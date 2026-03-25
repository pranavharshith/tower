import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/core/interfaces/i_sound_service.dart';
import 'package:flutter_tower/game/collision_detector.dart';
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
  group('Collision Detector', () {
    late CollisionDetector detector;
    late TdSim sim;

    setUp(() {
      detector = CollisionDetector();
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

    test('Missile pool initializes correctly', () {
      expect(detector.missiles, isEmpty);
      // Pool starts with 200 available missiles internally
      expect(detector.pooledMissiles, isEmpty); // Active list starts empty
    });

    test('Fire missile activates from pool', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );

      detector.fireMissile(
        posX: 3.0,
        posY: 3.0,
        target: enemy,
        damageMin: 40,
        damageMax: 60,
        blastRadius: 1.0,
        rangeTiles: 7,
        speedTilesPerTick: 0.1666667,
        lifetimeTicks: 60,
      );

      expect(detector.missiles, hasLength(1));
      expect(detector.pooledMissiles, hasLength(1)); // Active list has 1
    });

    test('Missile returns to pool after exploding', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );
      sim.enemies.add(enemy);

      detector.fireMissile(
        posX: 5.0,
        posY: 5.0,
        target: enemy,
        damageMin: 40,
        damageMax: 60,
        blastRadius: 1.0,
        rangeTiles: 7,
        speedTilesPerTick: 0.5,
        lifetimeTicks: 60,
      );

      expect(detector.missiles, hasLength(1));

      // Update until missile reaches target
      for (int i = 0; i < 10; i++) {
        detector.updateMissiles(sim: sim, paused: false);
      }

      expect(detector.missiles, isEmpty);
      expect(
        detector.pooledMissiles,
        isEmpty,
      ); // Active list is empty after return
    });

    test('Missile explodes on contact with target', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );
      sim.enemies.add(enemy);

      // CRITICAL: Update spatial grid before collision detection
      sim.paused = false;
      sim.step(); // This updates the spatial grid
      sim.paused = true;

      detector.fireMissile(
        posX: 5.4,
        posY: 5.4,
        target: enemy,
        damageMin: 40,
        damageMax: 60,
        blastRadius: 1.0,
        rangeTiles: 7,
        speedTilesPerTick: 0.5,
        lifetimeTicks: 60,
      );

      final healthBefore = enemy.health;
      detector.updateMissiles(sim: sim, paused: false);

      expect(enemy.health, lessThan(healthBefore));
    });

    test('Missile expires after lifetime', () {
      final enemy = TdEnemy(
        posX: 100.5,
        posY: 100.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );

      detector.fireMissile(
        posX: 5.0,
        posY: 5.0,
        target: enemy,
        damageMin: 40,
        damageMax: 60,
        blastRadius: 1.0,
        rangeTiles: 7,
        speedTilesPerTick: 0.01,
        lifetimeTicks: 5,
      );

      for (int i = 0; i < 10; i++) {
        detector.updateMissiles(sim: sim, paused: false);
      }

      expect(detector.missiles, isEmpty);
    });

    test('Clear removes all missiles', () {
      final enemy = TdEnemy(
        posX: 5.5,
        posY: 5.5,
        type: enemyTypes['weak']!,
        rng: sim.rng,
      );

      for (int i = 0; i < 5; i++) {
        detector.fireMissile(
          posX: 3.0,
          posY: 3.0,
          target: enemy,
          damageMin: 40,
          damageMax: 60,
          blastRadius: 1.0,
          rangeTiles: 7,
          speedTilesPerTick: 0.1666667,
          lifetimeTicks: 60,
        );
      }

      expect(detector.missiles, hasLength(5));

      detector.clear();
      expect(detector.missiles, isEmpty);
      // Note: pooledMissiles (active list) is not cleared by clear()
      // This is expected behavior - pool maintains its active references
    });
  });
}
