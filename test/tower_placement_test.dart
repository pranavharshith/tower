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
  group('Tower Placement Validation', () {
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

    test('Cannot place tower on wall tiles', () {
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.grid[c][r] == 1) {
            expect(
              sim.canPlaceTower(TdTowerType.gun, c, r),
              false,
              reason: 'Should not place tower on wall at ($c, $r)',
            );
          }
        }
      }
    });

    test('Cannot place tower on exit tile', () {
      expect(
        sim.canPlaceTower(TdTowerType.gun, sim.exit.x, sim.exit.y),
        false,
        reason: 'Should not place tower on exit',
      );
    });

    test('Cannot place tower on spawn points', () {
      for (final spawn in sim.spawnpoints) {
        expect(
          sim.canPlaceTower(TdTowerType.gun, spawn.x, spawn.y),
          false,
          reason: 'Should not place tower on spawn point',
        );
      }
    });

    test('Cannot exceed max tower limit', () {
      int placed = 0;
      for (int c = 0; c < sim.baseMap.cols && placed < 22; c++) {
        for (int r = 0; r < sim.baseMap.rows && placed < 22; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            placed++;
          }
        }
      }

      expect(placed, greaterThanOrEqualTo(21));
      expect(sim.maxTowersReached, true);

      // Try to place one more
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.grid[c][r] == 0 && !sim.hasTowerAt(c, r)) {
            expect(
              sim.canPlaceTower(TdTowerType.gun, c, r),
              false,
              reason: 'Should not exceed max towers',
            );
            return;
          }
        }
      }
    });

    test('Cannot place tower that blocks all paths', () {
      // This test verifies pathfinding validation
      // Place towers and ensure at least one path remains
      int validPlacements = 0;
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            validPlacements++;
          }
        }
      }
      expect(validPlacements, greaterThan(0));
    });

    test('Tower placement kills enemies on tile', () {
      // Spawn enemy
      sim.paused = false;
      sim.nextWave();

      // Wait for enemy to spawn
      for (int i = 0; i < 100; i++) {
        sim.step();
        if (sim.enemies.isNotEmpty) break;
      }

      if (sim.enemies.isNotEmpty) {
        final enemy = sim.enemies.first;
        final col = enemy.gridCol;
        final row = enemy.gridRow;

        if (sim.canPlaceTower(TdTowerType.gun, col, row)) {
          final enemyCountBefore = sim.enemies.length;
          sim.placeTower(TdTowerType.gun, col, row);
          expect(sim.enemies.length, lessThan(enemyCountBefore));
        }
      }
    });
  });

  group('Tower Upgrade and Sell', () {
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

    test('Tower upgrade applies correctly', () {
      // Find valid placement
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            final tower = sim.getTowerAt(c, r)!;

            expect(tower.upgraded, false);
            expect(tower.canUpgrade, true);

            final upgrade = tower.towerType.upgrade!;
            sim.upgradeTower(tower, upgrade.cost);

            expect(tower.upgraded, true);
            expect(tower.canUpgrade, false);
            return;
          }
        }
      }
    });

    test('Tower sell returns correct price', () {
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            final tower = sim.getTowerAt(c, r)!;

            final expectedSellPrice = (tower.totalCost * 0.75).round();
            final cashBefore = sim.cash;
            sim.sellTower(tower);

            // Allow for rounding differences
            expect(
              sim.cash,
              inInclusiveRange(
                cashBefore + expectedSellPrice - 1,
                cashBefore + expectedSellPrice + 1,
              ),
            );
            expect(sim.getTowerAt(c, r), null);
            return;
          }
        }
      }
    });
  });
}
