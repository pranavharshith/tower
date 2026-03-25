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
  group('Pathfinding Edge Cases', () {
    test('Tower placement maintains valid paths', () {
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

      // Place multiple towers and verify paths still work
      int placedCount = 0;
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (placedCount < 5 && sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            placedCount++;

            // Verify exit is still reachable
            expect(sim.dists[sim.exit.x][sim.exit.y], isNotNull);
          }
        }
        if (placedCount >= 5) break;
      }

      expect(placedCount, greaterThan(0));
    });

    test('Recalculation works with enemies on map', () {
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

      // Spawn enemies
      for (int i = 0; i < 10; i++) {
        final enemy = TdEnemy(
          posX: sim.rng.nextDouble() * sim.baseMap.cols.toDouble(),
          posY: sim.rng.nextDouble() * sim.baseMap.rows.toDouble(),
          type: enemyTypes['weak']!,
          rng: sim.rng,
        );
        sim.enemies.add(enemy);
      }

      // Recalculate paths with enemies present - should not throw
      expect(() => sim.recalculate(), returnsNormally);

      // Paths should still be valid
      expect(sim.dists[sim.exit.x][sim.exit.y], equals(0));
    });

    test('Multiple tower placements without intermediate recalculation', () {
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

      // Place 3 towers without recalculating
      final placed = <(int, int)>[];
      for (int c = 0; c < sim.baseMap.cols && placed.length < 3; c++) {
        for (int r = 0; r < sim.baseMap.rows && placed.length < 3; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            placed.add((c, r));
          }
        }
      }

      // Recalculate once after all placements
      expect(() => sim.recalculate(), returnsNormally);

      // Verify all towers are still there
      for (final (c, r) in placed) {
        expect(sim.hasTowerAt(c, r), isTrue);
      }

      // Verify exit is still reachable
      expect(sim.dists[sim.exit.x][sim.exit.y], equals(0));
    });

    test('Stress test: rapid recalculation', () {
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

      // Fill map with towers
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
          }
        }
      }

      // Recalculate 10 times rapidly - should complete without errors
      for (int i = 0; i < 10; i++) {
        expect(() => sim.recalculate(), returnsNormally);
      }
    });
  });
}
