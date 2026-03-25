import 'dart:math';

import '../config/td_game_config.dart';
import '../data/td_maps.dart';
import 'game_utils.dart';
import 'td_simulation.dart';
import 'entities/entities.dart';

/// Manages enemy lifecycle, spawning, updates, and spatial queries
/// Extracted from TdSim for better separation of concerns
class EnemyManager {
  final TdMapData baseMap;
  final Random rng;

  // Enemy list
  final List<TdEnemy> enemies = [];
  final List<TdTempSpawn> tempSpawns = [];

  // Spatial partitioning grid for efficient enemy queries (Tesla tower optimization)
  late final _SpatialGrid _spatialGrid;

  // Boss reference
  TdEnemy? currentBoss;

  EnemyManager({required this.baseMap, required this.rng}) {
    _spatialGrid = _SpatialGrid(baseMap.cols, baseMap.rows);
  }

  /// Clear all enemies (for game reset)
  void clear() {
    enemies.clear();
    tempSpawns.clear();
    currentBoss = null;
  }

  /// Create enemy at position with type
  TdEnemy createEnemyAt(
    TdCoord coord,
    String typeName, {
    required int currentWave,
    double speedMultiplier = 1.0,
  }) {
    final type = _getEnemyType(typeName);
    final enemy = TdEnemy(
      posX: coord.x + 0.5,
      posY: coord.y + 0.5,
      type: type,
      rng: rng,
    );

    // Apply speed multiplier (for near-exit towers)
    if (speedMultiplier != 1.0) {
      enemy.speed *= speedMultiplier;
    }

    // For waves 1-3: Increase speed by 20%
    if (currentWave <= 3) {
      enemy.speed *= 1.2;
    }

    return enemy;
  }

  /// Spawn enemies from spawn towers
  void spawnFromTowers({
    required List<TdEnemyTower> spawnTowers,
    required String enemyTypeName,
    required int currentWave,
  }) {
    // For path splitting: alternate which tower spawns first
    final shuffledTowers = List<TdEnemyTower>.from(spawnTowers);
    if (spawnTowers.length > 1) {
      shuffledTowers.shuffle(rng);
    }

    for (final tower in shuffledTowers) {
      // Enemies from near-exit towers move at 60% speed
      final speedMultiplier = tower.isNearExit
          ? TdGameConfig.nearExitSpeedMultiplier
          : 1.0;
      enemies.add(
        createEnemyAt(
          TdCoord(tower.col, tower.row),
          enemyTypeName,
          currentWave: currentWave,
          speedMultiplier: speedMultiplier,
        ),
      );
    }
  }

  /// Update all enemies with delta time
  /// Returns number of enemies that reached exit
  int updateEnemies({
    required TdSim sim,
    required double dt,
    required bool paused,
    required TdCoord exit,
    required Function(int damage) onEnemyReachExit,
    required Function() onBossDefeated,
  }) {
    int enemiesReachedExit = 0;

    for (int i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (!paused) {
        e.update(sim, dt);
      }

      // Kill if outside bounds
      if (e.posX < 0 ||
          e.posY < 0 ||
          e.posX >= baseMap.cols ||
          e.posY >= baseMap.rows) {
        enemies.removeAt(i);
        continue;
      }

      // Check if enemy reached exit
      if (e.isAlive && atTileCenter(e.posX, e.posY, exit.x, exit.y)) {
        if (!paused) {
          // Boss only deals damage once per attack interval
          if (e.type.key == 'boss') {
            if (e.bossAttackTimer >= e.bossNextAttackTime) {
              onEnemyReachExit(e.damage);
              e.bossAttackTimer = 0;
              e.bossNextAttackTime =
                  TdGameConfig.bossAttackIntervalMin +
                  rng.nextDouble() *
                      (TdGameConfig.bossAttackIntervalMax -
                          TdGameConfig.bossAttackIntervalMin);
            }
          } else {
            // Regular enemies die after reaching exit and deal damage once
            onEnemyReachExit(e.damage);
            e.alive = false;
            enemies.removeAt(i);
            enemiesReachedExit++;
            continue;
          }
        }
        // Boss stays and continues attacking (not removed)
        if (e.type.key != 'boss') {
          e.alive = false;
          enemies.removeAt(i);
          enemiesReachedExit++;
        }
      } else if (!e.isAlive) {
        // Check if boss was defeated
        if (e.type.key == 'boss' && currentBoss == e) {
          currentBoss = null;
          onBossDefeated();
        }
        enemies.removeAt(i);
      }
    }

    return enemiesReachedExit;
  }

  /// Update spatial grid for efficient queries
  void updateSpatialGrid() {
    _spatialGrid.clear();
    for (final e in enemies) {
      _spatialGrid.add(e);
    }
  }

  /// Get enemies within range of a point using spatial grid
  List<TdEnemy> enemiesInRange(double cx, double cy, int radiusTiles) {
    // Use spatial grid for efficient lookup instead of linear scan
    final r = radiusTiles.toDouble();
    final r2 = r * r;
    final res = <TdEnemy>[];

    // Get enemies from spatial grid tiles within radius
    final centerCol = cx.floor();
    final centerRow = cy.floor();

    bool foundInSpatialGrid = false;

    // Check tiles within radius
    for (int dc = -radiusTiles; dc <= radiusTiles; dc++) {
      for (int dr = -radiusTiles; dr <= radiusTiles; dr++) {
        final col = centerCol + dc;
        final row = centerRow + dr;

        if (col < 0 || col >= baseMap.cols || row < 0 || row >= baseMap.rows) {
          continue;
        }

        // Check enemies in this tile
        for (final e in _spatialGrid._grid[col][row]) {
          foundInSpatialGrid = true;
          final dx = e.posX - cx;
          final dy = e.posY - cy;
          if (dx * dx + dy * dy <= r2) {
            res.add(e);
          }
        }
      }
    }

    // Fallback to linear scan if spatial grid didn't find anything
    // (for backward compatibility or edge cases)
    if (!foundInSpatialGrid) {
      for (final e in enemies) {
        final dx = e.posX - cx;
        final dy = e.posY - cy;
        if (dx * dx + dy * dy <= r2) {
          res.add(e);
        }
      }
    }

    return res;
  }

  /// Get enemies within explosion range using spatial grid (uses +1 padding)
  List<TdEnemy> enemiesInExplosionRange(
    double cx,
    double cy,
    double blastRadiusTiles,
  ) {
    final r = blastRadiusTiles + 1;
    final r2 = r * r;
    final res = <TdEnemy>[];

    // Use spatial grid for efficient lookup
    final centerCol = cx.floor();
    final centerRow = cy.floor();
    final radiusTiles = r.ceil();

    bool foundInSpatialGrid = false;

    // Check tiles within radius
    for (int dc = -radiusTiles; dc <= radiusTiles; dc++) {
      for (int dr = -radiusTiles; dr <= radiusTiles; dr++) {
        final col = centerCol + dc;
        final row = centerRow + dr;

        if (col < 0 || col >= baseMap.cols || row < 0 || row >= baseMap.rows) {
          continue;
        }

        // Check enemies in this tile
        for (final e in _spatialGrid._grid[col][row]) {
          foundInSpatialGrid = true;
          final dx = e.posX - cx;
          final dy = e.posY - cy;
          if (dx * dx + dy * dy < r2) {
            res.add(e);
          }
        }
      }
    }

    // Fallback to linear scan if spatial grid didn't find anything
    // (for backward compatibility or edge cases)
    if (!foundInSpatialGrid) {
      for (final e in enemies) {
        final dx = e.posX - cx;
        final dy = e.posY - cy;
        if (dx * dx + dy * dy < r2) res.add(e);
      }
    }

    return res;
  }

  /// Get enemies nearby using spatial grid (for Tesla chain lightning)
  List<TdEnemy> getNearby(double centerX, double centerY, int radiusTiles) {
    return _spatialGrid.getNearby(centerX, centerY, radiusTiles);
  }

  /// Get first target (closest to exit) from candidates
  TdEnemy? getFirstTarget(List<TdEnemy> candidates, List<List<int?>> dists) {
    TdEnemy? chosen;
    int least = 1 << 30;
    for (final e in candidates) {
      final dc = e.gridCol;
      final dr = e.gridRow;
      final dist = dists[dc][dr];
      if (dist == null) continue;
      if (dist < least) {
        least = dist;
        chosen = e;
      }
    }
    return chosen;
  }

  /// Get strongest target (highest health) from candidates
  TdEnemy? getStrongestTarget(List<TdEnemy> candidates) {
    if (candidates.isEmpty) return null;
    TdEnemy chosen = candidates[0];
    for (final e in candidates) {
      if (e.health > chosen.health) chosen = e;
    }
    return chosen;
  }

  /// Get nearest target to a reference enemy (for chain lightning)
  TdEnemy? getNearestTarget(
    List<TdEnemy> candidates,
    TdEnemy from,
    List<TdEnemy> ignore,
  ) {
    TdEnemy? best;
    double bestD2 = double.infinity;
    for (final e in candidates) {
      if (ignore.contains(e)) continue;
      final dx = e.posX - from.posX;
      final dy = e.posY - from.posY;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    return best;
  }

  // atTileCenter is provided by game_utils.dart (shared utility).

  /// Get enemy type by key
  TdEnemyType _getEnemyType(String key) {
    final t = enemyTypes[key];
    if (t == null) throw ArgumentError('Unknown enemy type: $key');
    return t;
  }
}

// Spatial partitioning grid for efficient enemy queries
// Used by Tesla tower to avoid O(N^2) checks
class _SpatialGrid {
  final int cols;
  final int rows;
  late List<List<List<TdEnemy>>> _grid;

  _SpatialGrid(this.cols, this.rows) {
    _grid = List.generate(
      cols,
      (_) => List.generate(rows, (_) => <TdEnemy>[], growable: false),
      growable: false,
    );
  }

  void clear() {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        _grid[c][r].clear();
      }
    }
  }

  void add(TdEnemy enemy) {
    final col = enemy.gridCol;
    final row = enemy.gridRow;
    if (col >= 0 && col < cols && row >= 0 && row < rows) {
      _grid[col][row].add(enemy);
    }
  }

  // Get enemies in a specific tile and its neighbors (for chain lightning)
  List<TdEnemy> getNearby(double centerX, double centerY, int radiusTiles) {
    final centerCol = centerX.floor();
    final centerRow = centerY.floor();

    final result = <TdEnemy>[];
    final seen = <int>{}; // Use hash set to avoid duplicates

    // Check tiles within radius
    for (int dc = -radiusTiles; dc <= radiusTiles; dc++) {
      for (int dr = -radiusTiles; dr <= radiusTiles; dr++) {
        final col = centerCol + dc;
        final row = centerRow + dr;

        if (col < 0 || col >= cols || row < 0 || row >= rows) continue;

        // Add all enemies in this tile
        for (final e in _grid[col][row]) {
          final id = e.hashCode;
          if (!seen.contains(id)) {
            seen.add(id);
            result.add(e);
          }
        }
      }
    }

    return result;
  }
}
