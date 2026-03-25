import 'dart:collection';
import 'dart:math';

import '../data/td_maps.dart';
import 'entities/entities.dart';
import 'game_utils.dart';

/// Handles pathfinding, danger heatmap, and path recalculation
/// Extracted from TdSim for better separation of concerns
class PathfindingService {
  final TdMapData baseMap;
  final Random rng;

  // Path state
  late List<List<int>>
  paths; // direction to exit (1=left, 2=up, 3=right, 4=down)
  late List<List<int?>> dists; // BFS distance from exit (null if unreachable)

  // Grid state (reference to simulation grid)
  late final List<List<int>> grid;
  late final TdCoord exit;
  late final List<TdCoord> spawnpoints;

  // Adaptive pathfinding - danger heatmap for enemy AI
  late List<List<double>> dangerHeatmap; // tracks enemy deaths per tile
  static const double dangerDecayRate = 0.98; // decay per frame (60fps)
  static const double dangerWeight = 2.0; // how much enemies avoid danger
  static const int dangerThreshold = 3; // minimum deaths to consider dangerous
  int _framesSincePathRecalc = 0;
  static const int pathRecalcInterval =
      120; // recalc every 2 seconds (60fps * 2)

  // Cached for placement / BFS
  late List<List<bool>> walkableCache;

  // Cache of reachable tiles from exit (for fast placement validation)
  late Set<String> _reachableTilesCache;
  bool _isReachabilityCacheValid = false;

  PathfindingService({
    required this.baseMap,
    required this.rng,
    required this.grid,
    required this.exit,
    required this.spawnpoints,
  }) {
    // Initialize paths from base map
    paths = deepCopy2DInt(baseMap.paths);

    // Initialize danger heatmap
    dangerHeatmap = List<List<double>>.generate(
      baseMap.cols,
      (_) => List<double>.filled(baseMap.rows, 0.0, growable: false),
      growable: false,
    );

    // Initialize distance map
    dists = List<List<int?>>.generate(
      baseMap.cols,
      (_) => List<int?>.filled(baseMap.rows, null, growable: false),
      growable: false,
    );

    // Initialize walkable cache
    walkableCache = List<List<bool>>.generate(
      baseMap.cols,
      (_) => List<bool>.filled(baseMap.rows, false, growable: false),
      growable: false,
    );

    // Initialize reachability cache
    _reachableTilesCache = <String>{};
  }

  /// Record enemy death at position for danger heatmap
  void recordEnemyDeath(int col, int row) {
    if (col >= 0 && row >= 0 && col < baseMap.cols && row < baseMap.rows) {
      dangerHeatmap[col][row] += 1.0;
    }
  }

  /// Update danger heatmap decay (called each frame when not paused)
  /// Returns true if paths should be recalculated
  bool updateDangerHeatmap() {
    bool hasSignificantDanger = false;

    for (int c = 0; c < baseMap.cols; c++) {
      for (int r = 0; r < baseMap.rows; r++) {
        dangerHeatmap[c][r] *= dangerDecayRate;

        // Clamp to zero if very small
        if (dangerHeatmap[c][r] < 0.01) {
          dangerHeatmap[c][r] = 0.0;
        }

        // Check if any tile has significant danger
        if (dangerHeatmap[c][r] >= dangerThreshold) {
          hasSignificantDanger = true;
        }
      }
    }

    // Periodically recalculate paths to adapt to danger zones
    _framesSincePathRecalc++;
    if (_framesSincePathRecalc >= pathRecalcInterval && hasSignificantDanger) {
      _framesSincePathRecalc = 0;
      return true; // Signal that recalculation is needed
    }

    return false;
  }

  /// Recalculate paths using BFS from exit with danger-aware pathfinding
  /// Pass hasTowerAt callback to check tower positions
  void recalculate(bool Function(int col, int row) hasTowerAt) {
    final cols = baseMap.cols;
    final rows = baseMap.rows;

    final oldPaths = paths;

    // Compute walkability considering current towers
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final g = grid[c][r];
        final blockedByGrid = g == 1 || g == 3;
        if (blockedByGrid) {
          walkableCache[c][r] = false;
          continue;
        }
        walkableCache[c][r] = !hasTowerAt(c, r);
      }
    }

    // BFS from exit
    final distance = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, -1, growable: false),
      growable: false,
    );

    final cameFromX = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, -1, growable: false),
      growable: false,
    );
    final cameFromY = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, -1, growable: false),
      growable: false,
    );

    final q = Queue<TdCoord>();
    q.add(exit);
    distance[exit.x][exit.y] = 0;

    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final dCur = distance[cur.x][cur.y];

      // Explore 4-neighborhood of walkable tiles
      const dirs = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ];

      for (final dir in dirs) {
        final nc = cur.x + dir[0];
        final nr = cur.y + dir[1];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (!walkableCache[nc][nr]) continue;
        if (distance[nc][nr] != -1) continue;
        distance[nc][nr] = dCur + 1;
        cameFromX[nc][nr] = cur.x;
        cameFromY[nc][nr] = cur.y;
        q.add(TdCoord(nc, nr));
      }
    }

    // Build distance + path direction maps with danger-aware pathfinding
    final newPaths = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, 0),
      growable: false,
    );
    dists = List<List<int?>>.generate(
      cols,
      (_) => List<int?>.filled(rows, null, growable: false),
      growable: false,
    );

    // Update reachability cache
    _reachableTilesCache.clear();
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (distance[c][r] != -1) {
          _reachableTilesCache.add('$c,$r');
        }
      }
    }
    _isReachabilityCacheValid = true;

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (distance[c][r] == -1) continue;
        dists[c][r] = distance[c][r];

        // Find all neighbors with shorter distance (optimal paths)
        final currentDist = distance[c][r];
        final optimalNeighbors = <int>[];
        final neighborDangers = <double>[];

        // Check all 4 directions
        final neighbors = [
          [c - 1, r, 1], // left
          [c, r - 1, 2], // up
          [c + 1, r, 3], // right
          [c, r + 1, 4], // down
        ];

        for (final neighbor in neighbors) {
          final nc = neighbor[0];
          final nr = neighbor[1];
          final dir = neighbor[2];

          if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
          if (distance[nc][nr] == -1) continue;

          // If neighbor is closer to exit, it's an optimal direction
          if (distance[nc][nr] < currentDist) {
            optimalNeighbors.add(dir);
            neighborDangers.add(dangerHeatmap[nc][nr]);
          }
        }

        // Choose direction based on danger levels (adaptive pathfinding)
        if (optimalNeighbors.isNotEmpty) {
          // Find minimum danger among optimal neighbors
          double minDanger = neighborDangers.reduce((a, b) => a < b ? a : b);

          // Filter neighbors that are within acceptable danger range
          final safestNeighbors = <int>[];
          for (int i = 0; i < optimalNeighbors.length; i++) {
            // Accept neighbors with danger close to minimum (within threshold)
            if (neighborDangers[i] <= minDanger + dangerWeight) {
              safestNeighbors.add(optimalNeighbors[i]);
            }
          }

          // If all paths are dangerous, still pick the least dangerous
          if (safestNeighbors.isEmpty) {
            // Find index of minimum danger
            int minIndex = 0;
            for (int i = 1; i < neighborDangers.length; i++) {
              if (neighborDangers[i] < neighborDangers[minIndex]) {
                minIndex = i;
              }
            }
            newPaths[c][r] = optimalNeighbors[minIndex];
          } else {
            // Randomly choose from safest neighbors
            newPaths[c][r] =
                safestNeighbors[rng.nextInt(safestNeighbors.length)];
          }
        }

        // Preserve pre-made path directions on grid==2 tiles
        if (grid[c][r] == 2) {
          newPaths[c][r] = oldPaths[c][r];
        }
      }
    }

    paths = newPaths;
  }

  /// Check if a tower can be placed at position without blocking paths
  /// Pass callbacks for checking walkability and enemy positions
  bool isPlaceable({
    required int col,
    required int row,
    required bool Function(int col, int row) walkableForPlacement,
    required List<TdEnemy> enemies,
    required List<TdEnemyTower> spawnTowers,
  }) {
    // Fast path: use cached reachability data
    if (!_isReachabilityCacheValid) {
      // Cache not ready, fall back to full BFS
      return _isPlaceableFullBFS(
        col: col,
        row: row,
        walkableForPlacement: walkableForPlacement,
        enemies: enemies,
        spawnTowers: spawnTowers,
      );
    }

    // Quick check: tile must be reachable from exit
    if (!_reachableTilesCache.contains('$col,$row')) {
      return false; // Tile wasn't reachable even before placing tower
    }

    // For the common case (placing on reachable tile), still need to verify
    // that blocking this tile doesn't disconnect spawnpoints from exit
    // Use optimized delta-BFS from the blocked tile
    return _isPlaceableDeltaBFS(
      col: col,
      row: row,
      walkableForPlacement: walkableForPlacement,
    );
  }

  /// Optimized delta-BFS check for tower placement
  /// Only checks if blocking this tile disconnects spawnpoints
  bool _isPlaceableDeltaBFS({
    required int col,
    required int row,
    required bool Function(int col, int row) walkableForPlacement,
  }) {
    final cols = baseMap.cols;
    final rows = baseMap.rows;

    // Build walkable map with the candidate tile blocked
    final walk = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        walk[c][r] = walkableForPlacement(c, r);
      }
    }
    walk[col][row] = false;

    // Quick check: exit must be walkable
    if (!walk[exit.x][exit.y]) return false;

    // BFS from exit to check if all spawnpoints are still reachable
    final visited = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );
    final q = Queue<TdCoord>();
    visited[exit.x][exit.y] = true;
    q.add(exit);

    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      const dirs = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ];

      for (final dir in dirs) {
        final nc = cur.x + dir[0];
        final nr = cur.y + dir[1];

        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (!walk[nc][nr]) continue;
        if (visited[nc][nr]) continue;

        visited[nc][nr] = true;
        q.add(TdCoord(nc, nr));
      }
    }

    // Check if all spawnpoints are reachable
    for (final sp in spawnpoints) {
      if (!visited[sp.x][sp.y]) {
        return false; // Spawnpoint is unreachable
      }
    }

    return true;
  }

  /// Full BFS fallback for tower placement validation
  bool _isPlaceableFullBFS({
    required int col,
    required int row,
    required bool Function(int col, int row) walkableForPlacement,
    required List<TdEnemy> enemies,
    required List<TdEnemyTower> spawnTowers,
  }) {
    final cols = baseMap.cols;
    final rows = baseMap.rows;

    // Build walkable map with the candidate tile blocked
    final walk = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        walk[c][r] = walkableForPlacement(c, r);
      }
    }
    walk[col][row] = false;

    // Quick check: exit must be walkable
    if (!walk[exit.x][exit.y]) return false;

    // BFS from exit over walkable tiles - single flow field calculation
    final visited = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );
    final q = Queue<TdCoord>();
    visited[exit.x][exit.y] = true;
    q.add(exit);

    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      const dirs = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ];
      for (final dir in dirs) {
        final nc = cur.x + dir[0];
        final nr = cur.y + dir[1];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (visited[nc][nr]) continue;
        if (!walk[nc][nr]) continue;
        visited[nc][nr] = true;
        q.add(TdCoord(nc, nr));
      }
    }

    // Check spawnpoints are reachable
    for (final sp in spawnpoints) {
      if (!visited[sp.x][sp.y]) return false;
    }

    // Check spawn towers are reachable
    for (final st in spawnTowers) {
      if (!visited[st.col][st.row]) return false;
    }

    // Check enemies aren't trapped
    for (final e in enemies) {
      final ec = e.gridCol;
      final er = e.gridRow;
      if (ec < 0 || er < 0 || ec >= cols || er >= rows) continue;
      if (ec == col && er == row) continue;
      // Enemy is trapped if it's on a walkable tile but not reachable
      if (walk[ec][er] && !visited[ec][er]) return false;
    }

    return true;
  }
}
