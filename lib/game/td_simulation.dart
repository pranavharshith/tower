import 'dart:collection';
import 'dart:math';

import '../data/td_maps.dart';

// Simulation tick rate.
// The original JS uses per-frame cooldown ticks and divides cooldown by 120
// to compute seconds. We mirror that by running 120 sim steps / second.
const double kSimSecondsPerTick = 1 / 120;

const double resistance = 0.5;
const double weakness = 0.5;
const double sellConst = 0.8;

const int tempSpawnCount = 40;
const int waveCoolTicks = 120;
const int minDist = 15;

bool _insideCircle(double x, double y, double cx, double cy, double r) {
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy < r * r;
}

bool _atTileCenter(double x, double y, int col, int row) {
  // JS: tolerance = ts/24 in pixels; divide by ts => 1/24 in tile units.
  const tol = 1 / 24.0;
  final cX = col + 0.5;
  final cY = row + 0.5;
  return x > cX - tol && x < cX + tol && y > cY - tol && y < cY + tol;
}

int _randIntInclusive(Random rng, int min, int max) {
  if (min > max) return min;
  // JS uses round(random(min, max)).
  final v = min + rng.nextDouble() * (max - min);
  return v.round();
}

double _randDouble(Random rng, double min, double max) {
  if (min > max) return min;
  return min + rng.nextDouble() * (max - min);
}

class TdSim {
  final TdMapData baseMap;
  final Random rng;

  // Player state
  int cash = 0;
  int health = 40;
  int maxHealth = 40;

  // Map state
  late final List<List<int>> grid;
  late List<List<int>> paths; // direction to exit
  late List<List<int?>> dists; // BFS distance from exit (null if unreachable)

  late final TdCoord exit;
  late final List<TdCoord> spawnpoints;

  // Entities
  final List<TdEnemy> enemies = [];
  final List<TdTower> towers = [];
  final List<TdMissile> missiles = [];
  final List<TdTempSpawn> tempSpawns = [];

  // Wave spawning
  int wave = 0;
  int spawnCool = 0; // ticks between spawn cycles
  int scd = 0; // current spawn cooldown
  int wcd = 0; // wave cooldown remaining
  bool toWait = false;
  bool paused = true;

  final List<String> newEnemies = [];

  // cached for placement / BFS
  late List<List<bool>> walkableCache;

  TdSim({
    required this.baseMap,
    required this.rng,
    required this.cash,
  }) {
    grid = _deepCopy2D(baseMap.grid);
    paths = _deepCopy2D(baseMap.paths);
    exit = baseMap.exit;
    spawnpoints = List<TdCoord>.unmodifiable(baseMap.spawnpoints);

    health = 40;
    maxHealth = health;

    dists = List<List<int?>>.generate(
      baseMap.cols,
      (_) => List<int?>.filled(baseMap.rows, null, growable: false),
      growable: false,
    );
    walkableCache = List<List<bool>>.generate(
      baseMap.cols,
      (_) => List<bool>.filled(baseMap.rows, false, growable: false),
      growable: false,
    );

    recalculate();
  }

  void startGame() {
    // Matches JS resetGame() -> paused = true, wave = 0, then nextWave()
    paused = true;
    wave = 0;
    spawnCool = 0;
    scd = 0;
    wcd = 0;
    toWait = false;
    enemies.clear();
    towers.clear();
    missiles.clear();
    tempSpawns.clear();
    newEnemies.clear();
    nextWave();
  }

  void togglePause() {
    paused = !paused;
  }

  void nextWave() {
    final pattern = randomWave();
    addWave(pattern);
    wave++;
  }

  bool get noMoreEnemies => enemies.isEmpty && newEnemies.isEmpty;

  void addWave(List<dynamic> pattern) {
    if (pattern.isEmpty) {
      spawnCool = 0;
      return;
    }
    spawnCool = pattern[0] as int;
    // In JS, `addWave` doesn't clear existing queue; but it is only called
    // when noMoreEnemies() is true, so the queue is empty.
    newEnemies.clear();

    for (int i = 1; i < pattern.length; i++) {
      final group = (pattern[i] as List).cast<dynamic>();
      addGroup(group);
    }
  }

  void addGroup(List<dynamic> group) {
    if (group.isEmpty) return;
    final count = (group.last as num).toInt();
    final names = group.sublist(0, group.length - 1).cast<String>();

    for (int i = 0; i < count; i++) {
      for (final name in names) {
        newEnemies.add(name);
      }
    }
  }

  bool isWave(int min, [int? max]) {
    if (max == null) return wave >= min;
    return wave >= min && wave < max;
  }

  List<dynamic> randomWave() {
    final waves = <List<dynamic>>[];

    void push(List<dynamic> pattern) => waves.add(pattern);

    if (isWave(0, 3)) {
      push([40, ['weak', 50]]);
    }
    if (isWave(2, 4)) {
      push([20, ['weak', 25]]);
    }
    if (isWave(2, 7)) {
      push([30, ['weak', 25], ['strong', 25]]);
      push([20, ['strong', 25]]);
    }
    if (isWave(3, 7)) {
      push([40, ['fast', 25]]);
    }
    if (isWave(4, 14)) {
      push([20, ['fast', 50]]);
    }
    if (isWave(5, 6)) {
      push([20, ['strong', 50], ['fast', 25]]);
    }
    if (isWave(8, 12)) {
      push([20, ['medic', 'strong', 'strong', 25]]);
    }
    if (isWave(10, 13)) {
      push([20, ['medic', 'strong', 'strong', 50]]);
      push([30, ['medic', 'strong', 'strong', 50], ['fast', 50]]);
      push([5, ['fast', 50]]);
    }
    if (isWave(12, 16)) {
      push([20, ['medic', 'strong', 'strong', 50], ['strongFast', 50]]);
      push([10, ['strong', 50], ['strongFast', 50]]);
      push([10, ['medic', 'strongFast', 50]]);
      push([10, ['strong', 25], ['stronger', 25], ['strongFast', 50]]);
      push([10, ['strong', 25], ['medic', 25], ['strongFast', 50]]);
      push([20, ['medic', 'stronger', 'stronger', 50]]);
      push([10, ['medic', 'stronger', 'strong', 50]]);
      push([10, ['medic', 'strong', 50], ['medic', 'strongFast', 50]]);
      push([5, ['strongFast', 100]]);
      push([20, ['stronger', 50]]);
    }
    if (isWave(13, 20)) {
      push([40, ['tank', 'stronger', 'stronger', 'stronger', 10]]);
      push([10, ['medic', 'stronger', 'stronger', 50]]);
      push([40, ['tank', 25]]);
      push([20, ['tank', 'stronger', 'stronger', 50]]);
      push([20, ['tank', 'medic', 50], ['strongFast', 25]]);
    }
    if (isWave(14, 20)) {
      push([20, ['tank', 'stronger', 'stronger', 50]]);
      push([20, ['tank', 'medic', 'medic', 50]]);
      push([20, ['tank', 'medic', 50], ['strongFast', 25]]);
      push([10, ['tank', 50], ['strongFast', 25]]);
      push([10, ['faster', 50]]);
      push([20, ['tank', 50], ['faster', 25]]);
    }
    if (isWave(17, 25)) {
      push([20, ['taunt', 'stronger', 'stronger', 'stronger', 25]]);
      push([20, ['spawner', 'stronger', 'stronger', 'stronger', 25]]);
      push([20, ['taunt', 'tank', 'tank', 'tank', 25]]);
      push([40, ['taunt', 'tank', 'tank', 'tank', 25]]);
    }
    if (isWave(19)) {
      push([20, ['spawner', 1], ['tank', 20], ['stronger', 25]]);
      push([20, ['spawner', 1], ['faster', 25]]);
    }
    if (isWave(23)) {
      push([20, ['taunt', 'medic', 'tank', 25]]);
      push([20, ['spawner', 2], ['taunt', 'medic', 'tank', 25]]);
      push([10, ['spawner', 1], ['faster', 100]]);
      push([5, ['faster', 100]]);
      push([
        20,
        ['tank', 100],
        ['faster', 50],
        ['taunt', 'tank', 'tank', 'tank', 50]
      ]);
      push([
        10,
        ['taunt', 'stronger', 'tank', 'stronger', 50],
        ['faster', 50]
      ]);
    }
    if (isWave(25)) {
      push([5, ['taunt', 'medic', 'tank', 50], ['faster', 50]]);
      push([5, ['taunt', 'faster', 'faster', 'faster', 50]]);
      push([
        10,
        ['taunt', 'tank', 'tank', 'tank', 50],
        ['faster', 50]
      ]);
    }
    if (isWave(30)) {
      push([5, ['taunt', 'faster', 'faster', 'faster', 50]]);
      push([5, ['taunt', 'tank', 'tank', 'tank', 50]]);
      push([5, ['taunt', 'medic', 'tank', 'tank', 50]]);
      push([1, ['faster', 200]]);
    }
    if (isWave(35)) {
      push([0, ['taunt', 'faster', 200]]);
    }

    if (waves.isEmpty) {
      // Fallback in case we missed a wave window.
      return [40, ['weak', 50]];
    }

    return waves[rng.nextInt(waves.length)];
  }

  bool canSpawn() => newEnemies.isNotEmpty && scd == 0;

  TdEnemyType _enemyType(String key) {
    final t = enemyTypes[key];
    if (t == null) throw ArgumentError('Unknown enemy type: $key');
    return t;
  }

  TdEnemy createEnemyAt(TdCoord c, String name) {
    final type = _enemyType(name);
    return TdEnemy(
      posX: c.x + 0.5,
      posY: c.y + 0.5,
      type: type,
    );
  }

  /// One simulation tick (120Hz steps).
  void step() {
    if (health <= 0) return;

    if (!paused) {
      if (scd > 0) scd--;
      if (toWait && wcd > 0) wcd--;
    }

    // Spawn enemies
    if (!paused && canSpawn()) {
      final name = newEnemies.removeAt(0);
      for (final s in spawnpoints) {
        enemies.add(createEnemyAt(s, name));
      }
      for (int i = tempSpawns.length - 1; i >= 0; i--) {
        final ts = tempSpawns[i];
        if (ts.remaining <= 0) continue;
        ts.remaining--;
        if (ts.remaining <= 0) {
          // It still spawned on this cycle, so remove after processing.
        }
        enemies.add(createEnemyAt(ts.pos, name));
      }
      scd = spawnCool;
    }

    // Remove expired temp spawnpoints.
    tempSpawns.removeWhere((t) => t.remaining <= 0);

    // Update enemies
    for (int i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (!paused) {
        e.update(this);
      }

      // Kill if outside.
      if (e.posX < 0 || e.posY < 0 || e.posX >= baseMap.cols || e.posY >= baseMap.rows) {
        enemies.removeAt(i);
      } else if (e.isAlive && _atTileCenter(e.posX, e.posY, exit.x, exit.y)) {
        // Exit reached
        if (!paused) {
          health -= e.damage;
        }
        e.alive = false;
        enemies.removeAt(i);
      } else if (!e.isAlive) {
        enemies.removeAt(i);
      }
    }

    // Update towers (target + attack when cd==0)
    if (!paused) {
      for (final t in towers) {
        t.tryFire(this);
      }
      for (final t in towers) {
        t.updateCooldown();
      }
    }

    // Update missiles (projectiles)
    if (!paused) {
      for (int i = missiles.length - 1; i >= 0; i--) {
        final m = missiles[i];
        m.update(this);
        if (!m.alive) missiles.removeAt(i);
      }
    }

    // Enemy death effects (cash + temp spawns) happens inside dealDamage.

    // Wave progression
    if (!paused) {
      if (noMoreEnemies && !toWait) {
        wcd = waveCoolTicks;
        toWait = true;
      }
      if (toWait && wcd == 0) {
        toWait = false;
        wcd = 0;
        nextWave();
      }
    }

    // Auto-recalculate when towers were placed/sold (caller sets this).
    // We always recalculate immediately after changes from the UI layer.
  }

  void recalculate() {
    final cols = baseMap.cols;
    final rows = baseMap.rows;

    final oldPaths = paths;

    // Compute walkability considering current towers.
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

    // BFS from exit.
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
      // Explore 4-neighborhood of walkable tiles.
      const dirs = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ];
      for (final dir in dirs) {
        final nc = cur.x + dir[0] as int;
        final nr = cur.y + dir[1] as int;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (!walkableCache[nc][nr]) continue;
        if (distance[nc][nr] != -1) continue;
        distance[nc][nr] = dCur + 1;
        cameFromX[nc][nr] = cur.x;
        cameFromY[nc][nr] = cur.y;
        q.add(TdCoord(nc, nr));
      }
    }

    // Build distance + path direction maps.
    final newPaths =
        List<List<int>>.generate(cols, (_) => List<int>.filled(rows, 0), growable: false);
    dists = List<List<int?>>.generate(
      cols,
      (_) => List<int?>.filled(rows, null, growable: false),
      growable: false,
    );

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (distance[c][r] == -1) continue;
        dists[c][r] = distance[c][r];

        // cameFrom is predecessor toward exit, so direction is (pred - tile).
        final fromX = cameFromX[c][r];
        final fromY = cameFromY[c][r];
        if (fromX == -1 && fromY == -1) continue; // exit itself

        final dx = fromX - c;
        final dy = fromY - r;
        if (dx < 0) {
          newPaths[c][r] = 1;
        } else if (dy < 0) {
          newPaths[c][r] = 2;
        } else if (dx > 0) {
          newPaths[c][r] = 3;
        } else if (dy > 0) {
          newPaths[c][r] = 4;
        }
        // Preserve pre-made path directions on grid==2 tiles.
        if (grid[c][r] == 2) {
          newPaths[c][r] = oldPaths[c][r];
        }
      }
    }

    paths = newPaths;
  }

  TdTower? getTowerAt(int col, int row) {
    for (final t in towers) {
      if (t.col == col && t.row == row) return t;
    }
    return null;
  }

  bool hasTowerAt(int col, int row) => getTowerAt(col, row) != null;

  bool walkableForPlacement(int col, int row) {
    final g = grid[col][row];
    if (g == 1 || g == 3) return false;
    if (hasTowerAt(col, row)) return false;
    return true;
  }

  bool emptyTile(int col, int row) {
    if (!walkableForPlacement(col, row)) return false;
    for (final s in spawnpoints) {
      if (s.x == col && s.y == row) return false;
    }
    if (exit.x == col && exit.y == row) return false;
    return true;
  }

  bool placeable(int col, int row) {
    final cols = baseMap.cols;
    final rows = baseMap.rows;

    // Clone walkability, temporarily block (col,row).
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

    // BFS from exit over walkable tiles.
    final visited = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );
    final q = Queue<TdCoord>();
    if (!walk[exit.x][exit.y]) return false;
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
        final nc = cur.x + dir[0] as int;
        final nr = cur.y + dir[1] as int;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (visited[nc][nr]) continue;
        if (!walk[nc][nr]) continue;
        visited[nc][nr] = true;
        q.add(TdCoord(nc, nr));
      }
    }

    // Check spawnpoints reachable.
    for (final s in spawnpoints) {
      if (!visited[s.x][s.y]) return false;
    }

    // Check current enemies reachable (except those already on candidate).
    for (final e in enemies) {
      final ec = e.gridCol;
      final er = e.gridRow;
      if (ec == col && er == row) continue;
      if (!visited[ec][er]) return false;
    }

    return true;
  }

  bool canPlaceTower(TdTowerType towerType, int col, int row) {
    // Port of canPlace() from JS.
    final g = grid[col][row];
    if (g == 3) return true;
    if (g == 1 || g == 2 || g == 4) return false;
    if (!emptyTile(col, row)) return false;
    if (!placeable(col, row)) return false;
    return true;
  }

  void placeTower(TdTowerType towerType, int col, int row) {
    if (!canPlaceTower(towerType, col, row)) return;
    final tower = TdTower(
      towerType: towerType,
      col: col,
      row: row,
    );
    towers.add(tower);
    recalculate();
  }

  void sellTower(TdTower tower) {
    final idx = towers.indexOf(tower);
    if (idx == -1) return;
    cash += tower.sellPrice();
    towers.removeAt(idx);
    recalculate();
  }

  void upgradeTower(TdTower tower) {
    if (!tower.canUpgrade) return;
    tower.applyUpgrade();
  }

  TdEnemy? getFirstTarget(List<TdEnemy> candidates) {
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

  TdEnemy? getStrongestTarget(List<TdEnemy> candidates) {
    if (candidates.isEmpty) return null;
    TdEnemy chosen = candidates[0];
    for (final e in candidates) {
      if (e.health > chosen.health) chosen = e;
    }
    return chosen;
  }

  TdEnemy? getNearestTarget(List<TdEnemy> enemies, TdEnemy from, List<TdEnemy> ignore) {
    TdEnemy? best;
    double bestD2 = double.infinity;
    for (final e in enemies) {
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

  List<TdEnemy> enemiesInRange(double cx, double cy, int radiusTiles) {
    // JS: getInRange uses insideCircle with (radius + 1) * ts.
    final r = radiusTiles + 1;
    final r2 = (r * r).toDouble();
    final res = <TdEnemy>[];
    for (final e in enemies) {
      final dx = e.posX - cx;
      final dy = e.posY - cy;
      if (dx * dx + dy * dy < r2) {
        res.add(e);
      }
    }
    return res;
  }

  List<TdEnemy> enemiesInExplosionRange(double cx, double cy, double blastRadiusTiles) {
    // JS: getInRange uses (radius + 1) tiles.
    final r = blastRadiusTiles + 1;
    final r2 = r * r;
    final res = <TdEnemy>[];
    for (final e in enemies) {
      final dx = e.posX - cx;
      final dy = e.posY - cy;
      if (dx * dx + dy * dy < r2) res.add(e);
    }
    return res;
  }

  static List<List<int>> _deepCopy2D(List<List<int>> src) {
    return src.map((col) => col.toList(growable: false)).toList(growable: false);
  }
}

class TdEnemyType {
  final String key;
  final List<int> color;
  final double radiusTiles;

  final int cash;
  final double speed; // tiles-per-step*24 scale, matches JS speed.
  final double health;

  final List<String> immune;
  final List<String> resistant;
  final List<String> weak;

  final bool taunt;

  final bool medicTick;
  final bool spawnerTick;

  TdEnemyType({
    required this.key,
    required this.color,
    required this.radiusTiles,
    required this.cash,
    required this.speed,
    required this.health,
    this.immune = const [],
    this.resistant = const [],
    this.weak = const [],
    this.taunt = false,
    this.medicTick = false,
    this.spawnerTick = false,
  });
}

// Damage type strings match the JS version: 'physical', 'energy', 'slow', 'poison',
// 'explosion', 'piercing'.
final Map<String, TdEnemyType> enemyTypes = {
  'weak': TdEnemyType(
    key: 'weak',
    color: [189, 195, 199],
    radiusTiles: 0.5,
    cash: 1,
    speed: 1,
    health: 35,
  ),
  'strong': TdEnemyType(
    key: 'strong',
    color: [108, 122, 137],
    radiusTiles: 0.6,
    cash: 1,
    speed: 1,
    health: 75,
  ),
  'fast': TdEnemyType(
    key: 'fast',
    color: [61, 251, 255],
    radiusTiles: 0.5,
    cash: 2,
    speed: 2,
    health: 75,
  ),
  'strongFast': TdEnemyType(
    key: 'strongFast',
    color: [30, 139, 195],
    radiusTiles: 0.5,
    cash: 2,
    speed: 2,
    health: 135,
  ),
  'medic': TdEnemyType(
    key: 'medic',
    color: [192, 57, 43],
    radiusTiles: 0.7,
    cash: 4,
    speed: 1,
    health: 375,
    immune: ['regen'],
    medicTick: true,
  ),
  'stronger': TdEnemyType(
    key: 'stronger',
    color: [52, 73, 94],
    radiusTiles: 0.8,
    cash: 4,
    speed: 1,
    health: 375,
  ),
  'faster': TdEnemyType(
    key: 'faster',
    color: [249, 105, 14],
    radiusTiles: 0.5,
    cash: 4,
    speed: 3,
    health: 375,
    resistant: ['explosion'],
  ),
  'tank': TdEnemyType(
    key: 'tank',
    color: [30, 130, 76],
    radiusTiles: 1,
    cash: 4,
    speed: 1,
    health: 750,
    immune: ['poison', 'slow'],
    resistant: ['energy', 'physical'],
    weak: ['explosion', 'piercing'],
  ),
  'taunt': TdEnemyType(
    key: 'taunt',
    color: [102, 51, 153],
    radiusTiles: 0.8,
    cash: 8,
    speed: 1,
    health: 1500,
    immune: ['poison', 'slow'],
    resistant: ['energy', 'physical'],
    taunt: true,
  ),
  'spawner': TdEnemyType(
    key: 'spawner',
    color: [244, 232, 66],
    radiusTiles: 0.7,
    cash: 10,
    speed: 1,
    health: 1150,
    spawnerTick: true,
  ),
};

class TdEnemy {
  final TdEnemyType type;

  double posX;
  double posY;
  double velX = 0;
  double velY = 0;

  bool alive = true;

  final int damage = 1;

  late double health;
  late double maxHealth;
  late double speed;

  final List<_EnemyEffect> effects = [];

  TdEnemy({
    required this.posX,
    required this.posY,
    required this.type,
  }) {
    health = type.health;
    maxHealth = health;
    speed = type.speed;
  }

  bool get isAlive => alive;

  int get gridCol => posX.floor();
  int get gridRow => posY.floor();

  void applyEffect(String name, int duration) {
    // JS: if immune includes name -> return. Also only one of each effect allowed.
    if (_immuneContains(name)) return;
    for (final e in effects) {
      if (e.name == name) return;
    }

    if (name == 'slow') {
      // Matches effects.slow onStart.
      final oldSpeed = speed;
      speed = speed / 2.0;
      effects.add(_EnemyEffect.slow(duration: duration, oldSpeed: oldSpeed));
    } else if (name == 'poison') {
      effects.add(_EnemyEffect.simple(name: name, duration: duration));
    } else if (name == 'regen') {
      effects.add(_EnemyEffect.simple(name: name, duration: duration));
    } else {
      // Unknown effect
      effects.add(_EnemyEffect.simple(name: name, duration: duration));
    }
  }

  bool _immuneContains(String effectName) {
    return type.immune.contains(effectName);
  }

  void dealDamage(double amt, String typeName, TdSim sim) {
    if (!alive) return;

    double mult = 1.0;
    if (typeName == 'physical' || typeName == 'energy' || typeName == 'slow' || typeName == 'poison' || typeName == 'explosion' || typeName == 'piercing') {
      if (type.immune.contains(typeName)) {
        mult = 0.0;
      } else if (type.resistant.contains(typeName)) {
        mult = 1 - resistance;
      } else if (type.weak.contains(typeName)) {
        mult = 1 + weakness;
      }
    } else {
      if (type.immune.contains(typeName)) {
        mult = 0.0;
      } else if (type.resistant.contains(typeName)) {
        mult = 1 - resistance;
      } else if (type.weak.contains(typeName)) {
        mult = 1 + weakness;
      }
    }

    if (health > 0) {
      health -= amt * mult;
    }
    if (health <= 0) {
      onKilled(sim);
    }
  }

  void onKilled(TdSim sim) {
    if (!alive) return;
    alive = false;
    sim.cash += type.cash;

    if (type.spawnerTick) {
      final c = TdCoord(gridCol, gridRow);
      if (c == sim.exit) return;
      for (final ts in sim.tempSpawns) {
        if (ts.pos == c) return;
      }
      sim.tempSpawns.add(TdTempSpawn(pos: c, remaining: tempSpawnCount));
    }
  }

  void kill() {
    alive = false;
  }

  void update(TdSim sim) {
    // Status effects (slow/poison/regen)
    for (int i = effects.length - 1; i >= 0; i--) {
      final ef = effects[i];
      ef.onTick(this, sim);
      ef.duration--;
      if (ef.duration == 0) {
        ef.onEnd(this);
        effects.removeAt(i);
      }
    }

    // Medic periodically applies regen to nearby enemies.
    if (type.medicTick) {
      final affected =
          sim.enemiesInExplosionRange(posX, posY, 2); // radius tiles, JS uses getInRange(radius=2) => effective=3
      for (final other in affected) {
        other.applyEffect('regen', 1);
      }
    }

    // Movement using path direction map.
    if (_atTileCenter(posX, posY, gridCol, gridRow)) {
      final col = gridCol;
      final row = gridRow;
      if (col < 0 || row < 0 || col >= sim.baseMap.cols || row >= sim.baseMap.rows) return;
      final dir = sim.paths[col][row];
      if (dir == 1) {
        velX = -(speed / 24.0);
        velY = 0;
      } else if (dir == 2) {
        velY = -(speed / 24.0);
        velX = 0;
      } else if (dir == 3) {
        velX = speed / 24.0;
        velY = 0;
      } else if (dir == 4) {
        velY = speed / 24.0;
        velX = 0;
      } else {
        velX = 0;
        velY = 0;
      }
    }

    posX += velX;
    posY += velY;
  }
}

class _EnemyEffect {
  final String name;
  int duration;
  double? oldSpeed;

  _EnemyEffect.simple({required this.name, required this.duration});

  _EnemyEffect.slow({required int duration, required this.oldSpeed})
      : name = 'slow',
        duration = duration;

  void onTick(TdEnemy e, TdSim sim) {
    if (name == 'poison') {
      e.dealDamage(1, 'poison', sim);
    } else if (name == 'regen') {
      // JS: random() < 0.2. We approximate with sim.rng.
      if (e.health < e.maxHealth && sim.rng.nextDouble() < 0.2) {
        e.health += 1;
        if (e.health > e.maxHealth) e.health = e.maxHealth;
      }
    }
  }

  void onEnd(TdEnemy e) {
    if (name == 'slow') {
      e.speed = oldSpeed ?? e.speed;
    }
  }
}

class TdTempSpawn {
  final TdCoord pos;
  int remaining;
  TdTempSpawn({required this.pos, required this.remaining});
}

class TdTowerType {
  final String key;
  final String title;
  final int cost;
  final int range;
  final int cooldownMin;
  final int cooldownMax;
  final double damageMin;
  final double damageMax;
  final String type; // damage type (physical/energy/explosion/etc)

  final List<int> color;
  final List<int> secondary;
  final double radiusTiles;

  final TowerUpgrade? upgrade;

  final bool isSniper;
  final bool isRocket;
  final bool isTesla;

  TdTowerType({
    required this.key,
    required this.title,
    required this.cost,
    required this.range,
    required this.cooldownMin,
    required this.cooldownMax,
    required this.damageMin,
    required this.damageMax,
    required this.type,
    required this.color,
    required this.secondary,
    required this.radiusTiles,
    this.upgrade,
    this.isSniper = false,
    this.isRocket = false,
    this.isTesla = false,
  });
}

class TowerUpgrade {
  final String name;
  final String title;
  final int cost;

  final int? cooldownMin;
  final int? cooldownMax;
  final double? damageMin;
  final double? damageMax;
  final int? range;
  final String? type;

  // Attack behavior toggles handled by the parent tower key in TdTower.
  TowerUpgrade({
    required this.name,
    required this.title,
    required this.cost,
    this.cooldownMin,
    this.cooldownMax,
    this.damageMin,
    this.damageMax,
    this.range,
    this.type,
  });
}

class TdTower {
  final TdTowerType towerType;

  final int col;
  final int row;

  // tile-unit center position
  final double posX;
  final double posY;

  // Cooldown and damage.
  int cooldownMin;
  int cooldownMax;
  double damageMin;
  double damageMax;
  int range;
  String type;

  List<int> color;
  List<int> secondary;
  double radiusTiles;

  int cd = 0;
  double totalCost;

  final Random _localRng; // unused; uses sim.rng for determinism instead.

  TdEnemy? lastLaserTarget;
  int laserDuration = 0;

  bool upgraded = false;
  TowerUpgrade? upgrade;

  TdTower({
    required this.towerType,
    required this.col,
    required this.row,
  })  : posX = col + 0.5,
        posY = row + 0.5,
        cooldownMin = towerType.cooldownMin,
        cooldownMax = towerType.cooldownMax,
        damageMin = towerType.damageMin,
        damageMax = towerType.damageMax,
        range = towerType.range,
        type = towerType.type,
        color = towerType.color,
        secondary = towerType.secondary,
        radiusTiles = towerType.radiusTiles,
        totalCost = towerType.cost.toDouble(),
        _localRng = Random(),
        upgrade = towerType.upgrade {
    cd = 0;
  }

  bool get canUpgrade => !upgraded && upgrade != null;

  void applyUpgrade() {
    if (!canUpgrade) return;

    final u = upgrade!;
    cooldownMin = u.cooldownMin ?? cooldownMin;
    cooldownMax = u.cooldownMax ?? cooldownMax;
    if (u.damageMin != null) damageMin = u.damageMin!;
    if (u.damageMax != null) damageMax = u.damageMax!;
    if (u.range != null) range = u.range!;
    type = u.type ?? type;

    totalCost += u.cost.toDouble();
    upgraded = true;
  }

  int sellPrice() => (totalCost * sellConst).floor();

  bool get canFire => cd == 0;

  void resetCooldown(TdSim sim) {
    cd = _randIntInclusive(sim.rng, cooldownMin, cooldownMax);
  }

  void updateCooldown() {
    if (cd > 0) cd--;
  }

  void tryFire(TdSim sim) {
    if (enemiesInRange(sim).isEmpty) return;
    final inRange = enemiesInRange(sim);
    final taunting = inRange.where((e) => e.type.taunt).toList();

    if (!canFire) return;

    TdEnemy? target;
    if (towerType.isSniper) {
      target = taunting.isNotEmpty ? sim.getStrongestTarget(taunting) : sim.getStrongestTarget(inRange);
    } else {
      final candidates = taunting.isNotEmpty ? taunting : inRange;
      target = sim.getFirstTarget(candidates);
    }
    if (target == null) return;

    resetCooldown(sim);
    fireAt(sim, target);
  }

  List<TdEnemy> enemiesInRange(TdSim sim) =>
      sim.enemiesInRange(posX, posY, range);

  void fireAt(TdSim sim, TdEnemy target) {
    final key = towerType.key;

    switch (key) {
      case 'gun':
        _fireDirectDamage(sim, target);
        return;
      case 'slow':
        _fireDirectDamage(sim, target);
        // slow's onHit differs when upgraded.
        if (upgraded) {
          target.applyEffect('poison', 60);
        } else {
          target.applyEffect('slow', 40);
        }
        return;
      case 'laser':
        if (upgraded) {
          _fireBeamEmitter(sim, target);
        } else {
          _fireDirectDamage(sim, target);
        }
        return;
      case 'sniper':
        // Sniper is base Tower.attack behavior; railgun upgrade adds a blast onHit.
        _fireDirectDamage(sim, target);
        if (upgraded) {
          _fireRailgunBlast(sim, target);
        }
        return;
      case 'rocket':
        _fireRocketProjectile(sim, target);
        return;
      case 'bomb':
        _fireDirectDamage(sim, target);
        if (upgraded) {
          _fireClusterBomb(sim, target);
        } else {
          _fireBombBlast(sim, target);
        }
        return;
      case 'tesla':
        _fireTesla(sim, target);
        return;
      default:
        _fireDirectDamage(sim, target);
        return;
    }
  }

  void _fireDirectDamage(TdSim sim, TdEnemy target) {
    final dmg = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
    // JS uses round(random(min,max)) which rounds both sides; we approximate.
    target.dealDamage(dmg, type, sim);
  }

  void _fireBeamEmitter(TdSim sim, TdEnemy target) {
    if (lastLaserTarget == target) {
      laserDuration++;
    } else {
      lastLaserTarget = target;
      laserDuration = 0;
    }

    // JS: var d = random(damageMin, damageMax); var damage = d * sq(duration)
    final d = _randDouble(sim.rng, damageMin, damageMax);
    final damage = d * (laserDuration * laserDuration);
    target.dealDamage(damage, type, sim);
    // beam emitter's upgrade calls this.onHit(e); no onHit defined, so nothing else.
  }

  void _fireRailgunBlast(TdSim sim, TdEnemy target) {
    const blastRadius = 1.0;
    final inRadius = sim.enemiesInExplosionRange(target.posX, target.posY, blastRadius);
    for (final e in inRadius) {
      final amt = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
      e.dealDamage(amt, type, sim);
    }
  }

  void _fireBombBlast(TdSim sim, TdEnemy target) {
    const blastRadius = 1.0;
    final inRadius = sim.enemiesInExplosionRange(target.posX, target.posY, blastRadius);
    for (final e in inRadius) {
      final amt = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
      e.dealDamage(amt, type, sim);
    }
  }

  void _fireClusterBomb(TdSim sim, TdEnemy target) {
    const blastRadius = 1.0;
    const segs = 3;
    final a0 = sim.rng.nextDouble() * 2 * pi;
    for (int i = 0; i < segs; i++) {
      final a = 2 * pi / segs * i + a0;
      final d = 2.0; // JS: d = 2 * ts; ts ~= 1 tile.
      final x = target.posX + cos(a) * d;
      final y = target.posY + sin(a) * d;

      final inRadius = sim.enemiesInExplosionRange(x, y, blastRadius);
      for (final e in inRadius) {
        final amt = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
        e.dealDamage(amt, type, sim);
      }
    }
  }

  void _fireRocketProjectile(TdSim sim, TdEnemy target) {
    final speed = upgraded ? 0.25 : 0.1666667;
    final blastRadius = upgraded ? 2.0 : 1.0;
    final missile = TdMissile(
      posX: posX,
      posY: posY,
      target: target,
      damageMin: upgraded ? damageMin : 40,
      damageMax: upgraded ? damageMax : 60,
      blastRadius: blastRadius,
      rangeTiles: 7,
      speedTilesPerTick: speed,
      lifetimeTicks: 60,
    );
    sim.missiles.add(missile);
  }

  void _fireTesla(TdSim sim, TdEnemy target) {
    var dmg = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
    final targets = <TdEnemy>[];
    var last = target;
    while (dmg > 1) {
      last.dealDamage(dmg, type, sim);
      targets.add(last);
      final next = sim.getNearestTarget(sim.enemies, last, targets);
      if (next == null) break;
      last = next;
      dmg /= 2;
    }
  }
}

class TdMissile {
  double posX;
  double posY;
  TdEnemy target;

  bool alive = true;

  final double damageMin;
  final double damageMax;

  final double blastRadius;
  final int rangeTiles;

  final double speedTilesPerTick;
  int lifetimeTicks;

  TdMissile({
    required this.posX,
    required this.posY,
    required this.target,
    required this.damageMin,
    required this.damageMax,
    required this.blastRadius,
    required this.rangeTiles,
    required this.speedTilesPerTick,
    required this.lifetimeTicks,
  });

  void update(TdSim sim) {
    if (!alive) return;

    if (!target.isAlive) {
      // Retarget nearest in range.
      final inRange = sim.enemiesInRange(posX, posY, rangeTiles);
      if (inRange.isEmpty) {
        alive = false;
        return;
      }
      TdEnemy? best;
      var bestD2 = double.infinity;
      for (final e in inRange) {
        final dx = e.posX - posX;
        final dy = e.posY - posY;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestD2) {
          bestD2 = d2;
          best = e;
        }
      }
      if (best == null) {
        alive = false;
        return;
      }
      target = best;
    }

    // Move toward target.
    final dx = target.posX - posX;
    final dy = target.posY - posY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < target.type.radiusTiles) {
      explode(sim);
      return;
    }

    final ux = dx / dist;
    final uy = dy / dist;
    posX += ux * speedTilesPerTick;
    posY += uy * speedTilesPerTick;

    lifetimeTicks--;
    if (lifetimeTicks <= 0) {
      explode(sim);
    }
  }

  void explode(TdSim sim) {
    if (!alive) return;
    alive = false;

    final inRadius =
        sim.enemiesInExplosionRange(posX, posY, blastRadius);
    for (final e in inRadius) {
      final amt = _randIntInclusive(sim.rng, damageMin.round(), damageMax.round()).toDouble();
      // JS missile.explode always uses 'explosion' damage type.
      e.dealDamage(amt, 'explosion', sim);
    }
  }
}

// Tower types and upgrades ported from `towerdefense/scripts/towers.js`.
//
// Note: we only port the gameplay stats and attack behavior; fancy drawing
// (barrel shapes, line styles) is intentionally omitted for MVP.
final Map<String, TdTowerType> towerTypes = {
  'gun': TdTowerType(
    key: 'gun',
    title: 'Gun Tower',
    cost: 25,
    range: 3,
    cooldownMin: 8,
    cooldownMax: 18,
    damageMin: 1,
    damageMax: 20,
    type: 'physical',
    color: [249, 191, 59],
    secondary: [149, 165, 166],
    radiusTiles: 0.9,
    upgrade: TowerUpgrade(
      name: 'machineGun',
      title: 'Machine Gun',
      cost: 75,
      cooldownMin: 0,
      cooldownMax: 5,
      damageMin: 0,
      damageMax: 10,
    ),
  ),
  'laser': TdTowerType(
    key: 'laser',
    title: 'Laser Tower',
    cost: 75,
    range: 2,
    cooldownMin: 1,
    cooldownMax: 1,
    damageMin: 1,
    damageMax: 3,
    type: 'energy',
    color: [25, 181, 254],
    secondary: [149, 165, 166],
    radiusTiles: 0.8,
    upgrade: TowerUpgrade(
      name: 'beamEmitter',
      title: 'Beam Emitter',
      cost: 200,
      cooldownMin: 0,
      cooldownMax: 0,
      damageMin: 0.001,
      damageMax: 0.1,
      range: 3,
    ),
  ),
  'slow': TdTowerType(
    key: 'slow',
    title: 'Slow Tower',
    cost: 100,
    range: 1,
    cooldownMin: 0,
    cooldownMax: 0,
    damageMin: 0,
    damageMax: 0,
    type: 'slow',
    color: [75, 119, 190],
    secondary: [189, 195, 199],
    radiusTiles: 0.9,
    upgrade: TowerUpgrade(
      name: 'poison',
      title: 'Poison Tower',
      cost: 150,
      cooldownMin: 60,
      cooldownMax: 60,
      range: 2,
      type: 'poison',
    ),
  ),
  'sniper': TdTowerType(
    key: 'sniper',
    title: 'Sniper Tower',
    cost: 150,
    range: 9,
    cooldownMin: 60,
    cooldownMax: 100,
    damageMin: 100,
    damageMax: 100,
    type: 'physical',
    color: [207, 0, 15],
    secondary: [103, 128, 159],
    radiusTiles: 0.9,
    upgrade: TowerUpgrade(
      name: 'railgun',
      title: 'Railgun',
      cost: 300,
      cooldownMin: 100,
      cooldownMax: 120,
      damageMin: 200,
      damageMax: 200,
      range: 11,
      type: 'piercing',
    ),
    isSniper: true,
  ),
  'rocket': TdTowerType(
    key: 'rocket',
    title: 'Rocket Tower',
    cost: 250,
    range: 7,
    cooldownMin: 60,
    cooldownMax: 80,
    damageMin: 40,
    damageMax: 60,
    type: 'explosion',
    color: [30, 130, 76],
    secondary: [189, 195, 199],
    radiusTiles: 0.75,
    upgrade: TowerUpgrade(
      name: 'missileSilo',
      title: 'Missile Silo',
      cost: 250,
      cooldownMin: 40,
      cooldownMax: 80,
      damageMin: 100,
      damageMax: 120,
      range: 9,
      type: 'explosion',
    ),
    isRocket: true,
  ),
  'bomb': TdTowerType(
    key: 'bomb',
    title: 'Bomb Tower',
    cost: 250,
    range: 2,
    cooldownMin: 40,
    cooldownMax: 60,
    damageMin: 20,
    damageMax: 60,
    type: 'explosion',
    color: [102, 51, 153],
    secondary: [103, 128, 159],
    radiusTiles: 0.9,
    upgrade: TowerUpgrade(
      name: 'clusterBomb',
      title: 'Cluster Bomb',
      cost: 250,
      cooldownMin: 40,
      cooldownMax: 80,
      damageMin: 100,
      damageMax: 140,
      range: 2,
      type: 'explosion',
    ),
  ),
  'tesla': TdTowerType(
    key: 'tesla',
    title: 'Tesla Coil',
    cost: 350,
    range: 4,
    cooldownMin: 60,
    cooldownMax: 80,
    damageMin: 256,
    damageMax: 512,
    type: 'energy',
    color: [255, 255, 0],
    secondary: [30, 139, 195],
    radiusTiles: 1.0,
    upgrade: TowerUpgrade(
      name: 'plasma',
      title: 'Plasma Tower',
      cost: 250,
      cooldownMin: 40,
      cooldownMax: 60,
      damageMin: 1024,
      damageMax: 2048,
      range: 4,
      type: 'energy',
    ),
    isTesla: true,
  ),
};

