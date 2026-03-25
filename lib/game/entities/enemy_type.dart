import '../game_constants.dart';
import 'enemy.dart';

// Damage type strings match the JS version: 'physical', 'energy', 'slow', 'poison',
// 'explosion', 'piercing'.

enum TdEnemyType {
  weak(
    key: 'weak',
    color: [189, 195, 199],
    radiusTiles: 0.5,
    cash: 1,
    speed: 1,
    health: 35,
  ),
  strong(
    key: 'strong',
    color: [108, 122, 137],
    radiusTiles: 0.6,
    cash: 1,
    speed: 1,
    health: 75,
  ),
  fast(
    key: 'fast',
    color: [61, 251, 255],
    radiusTiles: 0.5,
    cash: 2,
    speed: 2,
    health: 75,
  ),
  strongFast(
    key: 'strongFast',
    color: [30, 139, 195],
    radiusTiles: 0.5,
    cash: 2,
    speed: 2,
    health: 135,
  ),
  medic(
    key: 'medic',
    color: [192, 57, 43],
    radiusTiles: 0.7,
    cash: 4,
    speed: 1,
    health: 375,
    immune: ['regen'],
    medicTick: true,
  ),
  stronger(
    key: 'stronger',
    color: [52, 73, 94],
    radiusTiles: 0.8,
    cash: 4,
    speed: 1,
    health: 375,
  ),
  faster(
    key: 'faster',
    color: [249, 105, 14],
    radiusTiles: 0.5,
    cash: 4,
    speed: 3,
    health: 375,
    resistant: ['explosion'],
  ),
  tank(
    key: 'tank',
    color: [30, 130, 76],
    radiusTiles: 1,
    cash: 4,
    speed: 1,
    health: 750,
    immune: ['poison', 'slow'],
    resistant: ['energy', 'physical'],
    weaknesses: ['explosion', 'piercing'],
  ),
  taunt(
    key: 'taunt',
    color: [102, 51, 153],
    radiusTiles: 0.8,
    cash: 8,
    speed: 1,
    health: 1500,
    immune: ['poison', 'slow'],
    resistant: ['energy', 'physical'],
    hasTaunt: true,
  ),
  spawner(
    key: 'spawner',
    color: [244, 232, 66],
    radiusTiles: 0.7,
    cash: 10,
    speed: 1,
    health: 1150,
    spawnerTick: true,
  ),
  boss(
    key: 'boss',
    color: [255, 0, 128], // Magenta/pink for boss
    radiusTiles: 1.5,
    cash: 50,
    speed: 0.5, // Slow but powerful
    health: 5000,
    damage: 5, // Boss deals 5 damage per hit
    immune: ['poison', 'slow'],
    resistant: ['physical', 'energy'],
    weaknesses: ['explosion', 'piercing'],
  );

  final String key;
  final List<int> color;
  final double radiusTiles;

  final int cash;
  final double speed; // tiles-per-step*24 scale, matches JS speed.
  final double health;
  final int damage; // Damage dealt to player when reaching exit

  final List<String> immune;
  final List<String> resistant;
  final List<String> weaknesses;

  final bool hasTaunt;

  final bool medicTick;
  final bool spawnerTick;

  const TdEnemyType({
    required this.key,
    required this.color,
    required this.radiusTiles,
    required this.cash,
    required this.speed,
    required this.health,
    this.damage = 1,
    this.immune = const [],
    this.resistant = const [],
    this.weaknesses = const [],
    this.hasTaunt = false,
    this.medicTick = false,
    this.spawnerTick = false,
  });
}

/// Lookup map: enemy type key → [TdEnemyType].
final Map<String, TdEnemyType> enemyTypes = {
  for (final v in TdEnemyType.values) v.key: v,
};

// ---------------------------------------------------------------------------
// StatusManager — prevents effect over-stacking, frame-rate independent durations
// ---------------------------------------------------------------------------

class StatusManager {
  double _slowRemaining = 0.0;
  double _poisonRemaining = 0.0;
  double _regenRemaining = 0.0;
  int _slowStacks = 0;

  bool get isSlowed => _slowRemaining > 0;
  bool get isPoisoned => _poisonRemaining > 0;
  bool get isRegening => _regenRemaining > 0;

  void applySlow([double? durationSeconds]) {
    _slowStacks++;
    _slowRemaining = durationSeconds ?? GameConstants.slowDurationSeconds;
  }

  void applyPoison([double? durationSeconds]) {
    _poisonRemaining = durationSeconds ?? GameConstants.poisonDurationSeconds;
  }

  void applyRegen([double? durationSeconds]) {
    _regenRemaining = durationSeconds ?? GameConstants.regenDurationSeconds;
  }

  double getSpeedMultiplier() {
    if (_slowStacks == 0) return 1.0;
    // Each slow reduces speed by 50%; hard floor at 30% minimum.
    final mult = _slowStacks == 1
        ? 0.5
        : _slowStacks == 2
        ? 0.25
        : 0.125;
    return mult.clamp(GameConstants.minSpeedMultiplier, 1.0);
  }

  void update(double dt) {
    if (_slowRemaining > 0) {
      _slowRemaining -= dt;
      if (_slowRemaining <= 0) {
        _slowRemaining = 0;
        _slowStacks = 0;
      }
    }
    if (_poisonRemaining > 0) _poisonRemaining -= dt;
    if (_regenRemaining > 0) _regenRemaining -= dt;
  }

  void processTicks(TdEnemy enemy, dynamic sim, double dt) {
    if (_poisonRemaining > 0) {
      enemy.applyPoisonDamage(sim, dt);
    }
    if (_regenRemaining > 0 && enemy.health < enemy.maxHealth) {
      enemy.applyRegenHealing(sim, dt);
    }
  }
}
