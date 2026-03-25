import '../../data/td_maps.dart';
import '../../game/entities/entities.dart';

/// Contract for the game simulation layer.
///
/// [TdGame] and tests interact with [TdSim] through this interface so that
/// simulations can be mocked trivially in unit tests.
abstract class ISimulation {
  // ──────────────────────────── State accessors ────────────────────────────

  int get wave;
  int get health;
  int get maxHealth;
  int get cash;
  set cash(int value);
  bool get paused;
  bool get isBossWave;
  int get healAmount;
  int get healEffectTicks;

  // ──────────────────────────── Entity collections ─────────────────────────

  List<TdTower> get towers;
  List<TdEnemy> get enemies;
  List<TdMissile> get missiles;
  bool get maxTowersReached;

  // ──────────────────────────── Map data ──────────────────────────────────

  TdMapData get baseMap;
  List<List<int>> get grid;
  List<List<int?>> get dists;
  List<TdEnemyTower> get spawnTowers;

  // ──────────────────────────── Lifecycle ──────────────────────────────────

  /// Advance the simulation by one fixed tick (1/60 s).
  void step();

  void togglePause();
  void startGame();

  // ──────────────────────────── Tower operations ───────────────────────────

  bool canPlaceTower(TdTowerType towerType, int col, int row);
  void placeTower(TdTowerType towerType, int col, int row);
  void sellTower(TdTower tower);
  void upgradeTower(TdTower tower, int upgradeCost);
  TdTower? getTowerAt(int col, int row);
  bool hasTowerAt(int col, int row);
  bool placeable(int col, int row);

  // ──────────────────────────── Enemy queries ──────────────────────────────

  List<TdEnemy> enemiesInRange(double cx, double cy, int radiusTiles);
  List<TdEnemy> enemiesInExplosionRange(double cx, double cy, double radius);
}
