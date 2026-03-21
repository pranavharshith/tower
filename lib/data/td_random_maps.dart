import 'dart:math';

import 'td_maps.dart';

class TdRandomMapGenerator {
  final Random rng;

  TdRandomMapGenerator(this.rng);

  /// Generates a map matching `towerdefense/scripts/sketch.js:randomMap(numSpawns)`.
  ///
  /// This is used for map options like `empty2`, `sparse3`, `dense2`, etc.
  TdGeneratedMap generate({
    required String key,
    required int cols,
    required int rows,
  }) {
    final is3 = key.endsWith('3');
    final numSpawns = is3 ? 3 : 2;
    final cash = is3 ? 65 : 55;

    double wallCover = 0.1;
    if (key == 'empty2' || key == 'empty3') wallCover = 0;
    if (key == 'sparse2' || key == 'sparse3') wallCover = 0.1;
    if (key == 'dense2' || key == 'dense3') wallCover = 0.2;
    if (key == 'solid2' || key == 'solid3') wallCover = 0.3;

    // Build grid.
    final grid = List<List<int>>.generate(
      cols,
      (_) => List<int>.generate(
        rows,
        (_) => rng.nextDouble() < wallCover ? 1 : 0,
        growable: false,
      ),
      growable: false,
    );

    bool walkable(int c, int r) {
      // Towers are not yet placed during generation.
      if (grid[c][r] == 1) return false;
      return true;
    }

    bool outside(int c, int r) => c < 0 || r < 0 || c >= cols || r >= rows;

    int randint(int maxExclusive) => rng.nextInt(maxExclusive);

    TdCoord randomTile() => TdCoord(randint(cols), randint(rows));

    bool empty(int c, int r, TdCoord exit, List<TdCoord> spawnpoints) {
      if (!walkable(c, r)) return false;
      for (final s in spawnpoints) {
        if (s.x == c && s.y == r) return false;
      }
      if (exit.x == c && exit.y == r) return false;
      return true;
    }

    // Generate exit (same logic as JS `getEmpty()` then place fix-ups).
    TdCoord exit = randomTile();
    while (!walkable(exit.x, exit.y)) {
      exit = randomTile();
    }

    // Remove walls adjacent to exit (neighbors(walkMap, exit, false) -> grid[n]=0)
    final exitCols = [exit.x - 1, exit.x, exit.x + 1];
    final exitRows = [exit.y - 1, exit.y, exit.y + 1];
    for (final c in exitCols) {
      for (final r in exitRows) {
        if (outside(c, r)) continue;
        final isOrth =
            (c == exit.x && (r == exit.y - 1 || r == exit.y + 1)) ||
            (r == exit.y && (c == exit.x - 1 || c == exit.x + 1));
        if (!isOrth) continue;
        if (!walkable(c, r)) grid[c][r] = 0;
      }
    }

    // Reachability map from exit.
    List<List<bool>> computeVisitMap() {
      final visited = List<List<bool>>.generate(
        cols,
        (_) => List<bool>.filled(rows, false),
        growable: false,
      );
      final q = <TdCoord>[];
      visited[exit.x][exit.y] = true;
      q.add(exit);

      while (q.isNotEmpty) {
        final cur = q.removeLast();
        final c = cur.x;
        final r = cur.y;
        const dirs = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ];
        for (final d in dirs) {
          final nc = c + d[0];
          final nr = r + d[1];
          if (outside(nc, nr)) continue;
          if (visited[nc][nr]) continue;
          if (!walkable(nc, nr)) continue;
          visited[nc][nr] = true;
          q.add(TdCoord(nc, nr));
        }
      }
      return visited;
    }

    final spawnpoints = <TdCoord>[];
    final visitMap = computeVisitMap();

    const minDist = 15;

    // Pre-compute all valid spawn tiles that meet distance criteria
    // This is more efficient than brute-force random rejection
    final validSpawnTiles = <TdCoord>[];
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (!walkable(c, r) || !visitMap[c][r]) continue;

        // Check distance from exit
        final dx = c - exit.x;
        final dy = r - exit.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist >= minDist) {
          validSpawnTiles.add(TdCoord(c, r));
        }
      }
    }

    // Shuffle and pick from valid tiles - guarantees instant valid result
    validSpawnTiles.shuffle(rng);

    for (int i = 0; i < numSpawns; i++) {
      // Find a tile that doesn't conflict with already placed spawnpoints
      TdCoord? selected;
      for (final tile in validSpawnTiles) {
        if (empty(tile.x, tile.y, exit, spawnpoints)) {
          selected = tile;
          break;
        }
      }

      // Fallback to random selection if no pre-validated tile works
      if (selected == null) {
        for (int tries = 0; tries < 100; tries++) {
          final s = randomTile();
          if (walkable(s.x, s.y) &&
              visitMap[s.x][s.y] &&
              empty(s.x, s.y, exit, spawnpoints)) {
            final dx = s.x - exit.x;
            final dy = s.y - exit.y;
            final dist = sqrt(dx * dx + dy * dy);
            if (dist >= minDist) {
              selected = s;
              break;
            }
          }
        }
      }

      if (selected != null) {
        spawnpoints.add(selected);
      }
    }

    // display/displayDir are not used by our MVP renderer yet; set placeholders.
    final display = List<List<dynamic>>.generate(
      cols,
      (c) => List<dynamic>.generate(
        rows,
        (r) => grid[c][r] == 1 ? 'wall' : 'empty',
        growable: false,
      ),
      growable: false,
    );
    final displayDir = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, 0, growable: false),
      growable: false,
    );

    // Initial paths will be computed by `recalculate()` when the game starts (and after placements).
    final initialPaths = List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, 0, growable: false),
      growable: false,
    );

    return TdGeneratedMap(
      map: TdMapData(
        cols: cols,
        rows: rows,
        grid: grid,
        paths: initialPaths,
        exit: exit,
        spawnpoints: spawnpoints,
        bg: const [0, 0, 0],
        border: 255,
        borderAlpha: 31,
        display: display,
        displayDir: displayDir,
      ),
      cash: cash,
    );
  }
}

class TdGeneratedMap {
  final TdMapData map;
  final int cash;
  const TdGeneratedMap({required this.map, required this.cash});
}
