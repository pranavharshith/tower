import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/game/wave_manager.dart';

void main() {
  group('Wave Manager', () {
    late WaveManager waveManager;

    setUp(() {
      waveManager = WaveManager(rng: Random(42), mapKey: 'loops');
    });

    test('Initializes with wave 0', () {
      expect(waveManager.wave, 0);
      expect(waveManager.bossesDefeated, 0);
      expect(waveManager.bossSpawned, false);
    });

    test('Next wave increments wave counter', () {
      waveManager.nextWave();
      expect(waveManager.wave, 1);

      waveManager.nextWave();
      expect(waveManager.wave, 2);
    });

    test('Boss wave detection works correctly', () {
      expect(waveManager.isBossWave, false);

      for (int i = 1; i <= 5; i++) {
        waveManager.nextWave();
      }
      expect(waveManager.isBossWave, true);

      waveManager.nextWave();
      expect(waveManager.isBossWave, false);
    });

    test('Spawn cooldown resets correctly', () {
      waveManager.nextWave(); // Need to advance wave first to set spawnCool
      waveManager.resetSpawnCooldown();
      expect(waveManager.scd, greaterThan(0));
    });

    test('Can spawn when cooldown is zero and enemies remain', () {
      waveManager.nextWave();
      waveManager.scd = 0;

      expect(waveManager.canSpawn(), true);
    });

    test('Cannot spawn when no enemies remain', () {
      waveManager.nextWave();
      waveManager.newEnemies.clear();

      expect(waveManager.canSpawn(), false);
    });

    test('Teleport occurs every 2 waves', () {
      waveManager.nextWave(); // Wave 1
      expect(waveManager.shouldTeleportSpawners(), false);

      waveManager.nextWave(); // Wave 2
      expect(waveManager.shouldTeleportSpawners(), true);
      waveManager.markSpawnersTeleported();

      waveManager.nextWave(); // Wave 3
      expect(waveManager.shouldTeleportSpawners(), false);

      waveManager.nextWave(); // Wave 4
      expect(waveManager.shouldTeleportSpawners(), true);
    });

    test('Boss defeated increments counter', () {
      for (int i = 1; i <= 5; i++) {
        waveManager.nextWave();
      }

      waveManager.markBossSpawned();
      expect(waveManager.bossesDefeated, 0);

      waveManager.onBossDefeated();
      expect(waveManager.bossesDefeated, 1);
      expect(waveManager.bossSpawned, false);
    });

    test('Wave progression requires cooldown and no enemies', () {
      waveManager.nextWave();
      waveManager.newEnemies.clear();

      expect(waveManager.shouldProgressWave(true), false); // wcd not zero

      waveManager.wcd = 0;
      expect(waveManager.shouldProgressWave(true), true);
      expect(waveManager.shouldProgressWave(false), false); // enemies remain
    });
  });
}
