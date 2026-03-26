import 'dart:math';

import '../game_constants.dart';
import '../game_utils.dart';
import '../../data/td_maps.dart';
import 'enemy_type.dart';

// Forward-declared to break circular import — TdSim is defined in td_simulation.dart
// but entities need access to it for onKilled callbacks and sim-level state.
// The barrel td_simulation.dart re-exports all entities so callers only import one file.
export 'enemy_type.dart';

/// Represents a live enemy unit on the map.
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

  late final double _baseSpeed;

  // Frame-rate independent status effects
  final StatusManager _statusManager = StatusManager();

  // Accumulators for fractional damage/healing (frame-rate independence)
  double _poisonAccumulator = 0.0;
  double _regenAccumulator = 0.0;

  // Boss attack timing (seconds)
  double bossAttackTimer = 0.0;
  double bossNextAttackTime = 3.0;

  // Individual pathfinding personality for emergent behaviour
  late final double riskTolerance;
  late final double explorationBias;

  // OPTIMIZATION: Cache direction to reduce pathfinding calculations
  int _cachedDirection = 0;
  int _directionCacheFrames = 0;
  static const int _directionCacheDuration = 3; // Cache for 3 frames
  
  // Performance optimization: only check blockage if path version changed
  int _lastPathVersion = -1;

  // OPTIMIZATION: Throttle medic healing queries (every 10 frames instead of every frame)
  int _medicHealFrames = 0;
  static const int _medicHealInterval =
      10; // Heal every 10 frames (~6 times/sec)

  TdEnemy({
    required this.posX,
    required this.posY,
    required this.type,
    Random? rng,
  }) {
    health = type.health;
    maxHealth = health;
    _baseSpeed = type.speed;
    speed = _baseSpeed;
    final random = rng ?? Random();
    riskTolerance = random.nextDouble();
    explorationBias = random.nextDouble() * 0.5;
  }

  bool get isAlive => alive;

  int get gridCol => posX.floor();
  int get gridRow => posY.floor();

  void applyEffect(String name, int durationTicks) {
    final durationSeconds = durationTicks / 60.0;
    applyEffectSeconds(name, durationSeconds);
  }

  void applyEffectSeconds(String name, double durationSeconds) {
    if (type.immune.contains(name)) return;
    if (name == 'slow') {
      _statusManager.applySlow(durationSeconds);
    } else if (name == 'poison') {
      _statusManager.applyPoison(durationSeconds);
    } else if (name == 'regen') {
      _statusManager.applyRegen(durationSeconds);
    }
  }

  /// Deal [amt] damage of [typeName] to this enemy, via [sim] for callbacks.
  void dealDamage(double amt, String typeName, dynamic sim) {
    if (!alive) return;
    double mult = 1.0;
    if (type.immune.contains(typeName)) {
      mult = 0.0;
    } else if (type.resistant.contains(typeName)) {
      mult = 1 - GameConstants.resistanceMultiplier;
    } else if (type.weaknesses.contains(typeName)) {
      mult = 1 + GameConstants.weaknessMultiplier;
    }
    if (health > 0) health -= amt * mult;
    if (health <= 0) onKilled(sim);
  }

  void onKilled(dynamic sim) {
    if (!alive) return;
    alive = false;
    sim.cash = sim.cash + type.cash;
    sim.recordEnemyDeath(gridCol, gridRow);
    if (type.spawnerTick) {
      final c = TdCoord(gridCol, gridRow);
      if (c == sim.exit) return;
      for (final ts in sim.tempSpawns as List<TdTempSpawn>) {
        if (ts.pos == c) return;
      }
      (sim.tempSpawns as List<TdTempSpawn>).add(
        TdTempSpawn(pos: c, remaining: GameConstants.enemiesPerTempSpawn),
      );
    }
  }

  void kill() => alive = false;

  /// Frame-rate independent update using delta time.
  void update(dynamic sim, double dt) {
    _updateStatusEffects(sim, dt);
    _updateMovement(sim, dt);
  }

  void _updateStatusEffects(dynamic sim, double dt) {
    _statusManager.update(dt);
    _processTicks(sim, dt);

    // OPTIMIZATION: Throttle medic healing to every 10 frames instead of every frame
    if (type.medicTick) {
      _medicHealFrames++;
      if (_medicHealFrames >= _medicHealInterval) {
        _medicHealFrames = 0;
        final affected = sim.enemiesInExplosionRange(posX, posY, 2.0) as List;
        for (final other in affected) {
          (other as TdEnemy).applyEffectSeconds(
            'regen',
            GameConstants.regenDurationSeconds,
          );
        }
      }
    }
    if (type.key == 'boss') {
      bossAttackTimer += dt;
    }
  }

  void _processTicks(dynamic sim, double dt) {
    if (_statusManager.isPoisoned) {
      applyPoisonDamage(sim, dt);
    }
    if (_statusManager.isRegening && health < maxHealth) {
      applyRegenHealing(sim, dt);
    }
  }

  void applyPoisonDamage(dynamic sim, double dt) {
    _poisonAccumulator += dt;
    while (_poisonAccumulator >= 1.0) {
      dealDamage(1, 'poison', sim);
      _poisonAccumulator -= 1.0;
    }
  }

  void applyRegenHealing(dynamic sim, double dt) {
    _regenAccumulator += dt;
    while (_regenAccumulator >= 1.0) {
      if ((sim.rng as Random).nextDouble() < 0.2) {
        health = (health + 1).clamp(0.0, maxHealth);
      }
      _regenAccumulator -= 1.0;
    }
  }

  void _updateMovement(dynamic sim, double dt) {
    final speedMultiplier = _statusManager.getSpeedMultiplier();
    final currentSpeed = _baseSpeed * speedMultiplier;

    final simPathVersion = sim.pathVersion as int;
    final needsPathRefresh = _lastPathVersion != simPathVersion;
    if (needsPathRefresh) {
      _directionCacheFrames = 0; // invalidate cached direction on any path change
    }

    final isAtCenter = atTileCenter(posX, posY, gridCol, gridRow);
    if (sim.hasTowerAt(gridCol, gridRow)) {
      // Emergency escape: never allow enemies to stay on a tower tile.
      final escapeDir = _findEscapeDirection(sim, gridCol, gridRow);
      if (escapeDir == 0) {
        velX = 0;
        velY = 0;
        return;
      }
      final velocity =
          currentSpeed * GameConstants.baseSpeedTilesPerSecond * dt;
      _setVelocityFromDirection(escapeDir, velocity);
      posX += velX;
      posY += velY;
      return;
    }
    if (isAtCenter) {
      if (!_isInBounds(sim)) return;
      _lastPathVersion = simPathVersion; // Updated to current version
      final dir = _chooseDirection(sim);
      final velocity =
          currentSpeed * GameConstants.baseSpeedTilesPerSecond * dt;
      _setVelocityFromDirection(dir, velocity);
    } else {
      // Not at center - only check for blockage if path version changed (performance optimization)
      if (needsPathRefresh && (velX != 0 || velY != 0)) {
        final dists = sim.dists as List<List<int?>>;
        final nextCol = gridCol + velX.sign.toInt();
        final nextRow = gridRow + velY.sign.toInt();

        if (nextCol >= 0 &&
            nextCol < dists.length &&
            nextRow >= 0 &&
            nextRow < dists[0].length) {
          if (dists[nextCol][nextRow] == null ||
              sim.hasTowerAt(nextCol, nextRow)) {
            // Target tile is now blocked! 
            // PERFORMANCE: Only re-path once per version change
            _lastPathVersion = simPathVersion; 
            
            // VISUAL POLISH: Instead of hard snapping, reverse velocity 
            // back towards the center of the CURRENT tile. 
            // The next time we reach atTileCenter, we'll pick a proper path.
            final velocity =
                currentSpeed * GameConstants.baseSpeedTilesPerSecond * dt;
            _setVelocityTowardsCenter(velocity);
            _directionCacheFrames = 0; // Force immediate re-path upon reaching center
          }
        }
      }
    }

    posX += velX;
    posY += velY;
  }

  bool _isInBounds(dynamic sim) {
    final col = gridCol;
    final row = gridRow;
    return col >= 0 &&
        row >= 0 &&
        col < sim.baseMap.cols &&
        row < sim.baseMap.rows;
  }

  // Returns direction: 1=left 2=up 3=right 4=down 0=none
  int _chooseDirection(dynamic sim) {
    // OPTIMIZATION: Use cached direction if still valid
    if (_directionCacheFrames > 0) {
      if (_isCachedDirectionValid(sim)) {
        _directionCacheFrames--;
        return _cachedDirection;
      }
      _directionCacheFrames = 0;
    }

    final col = gridCol;
    final row = gridRow;
    final cols = sim.baseMap.cols as int;
    final rows = sim.baseMap.rows as int;
    if (col < 0 || row < 0 || col >= cols || row >= rows) return 0;

    final dists = sim.dists as List<List<int?>>;
    final currentDist = dists[col][row];
    if (currentDist == null || currentDist == 0) return 0;

    final neighbors = [
      [col - 1, row, 1],
      [col, row - 1, 2],
      [col + 1, row, 3],
      [col, row + 1, 4],
    ];

    final optimalDirs = <int>[];
    final dirScores = <double>[];

    final dangerHeatmap = sim.dangerHeatmap as List<List<double>>;

    for (final neighbor in neighbors) {
      final nc = neighbor[0];
      final nr = neighbor[1];
      final dir = neighbor[2];
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      final neighborDist = dists[nc][nr];
      if (neighborDist == null) continue;
      if (sim.hasTowerAt(nc, nr)) continue;
      if (neighborDist < currentDist) {
        final danger = dangerHeatmap[nc][nr];
        final dangerPenalty = danger * (1.0 - riskTolerance);
        final explorationNoise =
            ((sim.rng as Random).nextDouble() - 0.5) * explorationBias * 2.0;
        final score =
            neighborDist.toDouble() + dangerPenalty + explorationNoise;
        optimalDirs.add(dir);
        dirScores.add(score);
      }
    }

    if (optimalDirs.isEmpty) return 0;
    int bestIndex = 0;
    double bestScore = dirScores[0];
    for (int i = 1; i < dirScores.length; i++) {
      if (dirScores[i] < bestScore) {
        bestScore = dirScores[i];
        bestIndex = i;
      }
    }

    // Cache the chosen direction
    _cachedDirection = optimalDirs[bestIndex];
    _directionCacheFrames = _directionCacheDuration;
    return _cachedDirection;
  }

  bool _isCachedDirectionValid(dynamic sim) {
    if (_cachedDirection == 0) return false;
    final col = gridCol;
    final row = gridRow;
    final cols = sim.baseMap.cols as int;
    final rows = sim.baseMap.rows as int;
    if (col < 0 || row < 0 || col >= cols || row >= rows) return false;
    final dists = sim.dists as List<List<int?>>;
    final currentDist = dists[col][row];
    if (currentDist == null || currentDist == 0) return false;
    final next = _neighborFromDir(col, row, _cachedDirection);
    final nc = next.x;
    final nr = next.y;
    if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) return false;
    final neighborDist = dists[nc][nr];
    if (neighborDist == null) return false;
    if (sim.hasTowerAt(nc, nr)) return false;
    return neighborDist < currentDist;
  }

  int _findEscapeDirection(dynamic sim, int col, int row) {
    final cols = sim.baseMap.cols as int;
    final rows = sim.baseMap.rows as int;
    final dists = sim.dists as List<List<int?>>;
    int bestDir = 0;
    int? bestDist;

    final neighbors = [
      [col - 1, row, 1],
      [col, row - 1, 2],
      [col + 1, row, 3],
      [col, row + 1, 4],
    ];

    for (final neighbor in neighbors) {
      final nc = neighbor[0];
      final nr = neighbor[1];
      final dir = neighbor[2];
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      if (sim.hasTowerAt(nc, nr)) continue;
      final nd = dists[nc][nr];
      if (nd == null) continue;
      if (bestDist == null || nd < bestDist) {
        bestDist = nd;
        bestDir = dir;
      }
    }
    return bestDir;
  }

  TdCoord _neighborFromDir(int col, int row, int dir) {
    switch (dir) {
      case 1:
        return TdCoord(col - 1, row);
      case 2:
        return TdCoord(col, row - 1);
      case 3:
        return TdCoord(col + 1, row);
      case 4:
        return TdCoord(col, row + 1);
      default:
        return TdCoord(col, row);
    }
  }

  void _setVelocityTowardsCenter(double velocity) {
    // Point velocity back towards the center of the current tile (gridCol + 0.5, gridRow + 0.5)
    final targetX = gridCol + 0.5;
    final targetY = gridRow + 0.5;
    final dx = targetX - posX;
    final dy = targetY - posY;
    final angle = atan2(dy, dx);
    velX = cos(angle) * velocity;
    velY = sin(angle) * velocity;
  }

  void _setVelocityFromDirection(int dir, double velocity) {
    switch (dir) {
      case 1:
        velX = -velocity;
        velY = 0;
      case 2:
        velY = -velocity;
        velX = 0;
      case 3:
        velX = velocity;
        velY = 0;
      case 4:
        velY = velocity;
        velX = 0;
      default:
        velX = 0;
        velY = 0;
    }
  }
}

/// Temporary spawn point created when a spawner enemy dies.
class TdTempSpawn {
  final TdCoord pos;
  int remaining;
  TdTempSpawn({required this.pos, required this.remaining});
}
