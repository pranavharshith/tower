/// Centralized configuration for game balancing and tuning
class TdGameConfig {
  // Difficulty presets
  static const TdGameConfig easy = TdGameConfig._(
    startingHealth: 60,
    ticksBetweenWaves: 180,
  );

  static const TdGameConfig normal = TdGameConfig._();

  static const TdGameConfig hard = TdGameConfig._(
    startingHealth: 30,
    ticksBetweenWaves: 90,
  );

  // Instance values for difficulty scaling
  final int startingHealth;
  final int ticksBetweenWaves;

  const TdGameConfig._({
    this.startingHealth = 40,
    this.ticksBetweenWaves = 120,
  });

  static const int defaultTicksBetweenWaves = 120;
  // Static defaults - use these directly in code
  static const int enemiesPerTempSpawn = 40;
  static const int minSpawnDistance = 15;
  static const double towerPlacementTimeout = 7.0;
  static const double bossAttackIntervalMin = 2.0;
  static const double bossAttackIntervalMax = 4.0;
  static const int maxTowers = 21;
  static const double towerSellMultiplier = 0.8;
  static const double resistanceMultiplier = 0.5;
  static const double weaknessMultiplier = 0.5;
  static const double slowDurationSeconds = 0.67;
  static const double poisonDurationSeconds = 1.0;
  static const double regenDurationSeconds = 1.0;
  static const double minSpeedMultiplier = 0.3;
  static const double nearExitSpeedMultiplier = 0.6;
}
