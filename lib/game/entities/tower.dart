import 'dart:math';

import '../game_constants.dart';
import 'enemy.dart';

/// Upgrade specification for a tower.
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

  const TowerUpgrade({
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

/// All available player tower types.
enum TdTowerType {
  gun(
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
  laser(
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
  slow(
    key: 'slow',
    title: 'Slow Tower',
    cost: 100,
    range: 3,
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
  sniper(
    key: 'sniper',
    title: 'Sniper Tower',
    cost: 150,
    range: 8,
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
  rocket(
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
  bomb(
    key: 'bomb',
    title: 'Bomb Tower',
    cost: 250,
    range: 3,
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
  tesla(
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
  );

  final String key;
  final String title;
  final int cost;
  final int range;
  final int cooldownMin;
  final int cooldownMax;
  final double damageMin;
  final double damageMax;
  final String type;

  final List<int> color;
  final List<int> secondary;
  final double radiusTiles;

  final TowerUpgrade? upgrade;

  final bool isSniper;
  final bool isRocket;
  final bool isTesla;

  const TdTowerType({
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

/// Lookup map: tower type key → [TdTowerType].
final Map<String, TdTowerType> towerTypes = {
  for (final v in TdTowerType.values) v.key: v,
};

// ---------------------------------------------------------------------------
// Internal helpers (used by TdTower, imported from td_simulation.dart)
// ---------------------------------------------------------------------------

int _randIntInclusive(Random rng, int min, int max) {
  if (min > max) return min;
  final v = min + rng.nextDouble() * (max - min);
  return v.round();
}

double _randDouble(Random rng, double min, double max) {
  if (min > max) return min;
  return min + rng.nextDouble() * (max - min);
}

double _calculateAndDealDamage(
  Random rng,
  TdEnemy target,
  double damageMin,
  double damageMax,
  String damageType,
  dynamic sim,
) {
  final dmg = _randIntInclusive(
    rng,
    damageMin.round(),
    damageMax.round(),
  ).toDouble();
  target.dealDamage(dmg, damageType, sim);
  return dmg;
}

/// A player-placed tower on the game grid.
class TdTower {
  final TdTowerType towerType;

  final int col;
  final int row;

  /// Tile-unit centre position.
  final double posX;
  final double posY;

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

  TdEnemy? lastLaserTarget;
  int laserDuration = 0;

  bool upgraded = false;
  TowerUpgrade? upgrade;
  String? appliedUpgradeName;

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
    appliedUpgradeName = u.title;
  }

  int sellPrice() => (totalCost * GameConstants.towerSellMultiplier).floor();

  bool get canFire => cd == 0;

  void resetCooldown(dynamic sim) {
    cd = _randIntInclusive(sim.rng as Random, cooldownMin, cooldownMax);
  }

  void updateCooldown() {
    if (cd > 0) cd--;
  }

  void tryFire(dynamic sim) {
    final inRange = enemiesInRange(sim);
    if (inRange.isEmpty) return;
    final taunting = inRange.where((e) => e.type.hasTaunt).toList();
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

  List<TdEnemy> enemiesInRange(dynamic sim) =>
      (sim.enemiesInRange(posX, posY, range) as List).cast<TdEnemy>();

  void fireAt(dynamic sim, TdEnemy target) {
    final rng = sim.rng as Random;
    switch (towerType.key) {
      case 'gun':
        _fireDirectDamage(sim, target, rng);
      case 'slow':
        _fireDirectDamage(sim, target, rng);
        if (upgraded) {
          target.applyEffect('poison', 60);
        } else {
          target.applyEffect('slow', 40);
        }
      case 'laser':
        if (upgraded) {
          _fireBeamEmitter(sim, target, rng);
        } else {
          _fireDirectDamage(sim, target, rng);
        }
      case 'sniper':
        _fireDirectDamage(sim, target, rng);
        if (upgraded) _fireRailgunBlast(sim, target, rng);
      case 'rocket':
        _fireRocketProjectile(sim, target);
        sim.soundService.playQuiet('missile', volume: 0.3);
      case 'bomb':
        _fireDirectDamage(sim, target, rng);
        if (upgraded) {
          _fireClusterBomb(sim, target, rng);
        } else {
          _fireBombBlast(sim, target, rng);
        }
      case 'tesla':
        _fireTesla(sim, target, rng);
        sim.soundService.playQuiet('spark', volume: 0.2);
      default:
        _fireDirectDamage(sim, target, rng);
    }
  }

  void _fireDirectDamage(dynamic sim, TdEnemy target, Random rng) {
    _calculateAndDealDamage(rng, target, damageMin, damageMax, type, sim);
    sim.soundService.playQuiet('shoot', volume: 0.3);
  }

  void _fireBeamEmitter(dynamic sim, TdEnemy target, Random rng) {
    if (lastLaserTarget == target) {
      laserDuration++;
    } else {
      lastLaserTarget = target;
      laserDuration = 0;
    }
    final d = _randDouble(rng, damageMin, damageMax);
    final damage = (d * laserDuration).clamp(0.0, GameConstants.maxBeamDamage);
    target.dealDamage(damage, type, sim);
  }

  void _fireRailgunBlast(dynamic sim, TdEnemy target, Random rng) {
    const blastRadius = 1.0;
    final inRadius =
        (sim.enemiesInExplosionRange(target.posX, target.posY, blastRadius)
                as List)
            .cast<TdEnemy>();
    for (final e in inRadius) {
      _calculateAndDealDamage(rng, e, damageMin, damageMax, type, sim);
    }
    sim.soundService.playQuiet('railgun', volume: 0.3);
  }

  void _fireBombBlast(dynamic sim, TdEnemy target, Random rng) {
    const blastRadius = 1.0;
    final inRadius =
        (sim.enemiesInExplosionRange(target.posX, target.posY, blastRadius)
                as List)
            .cast<TdEnemy>();
    for (final e in inRadius) {
      _calculateAndDealDamage(rng, e, damageMin, damageMax, type, sim);
    }
    sim.soundService.playQuiet('explosion', volume: 0.4);
  }

  void _fireClusterBomb(dynamic sim, TdEnemy target, Random rng) {
    const blastRadius = 1.0;
    const segs = 3;
    final a0 = rng.nextDouble() * 2 * pi;
    for (int i = 0; i < segs; i++) {
      final a = 2 * pi / segs * i + a0;
      const d = 2.0;
      final x = target.posX + cos(a) * d;
      final y = target.posY + sin(a) * d;
      final inRadius = (sim.enemiesInExplosionRange(x, y, blastRadius) as List)
          .cast<TdEnemy>();
      for (final e in inRadius) {
        _calculateAndDealDamage(rng, e, damageMin, damageMax, type, sim);
      }
    }
    sim.soundService.playQuiet('explosion', volume: 0.4);
  }

  void _fireRocketProjectile(dynamic sim, TdEnemy target) {
    final speed = upgraded ? 0.25 : 0.1666667;
    final blastRadius = upgraded ? 2.0 : 1.0;
    sim.fireMissile(
      posX: posX,
      posY: posY,
      target: target,
      damageMin: upgraded ? damageMin : 40.0,
      damageMax: upgraded ? damageMax : 60.0,
      blastRadius: blastRadius,
      rangeTiles: 7,
      speedTilesPerTick: speed,
      lifetimeTicks: 60,
    );
  }

  void _fireTesla(dynamic sim, TdEnemy target, Random rng) {
    var dmg = _calculateAndDealDamage(
      rng,
      target,
      damageMin,
      damageMax,
      type,
      sim,
    );
    final targets = <TdEnemy>[];
    var last = target;
    while (dmg > 1) {
      targets.add(last);
      final nearby = (sim.getNearbyEnemies(last.posX, last.posY, 2) as List)
          .cast<TdEnemy>();
      final next = (sim.getNearestTarget(nearby, last, targets) as TdEnemy?);
      if (next == null) break;
      last = next;
      dmg /= 2;
    }
  }
}
