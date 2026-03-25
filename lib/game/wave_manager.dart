import 'dart:math';

import '../config/td_game_config.dart';

/// Represents a single enemy spawn group within a wave
/// Example: ['weak', 'strong', 25] means spawn 25 waves of weak + strong enemies
typedef EnemyGroup = List<dynamic>;

/// Represents a complete wave pattern with spawn cooldown and enemy groups
/// Example: [60, ['weak', 25], ['strong', 25]] means 60 tick cooldown, then spawn groups
typedef WavePattern = List<dynamic>;

/// Wave configuration for a specific wave number range
/// Contains min/max wave bounds and the patterns to choose from
class WaveConfig {
  final int minWave;
  final int? maxWave; // null means "and beyond"
  final List<WavePattern> patterns;

  const WaveConfig({
    required this.minWave,
    this.maxWave,
    required this.patterns,
  });

  /// Check if current wave is within this config's range
  bool matches(int currentWave) {
    if (maxWave == null) return currentWave >= minWave;
    return currentWave >= minWave && currentWave < maxWave!;
  }
}

/// Manages wave progression, enemy spawning patterns, and boss waves
/// Extracted from TdSim for better separation of concerns
class WaveManager {
  final Random rng;
  final String mapKey;

  // Wave state
  int wave = 0;
  int spawnCool = 0; // ticks between spawn cycles
  int scd = 0; // current spawn cooldown
  int wcd = 0; // wave cooldown remaining
  bool toWait = false;

  // Enemy spawn queue
  final List<String> newEnemies = [];

  // Boss mechanics
  int bossesDefeated = 0;
  bool isBossWave = false;
  bool bossSpawned = false;
  int lastTeleportWave = 0;

  WaveManager({required this.rng, required this.mapKey});

  /// Reset wave state for new game
  void reset() {
    wave = 0;
    spawnCool = 0;
    scd = 0;
    wcd = 0;
    toWait = false;
    newEnemies.clear();
    bossesDefeated = 0;
    isBossWave = false;
    bossSpawned = false;
    lastTeleportWave = 0;
  }

  /// Check if all enemies have been spawned and queue is empty
  bool get noMoreEnemies => newEnemies.isEmpty;

  /// Check if ready to spawn next enemy
  bool canSpawn() => newEnemies.isNotEmpty && scd == 0;

  /// Advance to next wave
  void nextWave() {
    wave++;

    // Check if this is a boss wave (every 5 waves)
    if (wave % 5 == 0) {
      isBossWave = true;
      bossSpawned = false;
      // No regular enemies during boss wave
      newEnemies.clear();
      spawnCool = 0;
    } else {
      isBossWave = false;
      bossSpawned = false;

      final pattern = randomWave();
      addWave(pattern);
    }
  }

  /// Mark boss as spawned
  void markBossSpawned() {
    bossSpawned = true;
  }

  /// Handle boss defeat
  void onBossDefeated() {
    bossesDefeated++;
    bossSpawned = false;
    isBossWave = false;
  }

  /// Check if should teleport spawn towers this wave
  bool shouldTeleportSpawners() {
    if (isBossWave) return false;
    if (wave % 2 != 0) return false;
    if (wave == lastTeleportWave) return false;
    return true;
  }

  /// Mark that spawners were teleported this wave
  void markSpawnersTeleported() {
    lastTeleportWave = wave;
  }

  /// Add wave pattern to spawn queue
  void addWave(List<dynamic> pattern) {
    if (pattern.isEmpty) {
      spawnCool = 0;
      return;
    }
    spawnCool = pattern[0] as int;
    newEnemies.clear();

    for (int i = 1; i < pattern.length; i++) {
      final group = (pattern[i] as List).cast<dynamic>();
      addGroup(group);
    }
  }

  /// Add enemy group to spawn queue
  void addGroup(List<dynamic> group) {
    if (group.isEmpty) return;
    final count = (group.last as num).toInt();
    final names = group.sublist(0, group.length - 1).cast<String>();

    // For waves 1-3: Reduce enemy count to 60%
    final adjustedCount = (wave <= 3) ? (count * 0.6).round() : count;

    for (int i = 0; i < adjustedCount; i++) {
      for (final name in names) {
        newEnemies.add(name);
      }
    }
  }

  /// Check if current wave is within range
  bool isWave(int min, [int? max]) {
    if (max == null) return wave >= min;
    return wave >= min && wave < max;
  }

  /// Generate random wave pattern based on current wave number
  /// Uses data-driven WaveConfig definitions instead of hardcoded if-chains
  List<dynamic> randomWave() {
    // Data-driven wave configurations - each config defines patterns for a wave range
    final waveConfigs = <WaveConfig>[
      // Waves 0-2: Early game - reduced spawn rate by 50%
      WaveConfig(
        minWave: 0,
        maxWave: 3,
        patterns: [
          [
            80,
            ['weak', 50],
          ],
        ],
      ),
      // Waves 2-3: Introduction of weak enemies
      WaveConfig(
        minWave: 2,
        maxWave: 4,
        patterns: [
          [
            40,
            ['weak', 25],
          ],
        ],
      ),
      // Waves 2-6: Mix of weak and strong enemies
      WaveConfig(
        minWave: 2,
        maxWave: 7,
        patterns: [
          [
            60,
            ['weak', 25],
            ['strong', 25],
          ],
          [
            40,
            ['strong', 25],
          ],
        ],
      ),
      // Waves 3-6: Fast enemies introduced
      WaveConfig(
        minWave: 3,
        maxWave: 7,
        patterns: [
          [
            80,
            ['fast', 25],
          ],
        ],
      ),
      // Waves 4-13: More fast enemies
      WaveConfig(
        minWave: 4,
        maxWave: 14,
        patterns: [
          [
            40,
            ['fast', 50],
          ],
        ],
      ),
      // Waves 5: Strong + fast mix
      WaveConfig(
        minWave: 5,
        maxWave: 6,
        patterns: [
          [
            40,
            ['strong', 50],
            ['fast', 25],
          ],
        ],
      ),
      // Waves 8-11: Medic enemies introduced
      WaveConfig(
        minWave: 8,
        maxWave: 12,
        patterns: [
          [
            20,
            ['medic', 'strong', 'strong', 25],
          ],
        ],
      ),
      // Waves 10-12: Advanced medic combinations
      WaveConfig(
        minWave: 10,
        maxWave: 13,
        patterns: [
          [
            20,
            ['medic', 'strong', 'strong', 50],
          ],
          [
            30,
            ['medic', 'strong', 'strong', 50],
            ['fast', 50],
          ],
          [
            5,
            ['fast', 50],
          ],
        ],
      ),
      // Waves 12-15: Complex enemy compositions
      WaveConfig(
        minWave: 12,
        maxWave: 16,
        patterns: [
          [
            20,
            ['medic', 'strong', 'strong', 50],
            ['strongFast', 50],
          ],
          [
            10,
            ['strong', 50],
            ['strongFast', 50],
          ],
          [
            10,
            ['medic', 'strongFast', 50],
          ],
          [
            10,
            ['strong', 25],
            ['stronger', 25],
            ['strongFast', 50],
          ],
          [
            10,
            ['strong', 25],
            ['medic', 25],
            ['strongFast', 50],
          ],
          [
            20,
            ['medic', 'stronger', 'stronger', 50],
          ],
          [
            10,
            ['medic', 'stronger', 'strong', 50],
          ],
          [
            10,
            ['medic', 'strong', 50],
            ['medic', 'strongFast', 50],
          ],
          [
            5,
            ['strongFast', 100],
          ],
          [
            20,
            ['stronger', 50],
          ],
        ],
      ),
      // Waves 13-19: Tank enemies introduced
      WaveConfig(
        minWave: 13,
        maxWave: 20,
        patterns: [
          [
            40,
            ['tank', 'stronger', 'stronger', 'stronger', 10],
          ],
          [
            10,
            ['medic', 'stronger', 'stronger', 50],
          ],
          [
            40,
            ['tank', 25],
          ],
          [
            20,
            ['tank', 'stronger', 'stronger', 50],
          ],
          [
            20,
            ['tank', 'medic', 50],
            ['strongFast', 25],
          ],
        ],
      ),
      // Waves 14-19: Tank variations
      WaveConfig(
        minWave: 14,
        maxWave: 20,
        patterns: [
          [
            20,
            ['tank', 'stronger', 'stronger', 50],
          ],
          [
            20,
            ['tank', 'medic', 'medic', 50],
          ],
          [
            20,
            ['tank', 'medic', 50],
            ['strongFast', 25],
          ],
          [
            10,
            ['tank', 50],
            ['strongFast', 25],
          ],
          [
            10,
            ['faster', 50],
          ],
          [
            20,
            ['tank', 50],
            ['faster', 25],
          ],
        ],
      ),
      // Waves 17-24: Taunt and spawner enemies
      WaveConfig(
        minWave: 17,
        maxWave: 25,
        patterns: [
          [
            20,
            ['taunt', 'stronger', 'stronger', 'stronger', 25],
          ],
          [
            20,
            ['spawner', 'stronger', 'stronger', 'stronger', 25],
          ],
          [
            20,
            ['taunt', 'tank', 'tank', 'tank', 25],
          ],
          [
            40,
            ['taunt', 'tank', 'tank', 'tank', 25],
          ],
        ],
      ),
      // Wave 19: Special spawner composition
      WaveConfig(
        minWave: 19,
        maxWave: 20,
        patterns: [
          [
            20,
            ['spawner', 1],
            ['tank', 20],
            ['stronger', 25],
          ],
          [
            20,
            ['spawner', 1],
            ['faster', 25],
          ],
        ],
      ),
      // Wave 23: Complex taunt/spawner mix
      WaveConfig(
        minWave: 23,
        maxWave: 24,
        patterns: [
          [
            20,
            ['taunt', 'medic', 'tank', 25],
          ],
          [
            20,
            ['spawner', 2],
            ['taunt', 'medic', 'tank', 25],
          ],
          [
            10,
            ['spawner', 1],
            ['faster', 100],
          ],
          [
            5,
            ['faster', 100],
          ],
          [
            20,
            ['tank', 100],
            ['faster', 50],
            ['taunt', 'tank', 'tank', 'tank', 50],
          ],
          [
            10,
            ['taunt', 'stronger', 'tank', 'stronger', 50],
            ['faster', 50],
          ],
        ],
      ),
      // Wave 25: Advanced taunt compositions
      WaveConfig(
        minWave: 25,
        maxWave: 26,
        patterns: [
          [
            5,
            ['taunt', 'medic', 'tank', 50],
            ['faster', 50],
          ],
          [
            5,
            ['taunt', 'faster', 'faster', 'faster', 50],
          ],
          [
            10,
            ['taunt', 'tank', 'tank', 'tank', 50],
            ['faster', 50],
          ],
        ],
      ),
      // Wave 30: Endgame taunt/faster mix
      WaveConfig(
        minWave: 30,
        maxWave: 31,
        patterns: [
          [
            5,
            ['taunt', 'faster', 'faster', 'faster', 50],
          ],
          [
            5,
            ['taunt', 'tank', 'tank', 'tank', 50],
          ],
          [
            5,
            ['taunt', 'medic', 'tank', 'tank', 50],
          ],
          [
            1,
            ['faster', 200],
          ],
        ],
      ),
      // Wave 35+: Ultimate challenge
      WaveConfig(
        minWave: 35,
        patterns: [
          [
            0,
            ['taunt', 'faster', 200],
          ],
        ],
      ),
    ];

    // Collect all patterns from matching configs
    final waves = <WavePattern>[];
    for (final config in waveConfigs) {
      if (config.matches(wave)) {
        waves.addAll(config.patterns);
      }
    }

    if (waves.isEmpty) {
      // Fallback in case we missed a wave window
      return [
        40,
        ['weak', 50],
      ];
    }

    return waves[rng.nextInt(waves.length)];
  }

  /// Update wave cooldowns (called each tick when not paused)
  void updateCooldowns() {
    if (scd > 0) scd--;
    if (toWait && wcd > 0) wcd--;
  }

  /// Check if wave should progress
  bool shouldProgressWave(bool enemiesEmpty) {
    if (enemiesEmpty && !toWait) {
      wcd = TdGameConfig.defaultTicksBetweenWaves;
      toWait = true;
      return false;
    }
    if (toWait && wcd == 0) {
      toWait = false;
      wcd = 0;
      return true;
    }
    return false;
  }

  /// Reset spawn cooldown after spawning
  void resetSpawnCooldown() {
    scd = spawnCool;
  }
}
