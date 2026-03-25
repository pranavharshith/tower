import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/core/interfaces/i_sound_service.dart';
import 'package:flutter_tower/game/td_simulation.dart';
import 'package:flutter_tower/data/td_maps.dart';
import 'package:flutter_tower/game/entities/entities.dart';

class _MockSoundService implements ISoundService {
  @override
  bool get isEnabled => false;
  @override
  void setEnabled(bool enabled) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play(
    String soundName, {
    double volume = 1.0,
    double rate = 1.0,
  }) async {}
  @override
  Future<void> playQuiet(String soundName, {double volume = 0.3}) async {}
  @override
  Future<void> stopAll() async {}
  @override
  void dispose() {}
}

void main() {
  group('Enemy Mechanics', () {
    late TdSim sim;

    setUp(() {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 1000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );
      sim.startGame();
    });

    test('Enemy spawns at spawn tower position', () {
      sim.paused = false;
      sim.nextWave();

      for (int i = 0; i < 100; i++) {
        sim.step();
        if (sim.enemies.isNotEmpty) break;
      }

      expect(sim.enemies, isNotEmpty);
      final enemy = sim.enemies.first;

      bool nearSpawnTower = false;
      for (final tower in sim.spawnTowers) {
        final dx = (enemy.posX - (tower.col + 0.5)).abs();
        final dy = (enemy.posY - (tower.row + 0.5)).abs();
        if (dx < 0.1 && dy < 0.1) {
          nearSpawnTower = true;
          break;
        }
      }
      expect(nearSpawnTower, true);
    });

    test('Enemy takes damage correctly', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );

      final healthBefore = enemy.health;
      enemy.dealDamage(10, 'physical', sim);

      expect(enemy.health, lessThan(healthBefore));
      expect(enemy.alive, true);
    });

    test('Enemy dies when health reaches zero', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );
      sim.enemies.add(enemy);

      enemy.dealDamage(1000, 'physical', sim);

      expect(enemy.health, lessThanOrEqualTo(0));
      expect(enemy.alive, false);
    });

    test('Enemy grants cash on death', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );

      final cashBefore = sim.cash;
      enemy.onKilled(sim);

      expect(sim.cash, cashBefore + enemy.type.cash);
    });

    test('Immune enemies take no damage from immune types', () {
      final tank = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['tank']!,
        rng: sim.rng,
      );

      final healthBefore = tank.health;
      tank.dealDamage(100, 'poison', sim);

      expect(tank.health, healthBefore); // No damage from poison
    });

    test('Resistant enemies take reduced damage', () {
      final tank = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['tank']!,
        rng: sim.rng,
      );

      final healthBefore = tank.health;
      tank.dealDamage(100, 'physical', sim);

      final damageTaken = healthBefore - tank.health;
      expect(damageTaken, lessThan(100)); // Reduced damage
    });

    test('Weak enemies take increased damage', () {
      final tank = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['tank']!,
        rng: sim.rng,
      );

      final healthBefore = tank.health;
      tank.dealDamage(100, 'explosion', sim);

      final damageTaken = healthBefore - tank.health;
      expect(damageTaken, greaterThan(100)); // Increased damage
    });

    test('Slow effect reduces enemy speed', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['fast']!,
        rng: sim.rng,
      );

      enemy.applyEffectSeconds('slow', 1.0);
      enemy.update(sim, 1 / 60);

      // Speed should be reduced (velocity magnitude should be less than base)
      final velocityMag = (enemy.velX.abs() + enemy.velY.abs());
      expect(velocityMag, lessThan(enemy.speed * 2.5 / 60));
    });

    test('Poison effect deals damage over time', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );
      sim.enemies.add(enemy); // Add to sim for proper update

      final healthBefore = enemy.health;
      enemy.applyEffectSeconds('poison', 3.0); // 3 seconds = ~3 damage

      // Simulate 3 seconds (180 ticks at 60Hz)
      for (int i = 0; i < 180; i++) {
        enemy.update(sim, 1 / 60);
      }

      // Should have taken at least 2 damage (poison deals 1 per second)
      expect(enemy.health, lessThan(healthBefore - 1));
    });
  });

  group('Pathfinding Edge Cases', () {
    test('Handles blocked paths gracefully', () {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      final sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 1000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );
      sim.startGame();

      // Block a path with towers
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);

            // Verify at least one spawn still has a path
            bool hasValidPath = false;
            for (final spawn in sim.spawnpoints) {
              if (sim.dists[spawn.x][spawn.y] != null) {
                hasValidPath = true;
                break;
              }
            }

            if (!hasValidPath) {
              // If we blocked all paths, placement should have been prevented
              fail('Tower placement blocked all paths');
            }

            return;
          }
        }
      }
    });
  });
}
