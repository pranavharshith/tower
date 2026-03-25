import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/core/interfaces/i_sound_service.dart';
import 'package:flutter_tower/game/td_simulation.dart';
import 'package:flutter_tower/data/td_maps.dart';

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
  group('Boss Mechanics', () {
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

    test('Boss wave occurs every 5 waves', () {
      expect(sim.isBossWave, false);

      // startGame() already advanced to wave 1, so advance 4 more times
      for (int i = 2; i <= 5; i++) {
        sim.nextWave();
      }
      expect(sim.isBossWave, true);

      sim.nextWave();
      expect(sim.isBossWave, false);

      for (int i = 7; i <= 10; i++) {
        sim.nextWave();
      }
      expect(sim.isBossWave, true);
    });

    test('Boss tower is created on boss wave', () {
      // startGame() already advanced to wave 1, so advance 4 more times
      for (int i = 2; i <= 5; i++) {
        sim.nextWave();
      }

      expect(sim.bossTower, isNotNull);
      expect(sim.bossTower!.isBossTower, true);
    });

    test('Boss spawns with scaled health', () {
      // startGame() already advanced to wave 1, so advance 4 more times
      for (int i = 2; i <= 5; i++) {
        sim.nextWave();
      }

      sim.spawnBoss();
      expect(sim.currentBoss, isNotNull);
      expect(sim.currentBoss!.type.key, 'boss');
      // First boss (bossesDefeated = 0) has 0.16x multiplier = 800 HP
      expect(sim.currentBoss!.health, 800);
    });

    test('Boss defeat triggers heal and counter increment', () {
      // startGame() already advanced to wave 1, so advance 4 more times
      for (int i = 2; i <= 5; i++) {
        sim.nextWave();
      }

      sim.spawnBoss();
      final bossesDefeatedBefore = sim.bossesDefeated;

      sim.onBossDefeated();

      expect(sim.health, 40); // Max HP is 40, so stays at 40 even with +10 heal
      expect(sim.bossesDefeated, bossesDefeatedBefore + 1);
      expect(sim.healEffectTicks, 60);
      expect(sim.bossTower, isNull); // Boss tower is cleared after defeat
    });

    test('Boss health scales exponentially with defeats', () {
      // startGame() already advanced to wave 1, so advance 4 more times
      for (int w = 2; w <= 5; w++) {
        sim.nextWave();
      }

      sim.spawnBoss();
      final firstBossHealth = sim.currentBoss!.health;

      // Defeat first boss
      sim.currentBoss!.health = 0;
      sim.onBossDefeated();

      // Advance to next boss wave (waves 6-10)
      for (int w = 6; w <= 10; w++) {
        sim.nextWave();
      }

      sim.spawnBoss();
      final secondBossHealth = sim.currentBoss!.health;

      // Second boss (bossesDefeated=1) has 0.24x vs first boss 0.16x = 1.5 ratio
      expect(secondBossHealth, greaterThan(firstBossHealth));
      expect(secondBossHealth / firstBossHealth, closeTo(1.5, 0.01));
    });
  });
}
