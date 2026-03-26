import 'dart:math';

import '../config/td_game_config.dart';
import '../core/interfaces/i_simulation.dart';
import '../core/interfaces/i_sound_service.dart';
import '../data/td_maps.dart';
import 'collision_detector.dart';
import 'enemy_manager.dart';
import 'game_constants.dart';
import 'game_state.dart';
import 'game_utils.dart';
import 'pathfinding_service.dart';
import 'tower_manager.dart';
import 'wave_manager.dart';
import 'entities/enemy.dart';
import 'entities/enemy_tower.dart';
import 'entities/tower.dart';
import 'entities/missile.dart';

// Grid tile values (map terrain types):
// 0 = Empty/Buildable - Players can place towers here
// 1 = Wall/Scenery - Blocked for building, enemies cannot walk
// 2 = Enemy Path - Buildable (path recalculates when tower placed), pre-made path direction preserved when empty
// 3 = Water/Void - Blocked for building, enemies cannot walk (future use)

const double resistance = TdGameConfig.resistanceMultiplier;
const double weakness = TdGameConfig.weaknessMultiplier;
const double sellConst = TdGameConfig.towerSellMultiplier;

const int tempSpawnCount = TdGameConfig.enemiesPerTempSpawn;
const int waveCoolTicks = TdGameConfig.defaultTicksBetweenWaves;
const int minDist = TdGameConfig.minSpawnDistance;

// _atTileCenter is now the shared atTileCenter() in game_utils.dart.

/// Core tower defense simulation engine.
///
/// [TdSim] implements [ISimulation] and manages all game state including:
/// - Player resources (cash, health)
/// - Enemy spawning and pathfinding
/// - Tower placement and combat
/// - Wave progression and boss mechanics
/// - Missile collisions and particle effects
///
/// Uses a component-based architecture delegating to specialized managers:
/// - [PathfindingService] - BFS pathfinding and danger heatmap
/// - [EnemyManager] - Enemy lifecycle and spatial partitioning
/// - [TowerManager] - Tower placement, upgrades, and targeting
/// - [CollisionDetector] - Missile-enemy collision detection
/// - [WaveManager] - Wave progression and spawn patterns
///
/// The simulation runs at a fixed 60Hz timestep decoupled from rendering,
/// ensuring consistent gameplay across different refresh rate displays.
class TdSim implements ISimulation {
  @override
  final TdMapData baseMap;
  final Random rng;
  final ISoundService soundService; // Use interface for testability
  final String mapKey; // Track which map is being played

  // Player state - delegated to GameState
  late final GameState _gameState;

  // GameState accessors
  @override
  int get cash => _gameState.cash;
  @override
  set cash(int value) => _gameState.cash = value;
  @override
  int get health => _gameState.health;
  set health(int value) => _gameState.health = value;
  @override
  int get maxHealth => _gameState.maxHealth;
  @override
  bool get paused => _gameState.paused;
  set paused(bool value) => _gameState.paused = value;
  @override
  int get healAmount => _gameState.healAmount;
  @override
  int get healEffectTicks => _gameState.healEffectTicks;

  // Map state
  @override
  late final List<List<int>> grid;
  late final TdCoord exit;
  late final List<TdCoord> spawnpoints;

  // Pathfinding service - delegated to PathfindingService
  late final PathfindingService _pathfindingService;

  // Pathfinding accessors (delegate to PathfindingService)
  List<List<int>> get paths => _pathfindingService.paths;
  @override
  List<List<int?>> get dists => _pathfindingService.dists;
  List<List<double>> get dangerHeatmap => _pathfindingService.dangerHeatmap;
  int get pathVersion => _pathfindingService.pathVersion;

  // Enemy management - delegated to EnemyManager
  late final EnemyManager _enemyManager;

  // Enemy accessors (delegate to EnemyManager)
  @override
  List<TdEnemy> get enemies => _enemyManager.enemies;
  List<TdTempSpawn> get tempSpawns => _enemyManager.tempSpawns;
  TdEnemy? get currentBoss => _enemyManager.currentBoss;

  // Tower management - delegated to TowerManager
  late final TowerManager _towerManager;

  // Tower accessors (delegate to TowerManager)
  @override
  List<TdTower> get towers => _towerManager.towers;
  @override
  bool get maxTowersReached => _towerManager.maxTowersReached;

  // Collision detection - delegated to CollisionDetector
  late final CollisionDetector _collisionDetector;

  // Missile accessors (delegate to CollisionDetector)
  @override
  List<TdMissile> get missiles => _collisionDetector.missiles;
  List<TdMissile> get pooledMissiles => _collisionDetector.pooledMissiles;

  // Wave management - delegated to WaveManager
  late final WaveManager _waveManager;

  // Wave state accessors (delegate to WaveManager)
  @override
  int get wave => _waveManager.wave;
  int get spawnCool => _waveManager.spawnCool;
  int get scd => _waveManager.scd;
  set scd(int value) => _waveManager.scd = value;
  int get wcd => _waveManager.wcd;
  bool get toWait => _waveManager.toWait;
  List<String> get newEnemies => _waveManager.newEnemies;

  // Boss mechanics (delegate to WaveManager)
  int get bossesDefeated => _waveManager.bossesDefeated;
  @override
  bool get isBossWave => _waveManager.isBossWave;
  bool get bossSpawned => _waveManager.bossSpawned;
  int get lastTeleportWave => _waveManager.lastTeleportWave;

  // Pink Towers - visual representation of spawnpoints
  @override
  final List<TdEnemyTower> spawnTowers = [];
  TdEnemyTower? bossTower; // Which tower is currently the boss tower

  // Near-exit spawn probability (varies between 5-10% per game)
  late final double nearExitSpawnProbability;

  TdSim({
    required this.baseMap,
    required this.rng,
    required int cash,
    required this.soundService,
    required this.mapKey,
  }) {
    grid = deepCopy2DInt(baseMap.grid);
    exit = baseMap.exit;
    spawnpoints = List<TdCoord>.unmodifiable(baseMap.spawnpoints);

    // Initialize game state
    _gameState = GameState(cash: cash, health: 40, maxHealth: 40);

    // Initialize near-exit spawn probability (5-10% random per game)
    nearExitSpawnProbability =
        GameConstants.nearExitSpawnProbabilityMin +
        (rng.nextDouble() *
            (GameConstants.nearExitSpawnProbabilityMax -
                GameConstants.nearExitSpawnProbabilityMin));

    // Initialize wave manager
    _waveManager = WaveManager(rng: rng, mapKey: mapKey);

    // Initialize enemy manager
    _enemyManager = EnemyManager(baseMap: baseMap, rng: rng);

    // Initialize tower manager
    _towerManager = TowerManager(baseMap: baseMap);

    // Initialize collision detector
    _collisionDetector = CollisionDetector();

    // Initialize pathfinding service
    _pathfindingService = PathfindingService(
      baseMap: baseMap,
      rng: rng,
      grid: grid,
      exit: exit,
      spawnpoints: spawnpoints,
    );

    recalculate();
  }

  @override
  void startGame() {
    // Matches JS resetGame() -> paused = true, wave = 0, then nextWave()
    _gameState.paused = true;
    _enemyManager.clear();
    _towerManager.clear();
    _collisionDetector.clear();

    // Reset wave manager
    _waveManager.reset();

    // Boss mechanics reset
    bossTower = null;
    spawnTowers.clear();

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

  void _swapDualUSpawners() {
    // Dual-U map: Swap inner spawners with outer spawners
    // Assumes 4 spawners: [0,1] = inner, [2,3] = outer
    if (spawnTowers.length != 4) return;

    // Swap positions: inner <-> outer
    final temp0Col = spawnTowers[0].col;
    final temp0Row = spawnTowers[0].row;
    final temp1Col = spawnTowers[1].col;
    final temp1Row = spawnTowers[1].row;

    // Inner spawners take outer positions
    spawnTowers[0].col = spawnTowers[2].col;
    spawnTowers[0].row = spawnTowers[2].row;
    spawnTowers[1].col = spawnTowers[3].col;
    spawnTowers[1].row = spawnTowers[3].row;

    // Outer spawners take inner positions
    spawnTowers[2].col = temp0Col;
    spawnTowers[2].row = temp0Row;
    spawnTowers[3].col = temp1Col;
    spawnTowers[3].row = temp1Row;

    // Recalculate paths after swap
    recalculate();
  }

  void _teleportSpawnTowers() {
    final oldPositions = _saveOldTowerPositions();
    _markOldPositionsWalkable(oldPositions);
    recalculate();

    final (nearExitTiles, farTiles) = _findValidTeleportTiles();
    _assignTowerPositions(nearExitTiles, farTiles);
    _updateGridAfterTeleport(oldPositions);
    recalculate();
  }

  List<TdCoord> _saveOldTowerPositions() {
    return spawnTowers.map((t) => TdCoord(t.col, t.row)).toList();
  }

  void _markOldPositionsWalkable(List<TdCoord> oldPositions) {
    for (final pos in oldPositions) {
      grid[pos.x][pos.y] = 0;
    }
  }

  (List<TdCoord>, List<TdCoord>) _findValidTeleportTiles() {
    final nearExitTiles = <TdCoord>[];
    final farTiles = <TdCoord>[];

    for (int c = 0; c < baseMap.cols; c++) {
      for (int r = 0; r < baseMap.rows; r++) {
        if (!_isValidTeleportTile(c, r)) continue;

        final distToExit = (exit.x - c).abs() + (exit.y - r).abs();
        if (distToExit <= GameConstants.nearExitDistance) {
          nearExitTiles.add(TdCoord(c, r));
        } else {
          farTiles.add(TdCoord(c, r));
        }
      }
    }

    return (nearExitTiles, farTiles);
  }

  bool _isValidTeleportTile(int c, int r) {
    if (grid[c][r] != 0) return false;
    if (exit.x == c && exit.y == r) return false;
    if (paths[c][r] == 0) return false;

    for (final t in spawnTowers) {
      if (t.col == c && t.row == r) return false;
    }
    return true;
  }

  void _assignTowerPositions(
    List<TdCoord> nearExitTiles,
    List<TdCoord> farTiles,
  ) {
    nearExitTiles.shuffle(rng);
    farTiles.shuffle(rng);

    final shouldSpawnNearExit = rng.nextDouble() < nearExitSpawnProbability;
    bool nearExitTileAssigned = false;

    for (int i = 0; i < spawnTowers.length; i++) {
      if (shouldSpawnNearExit &&
          !nearExitTileAssigned &&
          nearExitTiles.isNotEmpty) {
        _assignNearExitPosition(spawnTowers[i], nearExitTiles);
        nearExitTileAssigned = true;
      } else {
        _assignRandomPosition(spawnTowers[i], nearExitTiles, farTiles);
      }
    }
  }

  void _assignNearExitPosition(
    TdEnemyTower tower,
    List<TdCoord> nearExitTiles,
  ) {
    final tile = nearExitTiles.removeAt(0);
    tower.col = tile.x;
    tower.row = tile.y;
    tower.isNearExit = true;
  }

  void _assignRandomPosition(
    TdEnemyTower tower,
    List<TdCoord> nearExitTiles,
    List<TdCoord> farTiles,
  ) {
    final allTiles = [...farTiles, ...nearExitTiles];
    allTiles.shuffle(rng);

    if (allTiles.isEmpty) return;

    final tile = allTiles.removeAt(0);
    tower.col = tile.x;
    tower.row = tile.y;

    final distToExit = (exit.x - tile.x).abs() + (exit.y - tile.y).abs();
    tower.isNearExit = distToExit <= GameConstants.nearExitDistance;

    if (distToExit <= GameConstants.nearExitDistance) {
      nearExitTiles.removeWhere((t) => t.x == tile.x && t.y == tile.y);
    } else {
      farTiles.removeWhere((t) => t.x == tile.x && t.y == tile.y);
    }
  }

  void _updateGridAfterTeleport(List<TdCoord> oldPositions) {
    for (final oldPos in oldPositions) {
      if (!_hasTowerAtPosition(oldPos)) {
        grid[oldPos.x][oldPos.y] = 0;
      }
    }
  }

  bool _hasTowerAtPosition(TdCoord pos) {
    return spawnTowers.any((t) => t.col == pos.x && t.row == pos.y);
  }

  void _convertToBossTower() {
    // Convert one spawn tower to boss tower
    if (spawnTowers.isNotEmpty) {
      final bt = spawnTowers[rng.nextInt(spawnTowers.length)];
      bt.isBossTower = true;
      bossTower = bt;
    }
  }

  @override
  void togglePause() {
    _gameState.paused = !_gameState.paused;
  }

  void nextWave() {
    _waveManager.nextWave();

    // Handle boss wave
    if (isBossWave) {
      _convertToBossTower();
      spawnBoss();
    } else {
      // Reset boss tower status after boss wave
      bossTower?.isBossTower = false;
      bossTower = null;

      // Teleport Pink Towers every 2 waves (only on non-boss waves)
      if (_waveManager.shouldTeleportSpawners()) {
        // Special case: Dual-U map swaps spawners instead of teleporting
        if (mapKey == 'dualU') {
          _swapDualUSpawners();
        } else {
          _teleportSpawnTowers();
        }
        _waveManager.markSpawnersTeleported();
      }
    }
  }

  void spawnBoss() {
    if (bossSpawned || !isBossWave) return;
    final bt = bossTower;
    if (bt == null) return;

    // Ensure boss tower position has a valid path
    final bossCol = bt.col;
    final bossRow = bt.row;

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
    _enemyManager.currentBoss = TdEnemy(
      posX: bt.col + 0.5,
      posY: bt.row + 0.5,
      type: enemyTypes['boss']!,
      rng: rng,
    );
    // Boost boss health based on wave number
    // Balanced for typical player tower setup at each wave
    // Wave 5 (1st boss): 800 HP (~15-20 sec with 2-3 gun towers)
    // Wave 10 (2nd boss): 1200 HP (~20-30 sec with upgraded towers)
    // Wave 15+ (3rd+ boss): +25% per boss
    double healthMultiplier;
    if (bossesDefeated == 0) {
      // First boss at wave 5: manageable with basic gun towers
      healthMultiplier = 0.16; // 5000 * 0.16 = 800 HP
    } else if (bossesDefeated == 1) {
      // Second boss at wave 10: players should have better towers
      healthMultiplier = 0.24; // 5000 * 0.24 = 1200 HP
    } else {
      // Subsequent bosses: moderate exponential scaling
      healthMultiplier = 0.24 * pow(1.25, bossesDefeated - 1);
    }
    _enemyManager.currentBoss!.health *= healthMultiplier;
    _enemyManager.currentBoss!.maxHealth = _enemyManager.currentBoss!.health;
    enemies.add(_enemyManager.currentBoss!);
    _waveManager.markBossSpawned();
  }

  void onBossDefeated() {
    _waveManager.onBossDefeated();
    _enemyManager.currentBoss = null;

    // Heal player by 10 HP using GameState
    _gameState.applyHeal(GameConstants.bossHealAmount);

    // Revert boss tower back to normal spawn tower
    bossTower?.isBossTower = false;
    bossTower = null;
  }

  bool get noMoreEnemies => enemies.isEmpty && _waveManager.noMoreEnemies;

  bool canSpawn() => _waveManager.canSpawn();

  /// One simulation tick (60Hz steps with frame-rate independence).
  @override
  void step() {
    stepWithDelta(GameConstants.simSecondsPerTick);
  }

  /// Frame-rate independent step with delta time
  void stepWithDelta(double dt) {
    if (_gameState.isGameOver) return;

    if (!paused) {
      _waveManager.updateCooldowns();
    }

    // Spawn enemies from Pink Tower positions
    if (!paused && canSpawn()) {
      final name = newEnemies.removeAt(0);
      _enemyManager.spawnFromTowers(
        spawnTowers: spawnTowers,
        enemyTypeName: name,
        currentWave: wave,
      );
      _waveManager.resetSpawnCooldown();
    }

    // Decay danger heatmap over time (adaptive pathfinding)
    if (!paused) {
      // Delegate danger heatmap update to pathfinding service
      if (_pathfindingService.updateDangerHeatmap()) {
        recalculate();
      }
    }

    // Update enemies with delta time for frame-rate independence
    if (!paused) {
      _enemyManager.updateEnemies(
        sim: this,
        dt: dt,
        paused: paused,
        exit: exit,
        onEnemyReachExit: (damage) {
          final causedGameOver = _gameState.takeDamage(damage);
          // Force stop game if game over occurred
          if (causedGameOver) {
            paused = true;
          }
        },
        onBossDefeated: onBossDefeated,
      );
      _enemyManager.updateSpatialGrid();
    }

    // Update towers (target + attack when cd==0)
    _towerManager.updateTowers(sim: this, paused: paused);

    // Update missiles (projectiles) and return dead ones to pool
    _collisionDetector.updateMissiles(sim: this, paused: paused);

    // Enemy death effects (cash + temp spawns) happens inside dealDamage.

    // Wave progression
    if (!paused) {
      if (_waveManager.shouldProgressWave(noMoreEnemies)) {
        nextWave();
      }
    }

    // Update heal effect timer using GameState
    _gameState.updateHealEffect();

    // Auto-recalculate when towers were placed/sold (caller sets this).
    // We always recalculate immediately after changes from the UI layer.
  }

  void recalculate() {
    // Delegate pathfinding to PathfindingService
    _pathfindingService.recalculate(hasTowerAt);
  }

  @override
  TdTower? getTowerAt(int col, int row) {
    return _towerManager.getTowerAt(col, row);
  }

  @override
  bool hasTowerAt(int col, int row) => _towerManager.hasTowerAt(col, row);

  bool walkableForPlacement(int col, int row) {
    final g = grid[col][row];
    // Grid value 0 and 2 are buildable
    // 0 = Empty (buildable)
    // 1 = Wall/Scenery (blocked)
    // 2 = Enemy Path (buildable, but path will recalculate when tower placed)
    // 3 = Water/Void (blocked for building, enemies can't walk here)
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

  @override
  bool placeable(int col, int row) {
    // Delegate placement validation to PathfindingService
    return _pathfindingService.isPlaceable(
      col: col,
      row: row,
      walkableForPlacement: walkableForPlacement,
      enemies: enemies,
      spawnTowers: spawnTowers,
    );
  }

  @override
  bool canPlaceTower(TdTowerType towerType, int col, int row) {
    return _towerManager.canPlaceTower(
      towerType: towerType,
      col: col,
      row: row,
      grid: grid,
      spawnpoints: spawnpoints,
      exit: exit,
      enemies: enemies,
      isPlaceable: placeable,
    );
  }

  @override
  void placeTower(TdTowerType towerType, int col, int row) {
    if (!canPlaceTower(towerType, col, row)) return;
    _towerManager.placeTower(
      towerType: towerType,
      col: col,
      row: row,
      enemies: enemies,
      onRecalculate: recalculate,
    );
  }

  @override
  void sellTower(TdTower tower) {
    final sellPrice = _towerManager.sellTower(tower);
    if (sellPrice > 0) {
      cash += sellPrice;
      recalculate();
    }
  }

  @override
  void upgradeTower(TdTower tower, int upgradeCost) {
    if (_towerManager.upgradeTower(
      tower: tower,
      upgradeCost: upgradeCost,
      currentCash: cash,
    )) {
      // Deduct cash
      cash -= upgradeCost;
    }
  }

  TdEnemy? getFirstTarget(List<TdEnemy> candidates) {
    return _enemyManager.getFirstTarget(candidates, dists);
  }

  TdEnemy? getStrongestTarget(List<TdEnemy> candidates) {
    return _enemyManager.getStrongestTarget(candidates);
  }

  TdEnemy? getNearestTarget(
    List<TdEnemy> enemies,
    TdEnemy from,
    List<TdEnemy> ignore,
  ) {
    return _enemyManager.getNearestTarget(enemies, from, ignore);
  }

  @override
  List<TdEnemy> enemiesInRange(double cx, double cy, int radiusTiles) {
    return _enemyManager.enemiesInRange(cx, cy, radiusTiles);
  }

  @override
  List<TdEnemy> enemiesInExplosionRange(
    double cx,
    double cy,
    double blastRadiusTiles,
  ) {
    return _enemyManager.enemiesInExplosionRange(cx, cy, blastRadiusTiles);
  }

  // â”€â”€â”€ Public methods required by entity layer (dynamic-typed calls) â”€â”€â”€â”€â”€â”€â”€

  /// Records that an enemy died at (col, row) for the danger heatmap.
  void recordEnemyDeath(int col, int row) {
    _pathfindingService.recordEnemyDeath(col, row);
  }

  /// Returns enemies near ([x], [y]) within [radius] tiles using the
  /// spatial grid â€” used by Tesla chain lightning targeting.
  List<TdEnemy> getNearbyEnemies(double x, double y, int radius) {
    return _enemyManager.getNearby(x, y, radius);
  }

  /// Fire a missile (delegates to CollisionDetector)
  void fireMissile({
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
    _collisionDetector.fireMissile(
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
