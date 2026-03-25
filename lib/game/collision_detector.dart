import 'td_simulation.dart';
import 'entities/entities.dart';

/// Manages missile lifecycle and collision detection
/// Extracted from TdSim for better separation of concerns
class CollisionDetector {
  // Missile list
  final List<TdMissile> missiles = [];

  // Object pool for missiles to reduce GC pressure
  final TdMissilePool _missilePool = TdMissilePool();

  // Get pooled missiles (for backward compatibility)
  List<TdMissile> get pooledMissiles => _missilePool.active;

  /// Clear all missiles (for game reset)
  void clear() {
    missiles.clear();
  }

  /// Create and add a missile to the simulation
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
    // Use object pool instead of creating new missile
    final missile = _missilePool.acquire(
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
    missiles.add(missile);
  }

  /// Update all missiles and handle collisions
  void updateMissiles({required TdSim sim, required bool paused}) {
    if (paused) return;

    for (int i = missiles.length - 1; i >= 0; i--) {
      final m = missiles[i];
      m.update(sim);
      if (!m.alive) {
        // Return to pool instead of letting GC collect
        _missilePool.release(m);
        missiles.removeAt(i);
      }
    }
  }
}

