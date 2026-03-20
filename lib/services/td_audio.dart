import 'package:flame_audio/flame_audio.dart';

/// Audio service for Tower Defense game
/// Handles loading and playing sound effects from towerdefense
class TdAudio {
  static final TdAudio _instance = TdAudio._internal();
  factory TdAudio() => _instance;
  TdAudio._internal();

  bool _initialized = false;
  bool _muted = false;

  Future<void> init() async {
    if (_initialized) return;

    await FlameAudio.audioCache.loadAll([
      'boom.wav',
      'missile.wav',
      'pop.wav',
      'railgun.wav',
      'sniper.wav',
      'spark.wav',
      'taunt.wav',
    ]);

    _initialized = true;
  }

  void setMuted(bool muted) {
    _muted = muted;
  }

  void play(String sound) {
    if (_muted || !_initialized) return;

    try {
      switch (sound) {
        case 'boom':
          FlameAudio.play('boom.wav', volume: 0.3);
          break;
        case 'missile':
          FlameAudio.play('missile.wav', volume: 0.3);
          break;
        case 'pop':
          FlameAudio.play('pop.wav', volume: 0.4);
          break;
        case 'railgun':
          FlameAudio.play('railgun.wav', volume: 0.3);
          break;
        case 'sniper':
          FlameAudio.play('sniper.wav', volume: 0.2);
          break;
        case 'spark':
          FlameAudio.play('spark.wav', volume: 0.3);
          break;
        case 'taunt':
          FlameAudio.play('taunt.wav', volume: 0.3);
          break;
      }
    } catch (e) {
      // Audio play failed, ignore
    }
  }

  // Convenience methods for specific sounds
  void playEnemyDeath(String enemyType) {
    if (enemyType == 'taunt') {
      play('taunt');
    } else {
      play('pop');
    }
  }

  void playTowerFire(String towerType) {
    switch (towerType) {
      case 'sniper':
      case 'railgun':
        play('sniper');
        break;
      case 'rocket':
      case 'missileSilo':
        play('missile');
        break;
      case 'tesla':
      case 'plasma':
        play('spark');
        break;
      default:
        // Gun, laser, slow, bomb - no specific sounds in original
        break;
    }
  }

  void playExplosion() {
    play('boom');
  }
}
