import 'dart:math';

import '../game_constants.dart';
import 'enemy.dart';

int _randIntInclusive(Random rng, int min, int max) {
  if (min > max) return min;
  final v = min + rng.nextDouble() * (max - min);
  return v.round();
}

/// Object pool for [TdMissile] instances — reduces GC pressure at 60 Hz.
class TdMissilePool {
  final List<TdMissile> _available = [];
  final List<TdMissile> _active = [];

  TdMissilePool() {
    for (int i = 0; i < GameConstants.missilePoolInitialCapacity; i++) {
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
      missile = _available.removeLast()
        .._reset(
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
    } else if (_active.length >= GameConstants.missilePoolMaxCapacity) {
      // Recycle oldest active missile when pool is exhausted
      missile = _active.removeAt(0)
        .._reset(
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
    _active.add(missile);
    return missile;
  }

  void release(TdMissile missile) {
    if (_active.remove(missile)) {
      missile._deactivate();
      if (_available.length < GameConstants.missilePoolInitialCapacity) {
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

/// A homing projectile fired by rocket/missile-silo towers.
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

  TdMissile._empty()
    : posX = 0,
      posY = 0,
      target = TdEnemy(
        posX: 0,
        posY: 0,
        type: enemyTypes['weak']!,
        rng: Random(),
      ),
      damageMin = 0,
      damageMax = 0,
      blastRadius = 0,
      rangeTiles = 0,
      speedTilesPerTick = 0,
      lifetimeTicks = 0;

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

  void _deactivate() => alive = false;

  void update(dynamic sim) {
    if (!alive) return;

    if (!target.isAlive) {
      final inRange = (sim.enemiesInRange(posX, posY, rangeTiles) as List)
          .cast<TdEnemy>();
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

    final dx = target.posX - posX;
    final dy = target.posY - posY;
    final distSq = dx * dx + dy * dy;
    final radiusSq = target.type.radiusTiles * target.type.radiusTiles;

    if (distSq < radiusSq) {
      explode(sim);
      return;
    }

    final dist = sqrt(distSq);
    posX += dx / dist * speedTilesPerTick;
    posY += dy / dist * speedTilesPerTick;

    lifetimeTicks--;
    if (lifetimeTicks <= 0) explode(sim);
  }

  void explode(dynamic sim) {
    if (!alive) return;
    alive = false;

    sim.soundService.play('explosion');

    final inRadius =
        (sim.enemiesInExplosionRange(posX, posY, blastRadius) as List)
            .cast<TdEnemy>();
    for (final e in inRadius) {
      final rng = sim.rng as Random;
      final dmg = _randIntInclusive(
        rng,
        damageMin.round(),
        damageMax.round(),
      ).toDouble();
      e.dealDamage(dmg, 'explosion', sim);
    }
  }
}
