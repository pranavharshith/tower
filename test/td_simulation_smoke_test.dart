import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/core/interfaces/i_sound_service.dart';
import 'package:flutter_tower/data/td_maps.dart';
import 'package:flutter_tower/game/td_simulation.dart';
import 'package:flutter_tower/game/entities/entities.dart';

class MockSoundService implements ISoundService {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Premade maps load and spawn first enemy batch', () {
    final tdMaps = TdMaps();

    final premadeKeys = TdMaps.options
        .where((o) => tdMaps.isPremadeKey(o.key))
        .map((o) => o.key)
        .toList();
    expect(premadeKeys, isNotEmpty);

    for (final key in premadeKeys) {
      final map = tdMaps.loadPremade(key);
      final sim = TdSim(
        baseMap: map,
        rng: Random(1),
        cash: 55,
        soundService: MockSoundService(),
        mapKey: key,
      );
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
    final sim = TdSim(
      baseMap: map,
      rng: Random(2),
      cash: 55,
      soundService: MockSoundService(),
      mapKey: 'loops',
    );
    sim.startGame();

    final gun = towerTypes['gun']!;

    final sp = sim.spawnpoints.first;
    final spawnCenterX = sp.x + 0.5;
    final spawnCenterY = sp.y + 0.5;
    final maxDist =
        gun.range + 1.0 + 0.001; // matches sim.enemiesInRange radius tiles.
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

    expect(
      placed,
      isTrue,
      reason: 'Could not find a valid placement near spawn',
    );

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
  test('stepWithDelta advances enemy positions based on velocity', () {
    final tdMaps = TdMaps();
    final map = tdMaps.loadPremade('loops');
    final sim = TdSim(
      baseMap: map,
      rng: Random(3),
      cash: 50,
      soundService: MockSoundService(),
      mapKey: 'loops',
    );
    sim.startGame();
    sim.paused = false;

    // Spawn an enemy directly
    sim.step(); // Trigger spawn
    expect(sim.enemies, isNotEmpty);

    final enemy = sim.enemies.first;
    final initialX = enemy.posX;
    final initialY = enemy.posY;

    // Enemy should have some velocity assigned
    expect(enemy.velX != 0 || enemy.velY != 0, isTrue);

    // Step forward 0.1 seconds
    final dt = 0.1;
    sim.stepWithDelta(dt);

    // Position should update based on the velocity (which is already dt-adjusted in stepWithDelta)
    expect(enemy.posX, closeTo(initialX + enemy.velX, 0.001));
    expect(enemy.posY, closeTo(initialY + enemy.velY, 0.001));
  });
}
