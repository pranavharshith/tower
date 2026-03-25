/// Game constants extracted from TdSim to reduce file size
class GameConstants {
  // Simulation
  static const double simSecondsPerTick = 1 / 60;
  static const double baseSpeedTilesPerSecond = 2.5;

  // Status effects (seconds)
  static const double slowDurationSeconds = 0.67; // ~40 ticks at 60Hz
  static const double poisonDurationSeconds = 1.0; // ~60 ticks at 60Hz
  static const double regenDurationSeconds = 1.0;
  static const double minSpeedMultiplier = 0.3; // Speed cap at 30%

  // Wave management
  static const int defaultTicksBetweenWaves = 300;
  static const int minSpawnDistance = 5;
  static const int enemiesPerTempSpawn = 3;

  // Damage modifiers
  static const double resistanceMultiplier = 0.5;
  static const double weaknessMultiplier = 0.5;
  static const double towerSellMultiplier = 0.75;

  // Tower limits
  static const int maxTowers = 21;

  // Boss mechanics
  static const int bossHealAmount = 10;
  static const int bossHealEffectTicks = 60;

  // Near-exit spawn probability range
  static const double nearExitSpawnProbabilityMin = 0.05; // 5%
  static const double nearExitSpawnProbabilityMax = 0.10; // 10%

  // Teleport mechanics
  static const int nearExitDistance = 3;

  // Missile pool
  static const int missilePoolInitialCapacity = 200;
  static const int missilePoolMaxCapacity = 500;

  // Beam emitter
  static const double maxBeamDamage = 500.0;

  // Tile center tolerance
  static const double tileCenterTolerance = 1 / 24.0;
}
