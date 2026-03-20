import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_tower/data/td_maps.dart';
import 'package:flutter_tower/data/td_random_maps.dart';
import 'package:flutter_tower/game/td_simulation.dart';

void main() {
  test('Premade maps load and spawn first enemy batch', () {
    final tdMaps = TdMaps();

    final premadeKeys = TdMaps.options.where((o) => tdMaps.isPremadeKey(o.key)).map((o) => o.key).toList();
    expect(premadeKeys, isNotEmpty);

    for (final key in premadeKeys) {
      final map = tdMaps.loadPremade(key);
      final sim = TdSim(baseMap: map, rng: Random(1), cash: 55);
      sim.startGame();
      expect(sim.enemies, isEmpty);

      sim.paused = false;
      sim.step();

      // On the first step with scd==0, we spawn exactly one enemy type
      // at each spawnpoint.
      expect(sim.enemies.length, map.spawnpoints.length, reason: 'key=$key');
    }
  });

  test('Placing a tower near spawn causes auto-attack damage', () {
    final tdMaps = TdMaps();
    final map = tdMaps.loadPremade('loops');
    final sim = TdSim(baseMap: map, rng: Random(2), cash: 55);
    sim.startGame();

    final gun = towerTypes['gun']!;

    final sp = sim.spawnpoints.first;
    final spawnCenterX = sp.x + 0.5;
    final spawnCenterY = sp.y + 0.5;
    final maxDist = gun.range + 1.0 + 0.001; // matches sim.enemiesInRange radius tiles.
    final maxDist2 = maxDist * maxDist;

    bool placed = false;
    for (int c = 0; c < sim.baseMap.cols; c++) {
      for (int r = 0; r < sim.baseMap.rows; r++) {
        if (!sim.canPlaceTower(gun, c, r)) continue;
        final cx = c + 0.5;
        final cy = r + 0.5;
        final dx = cx - spawnCenterX;
        final dy = cy - spawnCenterY;
        if (dx * dx + dy * dy <= maxDist2) {
          sim.placeTower(gun, c, r);
          placed = true;
          break;
        }
      }
      if (placed) break;
    }

    expect(placed, isTrue, reason: 'Could not find a valid placement near spawn');

    // Spawn and let the tower fire in the same first tick.
    sim.paused = false;
    final enemyHealthBefore = sim.enemies.map((e) => e.health).toList();
    sim.step();

    expect(sim.enemies, isNotEmpty);
    final anyDamaged = sim.enemies.any((e) => e.health < e.type.health);
    expect(anyDamaged, isTrue);
    // Sanity: pathfinding should still reach spawnpoints after placement.
    for (final s in sim.spawnpoints) {
      expect(sim.dists[s.x][s.y], isNotNull);
    }

    // Silence analyzer about the before variable being unused.
    expect(enemyHealthBefore.length, 0);
  });
}

