import 'package:audioplayers/audioplayers.dart';
import '../core/interfaces/i_sound_service.dart';
import 'logger.dart';

/// Manages sound effects for the tower defense game.
/// Handles loading, playing, and volume control of game sounds.
class SoundService implements ISoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final List<AudioPlayer> _audioPlayers = [];
  static const int _maxPlayers =
      8; // Pool of audio players for simultaneous sounds
  int _currentPlayerIndex = 0;
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isDisposed = false; // Track disposal state

  /// Map of sound effect names to their file paths
  static const Map<String, String> _soundEffects = {
    'shoot': 'sounds/pop.wav',
    'explosion': 'sounds/boom.wav',
    'missile': 'sounds/missile.wav',
    'railgun': 'sounds/railgun.wav',
    'sniper': 'sounds/sniper.wav',
    'spark': 'sounds/spark.wav',
    'taunt': 'sounds/taunt.wav',
  };

  /// Cache of loaded sounds
  final Map<String, Source> _loadedSounds = {};

  /// Initialize the sound service by loading all sound effects
  @override
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) {
      return; // Prevent re-initialization after disposal
    }

    try {
      // Create a pool of audio players for simultaneous sounds
      for (int i = 0; i < _maxPlayers; i++) {
        _audioPlayers.add(AudioPlayer());
      }

      // Load all sound effects
      int loadedCount = 0;
      for (final entry in _soundEffects.entries) {
        try {
          final source = AssetSource(entry.value);
          _loadedSounds[entry.key] = source;
          loadedCount++;
        } catch (e) {
          AppLogger.e('Failed to load sound ${entry.key}', e);
        }
      }
      _isInitialized = true;
      AppLogger.i(
        'Sound service initialized: $loadedCount/${_soundEffects.length} sounds loaded',
      );
    } catch (e) {
      AppLogger.e('Critical error initializing sound service', e);
      _isInitialized = false;
    }
  }

  /// Enable or disable sound effects
  @override
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if sounds are enabled
  @override
  bool get isEnabled => _isEnabled;

  /// Play a sound effect by name
  ///
  /// [soundName] - The name of the sound effect to play
  /// [volume] - Volume level (0.0 to 1.0), defaults to 1.0
  /// [rate] - Playback rate, defaults to 1.0
  @override
  Future<void> play(
    String soundName, {
    double volume = 1.0,
    double rate = 1.0,
  }) async {
    if (!_isEnabled || !_isInitialized || _isDisposed) return;

    try {
      final source = _loadedSounds[soundName];
      if (source == null) {
        AppLogger.w(
          'Sound not found: $soundName (available: ${_loadedSounds.keys.join(", ")})',
        );
        return;
      }

      // Get the next available player from the pool (round-robin)
      final player = _audioPlayers[_currentPlayerIndex];
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _maxPlayers;

      // Optimized: Set volume and rate before playing to reduce audio thread blocking
      // Only set if different from default to avoid unnecessary operations
      if (volume != 1.0) {
        await player.setVolume(volume);
      }
      if (rate != 1.0) {
        await player.setPlaybackRate(rate);
      }
      await player.play(source);
    } catch (e) {
      // Only log errors in debug mode to avoid performance impact
      AppLogger.e('Error playing sound $soundName', e);
    }
  }

  /// Play a sound effect with reduced volume
  @override
  Future<void> playQuiet(String soundName, {double volume = 0.3}) async {
    await play(soundName, volume: volume);
  }

  /// Stop all currently playing sounds
  @override
  Future<void> stopAll() async {
    try {
      for (final player in _audioPlayers) {
        await player.stop();
      }
    } catch (e) {
      AppLogger.e('Error stopping sounds', e);
    }
  }

  /// Dispose of resources
  @override
  void dispose() {
    if (_isDisposed) return; // Prevent double disposal
    _isDisposed = true;
    for (final player in _audioPlayers) {
      player.dispose();
    }
    _audioPlayers.clear();
    _loadedSounds.clear();
    _isInitialized = false;
  }
}
