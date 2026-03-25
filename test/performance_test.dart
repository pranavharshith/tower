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
  group('Performance Tests', () {
    test('Simulation step completes within 16ms (60fps)', () {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      final sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 10000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );

      sim.startGame();

      // Place max towers
      int placed = 0;
      for (int c = 0; c < sim.baseMap.cols && placed < 21; c++) {
        for (int r = 0; r < sim.baseMap.rows && placed < 21; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            placed++;
          }
        }
      }

      // Spawn many enemies
      sim.paused = false;
      sim.nextWave();
      for (int i = 0; i < 200; i++) {
        sim.step();
      }

      // Measure step performance
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 60; i++) {
        sim.step();
      }
      stopwatch.stop();

      final avgTimePerStep = stopwatch.elapsedMicroseconds / 60;
      expect(avgTimePerStep, lessThan(16000), reason: 'Should maintain 60fps');
    });

    test('Pathfinding recalculation completes quickly', () {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      final sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 10000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );

      sim.startGame();

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        sim.recalculate();
      }
      stopwatch.stop();

      final avgTime = stopwatch.elapsedMicroseconds / 100;
      expect(avgTime, lessThan(5000), reason: 'Recalculation should be fast');
    });

    test('Spatial grid query is efficient', () {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      final sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 10000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );

      sim.startGame();

      // Spawn many enemies
      for (int i = 0; i < 100; i++) {
        final enemy = TdEnemy(
          posX: sim.rng.nextDouble() * sim.baseMap.cols,
          posY: sim.rng.nextDouble() * sim.baseMap.rows,
          type: enemyTypes['weak']!,
          rng: sim.rng,
        );
        sim.enemies.add(enemy);
      }

      // Update spatial grid through simulation step
      sim.step();

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        // Use public method through sim
        sim.enemiesInRange(5.0, 5.0, 2);
      }
      stopwatch.stop();

      final avgTime = stopwatch.elapsedMicroseconds / 1000;
      expect(avgTime, lessThan(100), reason: 'Spatial query should be O(1)');
    });

    test('Missile pool prevents excessive allocations', () {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      final sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 10000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );

      sim.startGame();

      // Place a bomb tower to generate missiles
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.bomb, c, r)) {
            sim.placeTower(TdTowerType.bomb, c, r);
            final tower = sim.getTowerAt(c, r)!;

            // Spawn enemy in range
            final enemy = TdEnemy(
              posX: tower.posX + 1,
              posY: tower.posY,
              type: enemyTypes['weak']!,
              rng: sim.rng,
            );
            sim.enemies.add(enemy);

            // Fire many times
            for (int i = 0; i < 100; i++) {
              tower.cd = 0;
              tower.tryFire(sim);
              sim.step();
              sim.step();
              sim.step();
            }

            // Pool should reuse missiles efficiently
            // Active missiles + missiles in flight should be reasonable
            final totalMissiles =
                sim.pooledMissiles.length + sim.missiles.length;
            expect(
              totalMissiles,
              lessThan(200),
              reason: 'Pool should prevent excessive allocations',
            );
            return;
          }
        }
      }
    });
  });
}
