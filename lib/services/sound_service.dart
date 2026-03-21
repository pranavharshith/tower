import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Manages sound effects for the tower defense game.
/// Handles loading, playing, and volume control of game sounds.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isEnabled = true;

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
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load all sound effects
      for (final entry in _soundEffects.entries) {
        try {
          final source = AssetSource(entry.value);
          _loadedSounds[entry.key] = source;
        } catch (e) {
          debugPrint('Failed to load sound ${entry.key}: $e');
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing sound service: $e');
    }
  }

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if sounds are enabled
  bool get isEnabled => _isEnabled;

  /// Play a sound effect by name
  ///
  /// [soundName] - The name of the sound effect to play
  /// [volume] - Volume level (0.0 to 1.0), defaults to 1.0
  /// [rate] - Playback rate, defaults to 1.0
  Future<void> play(
    String soundName, {
    double volume = 1.0,
    double rate = 1.0,
  }) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      final source = _loadedSounds[soundName];
      if (source == null) {
        debugPrint('Sound not found: $soundName');
        return;
      }

      // Stop any currently playing sound and play the new one
      await _audioPlayer.stop();
      await _audioPlayer.setSource(source);
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.setPlaybackRate(rate);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing sound $soundName: $e');
    }
  }

  /// Play a sound effect with reduced volume
  Future<void> playQuiet(String soundName, {double volume = 0.3}) async {
    await play(soundName, volume: volume);
  }

  /// Stop all currently playing sounds
  Future<void> stopAll() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping sounds: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _audioPlayer.dispose();
    _loadedSounds.clear();
    _isInitialized = false;
  }
}
