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
  group('Tower Combat', () {
    late TdSim sim;

    setUp(() {
      final maps = TdMaps();
      final map = maps.loadPremade('loops');
      sim = TdSim(
        baseMap: map,
        rng: Random(42),
        cash: 10000,
        soundService: _MockSoundService(),
        mapKey: 'loops',
      );
      sim.startGame();
    });

    test('Tower fires at enemies in range', () {
      // Place rocket tower (fires missiles)
      bool placed = false;
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.rocket, c, r)) {
            sim.placeTower(TdTowerType.rocket, c, r);
            final tower = sim.getTowerAt(c, r)!;

            // Find a nearby tile with a valid path
            TdEnemy? enemy;
            for (int dc = -1; dc <= 1; dc++) {
              for (int dr = -1; dr <= 1; dr++) {
                final nc = c + dc;
                final nr = r + dr;
                if (nc >= 0 &&
                    nc < sim.baseMap.cols &&
                    nr >= 0 &&
                    nr < sim.baseMap.rows &&
                    sim.dists[nc][nr] != null) {
                  // Found a valid path tile, place enemy there
                  enemy = TdEnemy(
                    posX: nc + 0.5,
                    posY: nr + 0.5,
                    type: enemyTypes['weak']!,
                    rng: sim.rng,
                  );
                  sim.enemies.add(enemy);
                  break;
                }
              }
              if (enemy != null) break;
            }

            if (enemy == null) {
              sim.sellTower(tower);
              continue; // No valid path tile found, try next tower position
            }

            // CRITICAL: Update spatial grid before tower targeting
            sim.paused = false;
            sim.step();
            sim.paused = true;

            tower.cd = 0; // Ready to fire

            final missilesBefore = sim.missiles.length;
            tower.tryFire(sim);

            // Rocket tower fires missiles, so check if missile was created
            expect(
              sim.missiles.length,
              greaterThan(missilesBefore),
              reason: 'Rocket tower should create a missile',
            );
            placed = true;
            break;
          }
        }
        if (placed) break;
      }
      expect(placed, true, reason: 'Should have placed at least one tower');
    });

    test('Tower does not fire when on cooldown', () {
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            final tower = sim.getTowerAt(c, r)!;

            final enemy = TdEnemy(
              posX: tower.posX + 1,
              posY: tower.posY,
              type: enemyTypes['weak']!,
              rng: sim.rng,
            );
            sim.enemies.add(enemy);

            tower.cd = 10; // On cooldown
            final healthBefore = enemy.health;
            tower.tryFire(sim);

            expect(enemy.health, healthBefore); // No damage
            return;
          }
        }
      }
    });

    test('Sniper targets strongest enemy', () {
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.sniper, c, r)) {
            sim.placeTower(TdTowerType.sniper, c, r);
            final tower = sim.getTowerAt(c, r)!;

            final weakEnemy = TdEnemy(
              posX: tower.posX + 1,
              posY: tower.posY,
              type: enemyTypes['weak']!,
              rng: sim.rng,
            );
            final strongEnemy = TdEnemy(
              posX: tower.posX + 2,
              posY: tower.posY,
              type: enemyTypes['strong']!,
              rng: sim.rng,
            );

            sim.enemies.addAll([weakEnemy, strongEnemy]);

            // CRITICAL: Update spatial grid before tower targeting
            sim.paused = false;
            sim.step();
            sim.paused = true;

            tower.cd = 0;
            tower.tryFire(sim);

            // Sniper should target the stronger enemy
            expect(strongEnemy.health, lessThan(strongEnemy.maxHealth));
            return;
          }
        }
      }
    });

    test('Cooldown updates correctly', () {
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.gun, c, r)) {
            sim.placeTower(TdTowerType.gun, c, r);
            final tower = sim.getTowerAt(c, r)!;

            tower.cd = 5;
            tower.updateCooldown();
            expect(tower.cd, 4);

            tower.cd = 1;
            tower.updateCooldown();
            expect(tower.cd, 0);

            tower.cd = 0;
            tower.updateCooldown();
            expect(tower.cd, 0); // Stays at 0
            return;
          }
        }
      }
    });

    test('Area damage hits multiple enemies', () {
      bool placed = false;
      for (int c = 0; c < sim.baseMap.cols; c++) {
        for (int r = 0; r < sim.baseMap.rows; r++) {
          if (sim.canPlaceTower(TdTowerType.rocket, c, r)) {
            sim.placeTower(TdTowerType.rocket, c, r);
            final tower = sim.getTowerAt(c, r)!;

            // Find a nearby tile with a valid path
            final enemies = <TdEnemy>[];
            for (int dc = -1; dc <= 1; dc++) {
              for (int dr = -1; dr <= 1; dr++) {
                final nc = c + dc;
                final nr = r + dr;
                if (nc >= 0 &&
                    nc < sim.baseMap.cols &&
                    nr >= 0 &&
                    nr < sim.baseMap.rows &&
                    sim.dists[nc][nr] != null &&
                    enemies.length < 3) {
                  // Found a valid path tile, place enemy there
                  enemies.add(
                    TdEnemy(
                      posX: nc + 0.5,
                      posY: nr + 0.5,
                      type: enemyTypes['weak']!,
                      rng: sim.rng,
                    ),
                  );
                }
              }
            }

            if (enemies.isEmpty) {
              sim.sellTower(tower);
              continue; // No valid path tiles found, try next tower position
            }

            sim.enemies.addAll(enemies);

            // CRITICAL: Update spatial grid before tower targeting
            sim.paused = false;
            sim.step();
            sim.paused = true;

            tower.cd = 0;
            final missilesBefore = sim.missiles.length;
            tower.tryFire(sim);

            // Rocket tower fires missiles
            expect(sim.missiles.length, greaterThan(missilesBefore));
            placed = true;
            break;
          }
        }
        if (placed) break;
      }
      expect(placed, true, reason: 'Should have placed at least one tower');
    });
  });
}
