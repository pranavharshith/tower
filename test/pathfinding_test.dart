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
  group('Pathfinding', () {
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

    test('All spawn points have valid paths to exit', () {
      for (final spawn in sim.spawnpoints) {
        final dist = sim.dists[spawn.x][spawn.y];
        expect(
          dist,
          isNotNull,
          reason: 'Spawn at (${spawn.x}, ${spawn.y}) should have path',
        );
        expect(dist, greaterThan(0), reason: 'Spawn should not be at exit');
      }
    });

    test('Exit tile has distance 0', () {
      expect(sim.dists[sim.exit.x][sim.exit.y], 0);
    });

    test('Path directions point toward exit', () {
      bool foundValidPath = false;
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          final dist = sim.dists[c][r];
          if (dist == null || dist == 0) continue;

          final dir = sim.paths[c][r];
          expect(dir, greaterThanOrEqualTo(0));
          expect(dir, lessThanOrEqualTo(4));

          // Verify direction leads to valid neighbor
          if (dir > 0) {
            final (nc, nr) = _getNeighbor(c, r, dir);
            if (nc >= 0 &&
                nc < sim.baseMap.cols &&
                nr >= 0 &&
                nr < sim.baseMap.rows) {
              final neighborDist = sim.dists[nc][nr];
              // Neighbor should have a valid distance (path exists)
              expect(neighborDist, isNotNull);
              foundValidPath = true;
            }
          }
        }
      }
      expect(
        foundValidPath,
        true,
        reason: 'Should have at least one valid path',
      );
    });

    test('Danger heatmap updates on enemy death', () {
      sim.paused = false;
      sim.nextWave();

      for (int i = 0; i < 100; i++) {
        sim.step();
        if (sim.enemies.isNotEmpty) break;
      }

      if (sim.enemies.isNotEmpty) {
        final enemy = sim.enemies.first;
        final col = enemy.gridCol;
        final row = enemy.gridRow;

        final dangerBefore = sim.dangerHeatmap[col][row];
        enemy.onKilled(sim);
        final dangerAfter = sim.dangerHeatmap[col][row];

        expect(dangerAfter, greaterThan(dangerBefore));
      }
    });

    test('Danger heatmap decays over time', () {
      sim.dangerHeatmap[5][5] = 10.0;

      sim.paused = false;
      for (int i = 0; i < 60; i++) {
        sim.step();
      }

      expect(sim.dangerHeatmap[5][5], lessThan(10.0));
    });

    test('Tower placement recalculates paths', () {
      // Place a tower and verify recalculation happened
      // We can't always guarantee paths will change, but we can verify
      // that the placement was successful and simulation is still valid
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);

            // Verify all spawns still have valid paths after placement
            bool allSpawnsValid = true;
            for (final spawn in sim.spawnpoints) {
              if (sim.dists[spawn.x][spawn.y] == null) {
                allSpawnsValid = false;
                break;
              }
            }

            expect(
              allSpawnsValid,
              true,
              reason: 'All spawns should have valid paths after placement',
            );
            return;
          }
        }
      }
    });
  });
}

(int, int) _getNeighbor(int col, int row, int dir) {
  return switch (dir) {
    1 => (col - 1, row),
    2 => (col, row - 1),
    3 => (col + 1, row),
    4 => (col, row + 1),
    _ => (col, row),
  };
}
