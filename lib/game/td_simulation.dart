import 'dart:collection';
import 'dart:math';

import '../data/td_maps.dart';

// Simulation tick rate.
// Optimized to 60Hz for better battery life on mobile devices.
// The rendering engine interpolates visual movement for smooth 120Hz appearance.
const double kSimSecondsPerTick = 1 / 60;

// Base speed factor - tiles per second at speed=1
// Original: speed/24 per tick at 60Hz = speed/24 * 60 = 2.5 tiles/sec
const double kBaseSpeedTilesPerSecond = 2.5;

const double resistance = 0.5;
const double weakness = 0.5;
const double sellConst = 0.8;

const int tempSpawnCount = 40;
const int waveCoolTicks = 120;
const int minDist = 15;

// Status effect durations in seconds (frame-rate independent)
const double kSlowDurationSeconds = 0.67; // ~40 ticks at 60Hz
const double kPoisonDurationSeconds = 1.0; // ~60 ticks at 60Hz
const double kRegenDurationSeconds = 1.0;
const double kMinSpeedMultiplier = 0.3; // Speed cap at 30% of base

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

  // Object pool for missiles to reduce GC pressure
  final TdMissilePool _missilePool = TdMissilePool();

  // Spatial partitioning grid for efficient enemy queries (Tesla tower optimization)
  late final _SpatialGrid _spatialGrid;

  // Get pooled missiles (for backward compatibility)
  List<TdMissile> get pooledMissiles => _missilePool.active;

  // Wave spawning
  int wave = 0;
  int spawnCool = 0; // ticks between spawn cycles
  int scd = 0; // current spawn cooldown
  int wcd = 0; // wave cooldown remaining
  bool toWait = false;
  bool paused = true;

  final List<String> newEnemies = [];

  // Boss mechanics
  int bossesDefeated = 0;
  bool isBossWave = false;
  bool bossSpawned = false;
  TdEnemy? currentBoss;

  // Pink Towers - visual representation of spawnpoints (teleport every 2 waves, one becomes boss tower every 5 waves)
  final List<TdEnemyTower> spawnTowers = [];
  int lastTeleportWave = 0;
  TdEnemyTower? bossTower; // Which tower is currently the boss tower

  // Tower limit
  static const int maxTowers = 21;

  // cached for placement / BFS
  late List<List<bool>> walkableCache;

  TdSim({required this.baseMap, required this.rng, required this.cash}) {
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

    // Initialize spatial partitioning grid
    _spatialGrid = _SpatialGrid(baseMap.cols, baseMap.rows);

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

    // Boss mechanics reset
    bossesDefeated = 0;
    isBossWave = false;
    bossSpawned = false;
    currentBoss = null;
    bossTower = null;
    spawnTowers.clear();
    lastTeleportWave = 0;

    // Spawn initial spawn towers (2 towers)
    _spawnSpawnTowers();

    nextWave();
  }

  void _spawnSpawnTowers() {
    // Convert map spawnpoints to Pink Towers (enemy spawn towers)
    // These are the original map spawn locations
    for (final sp in spawnpoints) {
      spawnTowers.add(TdEnemyTower(col: sp.x, row: sp.y));
    }
  }

  void _teleportSpawnTowers() {
    // Save old positions before teleporting
    final oldPositions = <TdCoord>[];
    for (final tower in spawnTowers) {
      oldPositions.add(TdCoord(tower.col, tower.row));
    }

    // First, temporarily mark old positions as walkable for path calculation
    for (final oldPos in oldPositions) {
      grid[oldPos.x][oldPos.y] = 0; // Make old positions walkable temporarily
    }

    // Recalculate paths to know which tiles are reachable from exit
    recalculate();

    // Define "near exit" as within 3 tiles of exit
    const nearExitDistance = 3;
    bool nearExitTileAssigned = false;

    // Separate tiles into "near exit" and "far from exit"
    final nearExitTiles = <TdCoord>[];
    final farTiles = <TdCoord>[];

    for (int c = 0; c < baseMap.cols; c++) {
      for (int r = 0; r < baseMap.rows; r++) {
        // Must be walkable (grid value 0), not exit, and have a valid path
        if (grid[c][r] == 0 && !(exit.x == c && exit.y == r)) {
          // Check if this tile has a valid path to exit (paths[c][r] != 0)
          if (paths[c][r] != 0) {
            // Also exclude current tower positions
            bool isTowerPos = false;
            for (final t in spawnTowers) {
              if (t.col == c && t.row == r) {
                isTowerPos = true;
                break;
              }
            }
            if (!isTowerPos) {
              // Calculate Manhattan distance to exit
              final distToExit = (exit.x - c).abs() + (exit.y - r).abs();
              if (distToExit <= nearExitDistance) {
                nearExitTiles.add(TdCoord(c, r));
              } else {
                farTiles.add(TdCoord(c, r));
              }
            }
          }
        }
      }
    }

    // 30% chance that one tower spawns near exit, 70% chance all random
    final bool shouldSpawnNearExit = rng.nextDouble() < 0.3;

    // Assign positions
    nearExitTiles.shuffle(rng);
    farTiles.shuffle(rng);

    for (int i = 0; i < spawnTowers.length; i++) {
      if (shouldSpawnNearExit &&
          !nearExitTileAssigned &&
          nearExitTiles.isNotEmpty) {
        // 30% case: Assign one tower to near-exit position (slow enemies)
        final nearTile = nearExitTiles.removeAt(0);
        spawnTowers[i].col = nearTile.x;
        spawnTowers[i].row = nearTile.y;
        spawnTowers[i].isNearExit = true;
        nearExitTileAssigned = true;
      } else {
        // 70% case: Random position (anywhere), or remaining towers in 30% case
        // Combine all remaining tiles for random selection
        final allTiles = [...farTiles, ...nearExitTiles];
        allTiles.shuffle(rng);

        if (allTiles.isNotEmpty) {
          final tile = allTiles.removeAt(0);
          spawnTowers[i].col = tile.x;
          spawnTowers[i].row = tile.y;
          // Mark as near exit if it's within near-exit distance (applies to both 30% and 70% cases)
          final distToExit = (exit.x - tile.x).abs() + (exit.y - tile.y).abs();
          spawnTowers[i].isNearExit = distToExit <= nearExitDistance;

          // Remove from appropriate list
          if (distToExit <= nearExitDistance) {
            nearExitTiles.removeWhere((t) => t.x == tile.x && t.y == tile.y);
          } else {
            farTiles.removeWhere((t) => t.x == tile.x && t.y == tile.y);
          }
        }
      }
    }

    // Convert old positions to empty (0) to allow tower placement
    // Don't make them walls (1) as that would permanently block tower placement
    for (final oldPos in oldPositions) {
      // Don't change if a tower is still there
      bool hasTower = false;
      for (final t in spawnTowers) {
        if (t.col == oldPos.x && t.row == oldPos.y) {
          hasTower = true;
          break;
        }
      }
      if (!hasTower) {
        // Always make it empty (0) to allow tower placement
        // The recalculate() will handle pathfinding correctly
        grid[oldPos.x][oldPos.y] = 0;
      }
    }

    // Recalculate paths after grid changes
    recalculate();
  }

  void _convertToBossTower() {
    // Convert one spawn tower to boss tower
    if (spawnTowers.isNotEmpty) {
      final bt = spawnTowers[rng.nextInt(spawnTowers.length)];
      bt.isBossTower = true;
      bossTower = bt;
    }
  }

  void togglePause() {
    paused = !paused;
  }

  void nextWave() {
    wave++;

    // Check if this is a boss wave (every 5 waves)
    if (wave % 5 == 0) {
      isBossWave = true;
      bossSpawned = false;
      _convertToBossTower();
      // Boss spawns immediately at wave start
      spawnBoss();
      // No regular enemies during boss wave
      newEnemies.clear();
      spawnCool = 0;
    } else {
      isBossWave = false;
      bossSpawned = false;
      currentBoss = null;
      // Reset boss tower status after boss wave
      bossTower?.isBossTower = false;
      bossTower = null;

      // Teleport Pink Towers every 2 waves (only on non-boss waves)
      if (wave % 2 == 0 && wave != lastTeleportWave) {
        _teleportSpawnTowers();
        lastTeleportWave = wave;
      }

      final pattern = randomWave();
      addWave(pattern);
    }
  }

  void spawnBoss() {
    if (bossSpawned || !isBossWave || bossTower == null) return;

    // Ensure boss tower position has a valid path
    final bossCol = bossTower!.col;
    final bossRow = bossTower!.row;

    // If boss tower position doesn't have a valid path, find one
    if (paths[bossCol][bossRow] == 0) {
      // Find a spawn tower with a valid path
      for (final st in spawnTowers) {
        if (paths[st.col][st.row] != 0) {
          bossTower = st;
          st.isBossTower = true;
          break;
        }
      }
    }

    // Spawn boss from the boss tower
    currentBoss = TdEnemy(
      posX: bossTower!.col + 0.5,
      posY: bossTower!.row + 0.5,
      type: enemyTypes['boss']!,
    );
    // Boost boss stats based on how many bosses defeated
    // Changed from linear to exponential scaling to keep late game challenging
    // Formula: health = base × 1.25^bossesDefeated (25% increase per boss)
    final healthMultiplier = pow(1.25, bossesDefeated);
    currentBoss!.health *= healthMultiplier;
    currentBoss!.maxHealth = currentBoss!.health;
    enemies.add(currentBoss!);
    bossSpawned = true;
  }

  void onBossDefeated() {
    bossesDefeated++;
    currentBoss = null;
    bossSpawned = false;
    isBossWave = false;

    // Heal player by 10 HP
    final oldHealth = health;
    health = min(maxHealth, health + 10);
    healAmount = health - oldHealth; // For visual effect
    healEffectTicks = 60; // Show heal effect for 60 ticks (0.5 seconds)

    // Revert boss tower back to normal spawn tower
    bossTower?.isBossTower = false;
    bossTower = null;
  }

  // Heal effect state
  int healAmount = 0;
  int healEffectTicks = 0;

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
      push([
        40,
        ['weak', 50],
      ]);
    }
    if (isWave(2, 4)) {
      push([
        20,
        ['weak', 25],
      ]);
    }
    if (isWave(2, 7)) {
      push([
        30,
        ['weak', 25],
        ['strong', 25],
      ]);
      push([
        20,
        ['strong', 25],
      ]);
    }
    if (isWave(3, 7)) {
      push([
        40,
        ['fast', 25],
      ]);
    }
    if (isWave(4, 14)) {
      push([
        20,
        ['fast', 50],
      ]);
    }
    if (isWave(5, 6)) {
      push([
        20,
        ['strong', 50],
        ['fast', 25],
      ]);
    }
    if (isWave(8, 12)) {
      push([
        20,
        ['medic', 'strong', 'strong', 25],
      ]);
    }
    if (isWave(10, 13)) {
      push([
        20,
        ['medic', 'strong', 'strong', 50],
      ]);
      push([
        30,
        ['medic', 'strong', 'strong', 50],
        ['fast', 50],
      ]);
      push([
        5,
        ['fast', 50],
      ]);
    }
    if (isWave(12, 16)) {
      push([
        20,
        ['medic', 'strong', 'strong', 50],
        ['strongFast', 50],
      ]);
      push([
        10,
        ['strong', 50],
        ['strongFast', 50],
      ]);
      push([
        10,
        ['medic', 'strongFast', 50],
      ]);
      push([
        10,
        ['strong', 25],
        ['stronger', 25],
        ['strongFast', 50],
      ]);
      push([
        10,
        ['strong', 25],
        ['medic', 25],
        ['strongFast', 50],
      ]);
      push([
        20,
        ['medic', 'stronger', 'stronger', 50],
      ]);
      push([
        10,
        ['medic', 'stronger', 'strong', 50],
      ]);
      push([
        10,
        ['medic', 'strong', 50],
        ['medic', 'strongFast', 50],
      ]);
      push([
        5,
        ['strongFast', 100],
      ]);
      push([
        20,
        ['stronger', 50],
      ]);
    }
    if (isWave(13, 20)) {
      push([
        40,
        ['tank', 'stronger', 'stronger', 'stronger', 10],
      ]);
      push([
        10,
        ['medic', 'stronger', 'stronger', 50],
      ]);
      push([
        40,
        ['tank', 25],
      ]);
      push([
        20,
        ['tank', 'stronger', 'stronger', 50],
      ]);
      push([
        20,
        ['tank', 'medic', 50],
        ['strongFast', 25],
      ]);
    }
    if (isWave(14, 20)) {
      push([
        20,
        ['tank', 'stronger', 'stronger', 50],
      ]);
      push([
        20,
        ['tank', 'medic', 'medic', 50],
      ]);
      push([
        20,
        ['tank', 'medic', 50],
        ['strongFast', 25],
      ]);
      push([
        10,
        ['tank', 50],
        ['strongFast', 25],
      ]);
      push([
        10,
        ['faster', 50],
      ]);
      push([
        20,
        ['tank', 50],
        ['faster', 25],
      ]);
    }
    if (isWave(17, 25)) {
      push([
        20,
        ['taunt', 'stronger', 'stronger', 'stronger', 25],
      ]);
      push([
        20,
        ['spawner', 'stronger', 'stronger', 'stronger', 25],
      ]);
      push([
        20,
        ['taunt', 'tank', 'tank', 'tank', 25],
      ]);
      push([
        40,
        ['taunt', 'tank', 'tank', 'tank', 25],
      ]);
    }
    if (isWave(19)) {
      push([
        20,
        ['spawner', 1],
        ['tank', 20],
        ['stronger', 25],
      ]);
      push([
        20,
        ['spawner', 1],
        ['faster', 25],
      ]);
    }
    if (isWave(23)) {
      push([
        20,
        ['taunt', 'medic', 'tank', 25],
      ]);
      push([
        20,
        ['spawner', 2],
        ['taunt', 'medic', 'tank', 25],
      ]);
      push([
        10,
        ['spawner', 1],
        ['faster', 100],
      ]);
      push([
        5,
        ['faster', 100],
      ]);
      push([
        20,
        ['tank', 100],
        ['faster', 50],
        ['taunt', 'tank', 'tank', 'tank', 50],
      ]);
      push([
        10,
        ['taunt', 'stronger', 'tank', 'stronger', 50],
        ['faster', 50],
      ]);
    }
    if (isWave(25)) {
      push([
        5,
        ['taunt', 'medic', 'tank', 50],
        ['faster', 50],
      ]);
      push([
        5,
        ['taunt', 'faster', 'faster', 'faster', 50],
      ]);
      push([
        10,
        ['taunt', 'tank', 'tank', 'tank', 50],
        ['faster', 50],
      ]);
    }
    if (isWave(30)) {
      push([
        5,
        ['taunt', 'faster', 'faster', 'faster', 50],
      ]);
      push([
        5,
        ['taunt', 'tank', 'tank', 'tank', 50],
      ]);
      push([
        5,
        ['taunt', 'medic', 'tank', 'tank', 50],
      ]);
      push([
        1,
        ['faster', 200],
      ]);
    }
    if (isWave(35)) {
      push([
        0,
        ['taunt', 'faster', 200],
      ]);
    }

    if (waves.isEmpty) {
      // Fallback in case we missed a wave window.
      return [
        40,
        ['weak', 50],
      ];
    }

    return waves[rng.nextInt(waves.length)];
  }

  bool canSpawn() => newEnemies.isNotEmpty && scd == 0;

  TdEnemyType _enemyType(String key) {
    final t = enemyTypes[key];
    if (t == null) throw ArgumentError('Unknown enemy type: $key');
    return t;
  }

  TdEnemy createEnemyAt(
    TdCoord c,
    String name, {
    double speedMultiplier = 1.0,
  }) {
    final type = _enemyType(name);
    final enemy = TdEnemy(posX: c.x + 0.5, posY: c.y + 0.5, type: type);
    // Apply speed multiplier (for near-exit towers)
    if (speedMultiplier != 1.0) {
      enemy.speed *= speedMultiplier;
    }
    return enemy;
  }

  /// One simulation tick (60Hz steps with frame-rate independence).
  void step() {
    stepWithDelta(kSimSecondsPerTick);
  }

  /// Frame-rate independent step with delta time
  void stepWithDelta(double dt) {
    if (health <= 0) return;

    if (!paused) {
      if (scd > 0) scd--;
      if (toWait && wcd > 0) wcd--;
    }

    // Spawn enemies from Pink Tower positions
    if (!paused && canSpawn()) {
      final name = newEnemies.removeAt(0);
      for (final tower in spawnTowers) {
        // Enemies from near-exit towers move at 60% speed
        final speedMultiplier = tower.isNearExit ? 0.6 : 1.0;
        enemies.add(
          createEnemyAt(
            TdCoord(tower.col, tower.row),
            name,
            speedMultiplier: speedMultiplier,
          ),
        );
      }
      scd = spawnCool;
    }

    // Update enemies with delta time for frame-rate independence
    for (int i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (!paused) {
        e.update(this, dt);
      }

      // Kill if outside.
      if (e.posX < 0 ||
          e.posY < 0 ||
          e.posX >= baseMap.cols ||
          e.posY >= baseMap.rows) {
        enemies.removeAt(i);
      } else if (e.isAlive && _atTileCenter(e.posX, e.posY, exit.x, exit.y)) {
        // Exit reached - deal damage but DON'T remove boss
        if (!paused) {
          // Boss only deals damage once per attack interval
          if (e.type.key == 'boss') {
            if (e._bossAttackCooldown <= 0) {
              health -= e.damage;
              // Set cooldown based on boss speed (slower = faster attack)
              // Boss attacks every 2-4 seconds randomly
              e._bossAttackCooldown = 2.0 + rng.nextDouble() * 2.0;
            }
          } else {
            // Regular enemies die after reaching exit and deal damage once
            health -= e.damage;
            e.alive = false;
            enemies.removeAt(i);
            continue;
          }
        }
        // Boss stays and continues attacking (not removed)
        if (e.type.key != 'boss') {
          e.alive = false;
          enemies.removeAt(i);
        }
      } else if (!e.isAlive) {
        enemies.removeAt(i);
      }
    }

    // Update spatial grid with current enemy positions (for Tesla tower optimization)
    _spatialGrid.clear();
    for (final e in enemies) {
      _spatialGrid.add(e);
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

    // Update missiles (projectiles) and return dead ones to pool
    if (!paused) {
      for (int i = missiles.length - 1; i >= 0; i--) {
        final m = missiles[i];
        m.update(this);
        if (!m.alive) {
          // Return to pool instead of letting GC collect
          _missilePool.release(m);
          missiles.removeAt(i);
        }
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

    // Update heal effect timer
    if (healEffectTicks > 0) {
      healEffectTicks--;
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
        final nc = cur.x + dir[0] as int;
        final nr = cur.y + dir[1] as int;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (visited[nc][nr]) continue;
        if (!walk[nc][nr]) continue;
        visited[nc][nr] = true;
        q.add(TdCoord(nc, nr));
      }
    }

    // Check spawnpoints are reachable (O(numSpawns) instead of O(enemies))
    for (final sp in spawnpoints) {
      if (!visited[sp.x][sp.y]) return false;
    }

    // Check Pink Towers (spawn towers) are reachable
    for (final st in spawnTowers) {
      if (!visited[st.col][st.row]) return false;
    }

    // Only check enemies that would be completely trapped
    // An enemy is only invalid if it's on a walkable tile that's not reachable
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

  bool canPlaceTower(TdTowerType towerType, int col, int row) {
    // Check tower limit
    if (towers.length >= maxTowers) return false;

    // Check if an enemy is currently on this tile
    for (final e in enemies) {
      if (e.gridCol == col && e.gridRow == row) {
        return false; // Can't place tower on enemy position
      }
    }

    // Port of canPlace() from JS.
    final g = grid[col][row];
    if (g == 3) return true;
    if (g == 1 || g == 2 || g == 4) return false;
    if (!emptyTile(col, row)) return false;
    if (!placeable(col, row)) return false;
    return true;
  }

  bool get maxTowersReached => towers.length >= maxTowers;

  void placeTower(TdTowerType towerType, int col, int row) {
    if (!canPlaceTower(towerType, col, row)) return;
    final tower = TdTower(towerType: towerType, col: col, row: row);
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

  TdEnemy? getNearestTarget(
    List<TdEnemy> enemies,
    TdEnemy from,
    List<TdEnemy> ignore,
  ) {
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
    // Use exact radius - no +1 padding
    final r = radiusTiles.toDouble();
    final r2 = r * r;
    final res = <TdEnemy>[];
    for (final e in enemies) {
      final dx = e.posX - cx;
      final dy = e.posY - cy;
      if (dx * dx + dy * dy <= r2) {
        res.add(e);
      }
    }
    return res;
  }

  List<TdEnemy> enemiesInExplosionRange(
    double cx,
    double cy,
    double blastRadiusTiles,
  ) {
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
    return src
        .map((col) => col.toList(growable: false))
        .toList(growable: false);
  }
}

class TdEnemyType {
  final String key;
  final List<int> color;
  final double radiusTiles;

  final int cash;
  final double speed; // tiles-per-step*24 scale, matches JS speed.
  final double health;
  final int damage; // Damage dealt to player when reaching exit

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
    this.damage = 1,
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
  'boss': TdEnemyType(
    key: 'boss',
    color: [255, 0, 128], // Magenta/pink for boss
    radiusTiles: 1.5,
    cash: 50,
    speed: 0.5, // Slow but powerful
    health: 5000,
    damage: 5, // Boss deals 5 damage per hit
    immune: ['poison', 'slow'],
    resistant: ['physical', 'energy'],
    weak: ['explosion', 'piercing'],
  ),
};

// StatusManager - prevents effect overstacking and handles frame-rate independent durations
class _StatusManager {
  // Effect durations remaining in seconds (frame-rate independent)
  double _slowRemaining = 0.0;
  double _poisonRemaining = 0.0;
  double _regenRemaining = 0.0;

  // Number of active slow sources (for proper stacking logic)
  int _slowStacks = 0;

  bool get isSlowed => _slowRemaining > 0;
  bool get isPoisoned => _poisonRemaining > 0;
  bool get isRegening => _regenRemaining > 0;

  // Apply or refresh slow effect
  void applySlow() {
    _slowStacks++;
    _slowRemaining = kSlowDurationSeconds; // Refresh duration
  }

  // Apply or refresh poison effect
  void applyPoison() {
    _poisonRemaining = kPoisonDurationSeconds; // Refresh duration
  }

  // Apply or refresh regen effect
  void applyRegen() {
    _regenRemaining = kRegenDurationSeconds; // Refresh duration
  }

  // Calculate current speed multiplier based on slow stacks
  // Uses multiplicative stacking with a hard floor
  double getSpeedMultiplier() {
    if (_slowStacks == 0) return 1.0;

    // Each slow reduces speed by 50%, but we cap at 30% minimum
    // 1 stack = 0.5, 2 stacks = 0.25, 3+ stacks = 0.3 (capped)
    double multiplier = pow(0.5, _slowStacks).toDouble();
    return multiplier.clamp(kMinSpeedMultiplier, 1.0);
  }

  // Update all effect durations (call with dt each frame)
  void update(double dt) {
    if (_slowRemaining > 0) {
      _slowRemaining -= dt;
      if (_slowRemaining <= 0) {
        _slowRemaining = 0;
        _slowStacks = 0; // Clear all slow stacks when duration expires
      }
    }

    if (_poisonRemaining > 0) _poisonRemaining -= dt;
    if (_regenRemaining > 0) _regenRemaining -= dt;
  }

  // Process poison/regen ticks (call once per frame)
  void processTicks(TdEnemy enemy, TdSim sim, double dt) {
    // Poison: 1 damage per second (scaled by dt for frame-rate independence)
    if (_poisonRemaining > 0) {
      // Accumulate fractional damage for smooth frame-rate independence
      enemy._poisonAccumulator += dt;
      while (enemy._poisonAccumulator >= 1.0) {
        enemy.dealDamage(1, 'poison', sim);
        enemy._poisonAccumulator -= 1.0;
      }
    }

    // Regen: 1 health per second with 20% chance (scaled by dt)
    if (_regenRemaining > 0 && enemy.health < enemy.maxHealth) {
      enemy._regenAccumulator += dt;
      while (enemy._regenAccumulator >= 1.0) {
        if (sim.rng.nextDouble() < 0.2) {
          enemy.health = (enemy.health + 1).clamp(0.0, enemy.maxHealth);
        }
        enemy._regenAccumulator -= 1.0;
      }
    }
  }
}

class TdEnemy {
  final TdEnemyType type;

  double posX;
  double posY;
  double velX = 0;
  double velY = 0;

  bool alive = true;

  int get damage => type.damage;

  late double health;
  late double maxHealth;
  late double speed;

  // Base speed from type (never modified directly)
  late final double _baseSpeed;

  // Frame-rate independent status manager
  final _StatusManager _statusManager = _StatusManager();

  // Accumulators for fractional damage/healing (frame-rate independence)
  double _poisonAccumulator = 0.0;
  double _regenAccumulator = 0.0;

  // Boss attack cooldown (seconds) - prevents continuous damage at exit
  double _bossAttackCooldown = 0.0;

  TdEnemy({required this.posX, required this.posY, required this.type}) {
    health = type.health;
    maxHealth = health;
    _baseSpeed = type.speed;
    speed = _baseSpeed;
  }

  bool get isAlive => alive;

  int get gridCol => posX.floor();
  int get gridRow => posY.floor();

  void applyEffect(String name, int durationTicks) {
    // Convert legacy tick duration to seconds for compatibility
    // durationTicks at 60Hz = durationTicks/60 seconds
    final durationSeconds = durationTicks / 60.0;
    applyEffectSeconds(name, durationSeconds);
  }

  void applyEffectSeconds(String name, double durationSeconds) {
    // JS: if immune includes name -> return.
    if (_immuneContains(name)) return;

    if (name == 'slow') {
      _statusManager.applySlow();
    } else if (name == 'poison') {
      _statusManager.applyPoison();
    } else if (name == 'regen') {
      _statusManager.applyRegen();
    }
  }

  bool _immuneContains(String effectName) {
    return type.immune.contains(effectName);
  }

  void dealDamage(double amt, String typeName, TdSim sim) {
    if (!alive) return;

    double mult = 1.0;
    if (typeName == 'physical' ||
        typeName == 'energy' ||
        typeName == 'slow' ||
        typeName == 'poison' ||
        typeName == 'explosion' ||
        typeName == 'piercing') {
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

    // Check if boss was defeated
    if (type.key == 'boss' && sim.currentBoss == this) {
      sim.onBossDefeated();
    }

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

  // Frame-rate independent update using delta time
  void update(TdSim sim, double dt) {
    // Update status effect durations
    _statusManager.update(dt);

    // Process poison/regen ticks
    _statusManager.processTicks(this, sim, dt);

    // Medic periodically applies regen to nearby enemies.
    if (type.medicTick) {
      final affected = sim.enemiesInExplosionRange(posX, posY, 2);
      for (final other in affected) {
        other.applyEffectSeconds('regen', kRegenDurationSeconds);
      }
    }

    // Boss attack cooldown countdown
    if (type.key == 'boss' && _bossAttackCooldown > 0) {
      _bossAttackCooldown -= dt;
      if (_bossAttackCooldown < 0) _bossAttackCooldown = 0;
    }

    // Calculate current speed based on status effects
    // Never modify base speed - calculate dynamically
    final speedMultiplier = _statusManager.getSpeedMultiplier();
    final currentSpeed = _baseSpeed * speedMultiplier;

    // Movement using path direction map.
    if (_atTileCenter(posX, posY, gridCol, gridRow)) {
      final col = gridCol;
      final row = gridRow;
      if (col < 0 ||
          row < 0 ||
          col >= sim.baseMap.cols ||
          row >= sim.baseMap.rows) {
        return;
      }
      final dir = sim.paths[col][row];

      // Frame-rate independent velocity: tiles per second
      final velocity = currentSpeed * kBaseSpeedTilesPerSecond * dt;

      if (dir == 1) {
        velX = -velocity;
        velY = 0;
      } else if (dir == 2) {
        velY = -velocity;
        velX = 0;
      } else if (dir == 3) {
        velX = velocity;
        velY = 0;
      } else if (dir == 4) {
        velY = velocity;
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

// Legacy effect class kept for compatibility
class _EnemyEffect {
  final String name;
  int duration;
  double? oldSpeed;

  _EnemyEffect.simple({required this.name, required this.duration});

  _EnemyEffect.slow({required int duration, required this.oldSpeed})
    : name = 'slow',
      duration = duration;

  void onTick(TdEnemy e, TdSim sim) {
    // Deprecated - use StatusManager instead
  }

  void onEnd(TdEnemy e) {
    // Deprecated - use StatusManager instead
  }
}

class TdTempSpawn {
  final TdCoord pos;
  int remaining;
  TdTempSpawn({required this.pos, required this.remaining});
}

// Enemy tower that spawns enemies and moves every 2 waves
class TdEnemyTower {
  int col;
  int row;
  bool isBossTower;
  bool isNearExit; // If true, enemies from this tower move at 60% speed
  int health;
  int maxHealth;

  TdEnemyTower({
    required this.col,
    required this.row,
    this.isBossTower = false,
    this.isNearExit = false,
    this.health = 100,
  }) : maxHealth = health;

  bool get isAlive => health > 0;
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

  TdTower({required this.towerType, required this.col, required this.row})
    : posX = col + 0.5,
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
      target = taunting.isNotEmpty
          ? sim.getStrongestTarget(taunting)
          : sim.getStrongestTarget(inRange);
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
    final dmg = _randIntInclusive(
      sim.rng,
      damageMin.round(),
      damageMax.round(),
    ).toDouble();
    // JS uses round(random(min,max)) which rounds both sides; we approximate.
    target.dealDamage(dmg, type, sim);
  }

  // Maximum damage cap for beam emitter to prevent exponential melting
  static const double _maxBeamDamage = 500.0;

  void _fireBeamEmitter(TdSim sim, TdEnemy target) {
    if (lastLaserTarget == target) {
      laserDuration++;
    } else {
      lastLaserTarget = target;
      laserDuration = 0;
    }

    // JS: var d = random(damageMin, damageMax); var damage = d * sq(duration)
    // Changed from quadratic to linear scaling with a hard cap
    // This prevents bosses from being instantly melted when slowed/stunned
    final d = _randDouble(sim.rng, damageMin, damageMax);
    final linearDamage = d * laserDuration; // Linear instead of quadratic
    final damage = linearDamage.clamp(0.0, _maxBeamDamage);
    target.dealDamage(damage, type, sim);
    // beam emitter's upgrade calls this.onHit(e); no onHit defined, so nothing else.
  }

  void _fireRailgunBlast(TdSim sim, TdEnemy target) {
    const blastRadius = 1.0;
    final inRadius = sim.enemiesInExplosionRange(
      target.posX,
      target.posY,
      blastRadius,
    );
    for (final e in inRadius) {
      final amt = _randIntInclusive(
        sim.rng,
        damageMin.round(),
        damageMax.round(),
      ).toDouble();
      e.dealDamage(amt, type, sim);
    }
  }

  void _fireBombBlast(TdSim sim, TdEnemy target) {
    const blastRadius = 1.0;
    final inRadius = sim.enemiesInExplosionRange(
      target.posX,
      target.posY,
      blastRadius,
    );
    for (final e in inRadius) {
      final amt = _randIntInclusive(
        sim.rng,
        damageMin.round(),
        damageMax.round(),
      ).toDouble();
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
        final amt = _randIntInclusive(
          sim.rng,
          damageMin.round(),
          damageMax.round(),
        ).toDouble();
        e.dealDamage(amt, type, sim);
      }
    }
  }

  void _fireRocketProjectile(TdSim sim, TdEnemy target) {
    final speed = upgraded ? 0.25 : 0.1666667;
    final blastRadius = upgraded ? 2.0 : 1.0;
    // Use object pool instead of creating new missile
    final missile = sim._missilePool.acquire(
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
    var dmg = _randIntInclusive(
      sim.rng,
      damageMin.round(),
      damageMax.round(),
    ).toDouble();
    final targets = <TdEnemy>[];
    var last = target;
    while (dmg > 1) {
      last.dealDamage(dmg, type, sim);
      targets.add(last);

      // Use spatial partitioning for O(1) neighbor lookup instead of O(N)
      // Chain lightning jumps to nearby enemies within 2 tiles
      final nearby = sim._spatialGrid.getNearby(last.posX, last.posY, 2);
      final next = sim.getNearestTarget(nearby, last, targets);

      if (next == null) break;
      last = next;
      dmg /= 2;
    }
  }
}

// Object Pool for missiles to reduce GC pressure
class TdMissilePool {
  static const int _initialCapacity = 200;
  static const int _maxCapacity = 500;

  final List<TdMissile> _available = [];
  final List<TdMissile> _active = [];

  TdMissilePool() {
    // Pre-allocate missiles to avoid runtime allocation
    for (int i = 0; i < _initialCapacity; i++) {
      _available.add(TdMissile._empty());
    }
  }

  TdMissile acquire({
    required double posX,
    required double posY,
    required TdEnemy target,
    required double damageMin,
    required double damageMax,
    required double blastRadius,
    required int rangeTiles,
    required double speedTilesPerTick,
    required int lifetimeTicks,
  }) {
    TdMissile missile;
    if (_available.isNotEmpty) {
      missile = _available.removeLast();
      missile._reset(
        posX: posX,
        posY: posY,
        target: target,
        damageMin: damageMin,
        damageMax: damageMax,
        blastRadius: blastRadius,
        rangeTiles: rangeTiles,
        speedTilesPerTick: speedTilesPerTick,
        lifetimeTicks: lifetimeTicks,
      );
    } else {
      // Pool exhausted - create new (but cap total size)
      if (_active.length >= _maxCapacity) {
        // Recycle oldest active missile
        missile = _active.removeAt(0);
        missile._reset(
          posX: posX,
          posY: posY,
          target: target,
          damageMin: damageMin,
          damageMax: damageMax,
          blastRadius: blastRadius,
          rangeTiles: rangeTiles,
          speedTilesPerTick: speedTilesPerTick,
          lifetimeTicks: lifetimeTicks,
        );
      } else {
        missile = TdMissile(
          posX: posX,
          posY: posY,
          target: target,
          damageMin: damageMin,
          damageMax: damageMax,
          blastRadius: blastRadius,
          rangeTiles: rangeTiles,
          speedTilesPerTick: speedTilesPerTick,
          lifetimeTicks: lifetimeTicks,
        );
      }
    }
    _active.add(missile);
    return missile;
  }

  void release(TdMissile missile) {
    if (_active.remove(missile)) {
      missile._deactivate();
      if (_available.length < _initialCapacity) {
        _available.add(missile);
      }
    }
  }

  void releaseAll(List<TdMissile> missiles) {
    for (final m in missiles) {
      release(m);
    }
    missiles.clear();
  }

  List<TdMissile> get active => _active;
}

class TdMissile {
  double posX;
  double posY;
  TdEnemy target;

  bool alive = true;

  double damageMin;
  double damageMax;

  double blastRadius;
  int rangeTiles;

  double speedTilesPerTick;
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

  // Factory constructor for empty missile (for pooling)
  TdMissile._empty()
    : posX = 0,
      posY = 0,
      target = TdEnemy(posX: 0, posY: 0, type: enemyTypes['weak']!),
      damageMin = 0,
      damageMax = 0,
      blastRadius = 0,
      rangeTiles = 0,
      speedTilesPerTick = 0,
      lifetimeTicks = 0;

  // Reset missile for reuse from pool
  void _reset({
    required double posX,
    required double posY,
    required TdEnemy target,
    required double damageMin,
    required double damageMax,
    required double blastRadius,
    required int rangeTiles,
    required double speedTilesPerTick,
    required int lifetimeTicks,
  }) {
    this.posX = posX;
    this.posY = posY;
    this.target = target;
    this.damageMin = damageMin;
    this.damageMax = damageMax;
    this.blastRadius = blastRadius;
    this.rangeTiles = rangeTiles;
    this.speedTilesPerTick = speedTilesPerTick;
    this.lifetimeTicks = lifetimeTicks;
    alive = true;
  }

  // Deactivate for return to pool
  void _deactivate() {
    alive = false;
  }

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
    final distSq = dx * dx + dy * dy;
    final radiusSq = target.type.radiusTiles * target.type.radiusTiles;

    // Use squared distance check to avoid expensive sqrt
    if (distSq < radiusSq) {
      explode(sim);
      return;
    }

    // Only compute sqrt when we need to normalize the vector
    final dist = sqrt(distSq);
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

    final inRadius = sim.enemiesInExplosionRange(posX, posY, blastRadius);
    for (final e in inRadius) {
      final amt = _randIntInclusive(
        sim.rng,
        damageMin.round(),
        damageMax.round(),
      ).toDouble();
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
