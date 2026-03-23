import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TdPrefs {
  static const _stretchModeKey = 'td_stretch_mode_v1';
  static const _soundEnabledKey = 'td_sound_enabled_v1';
  static const _effectsEnabledKey = 'td_effects_enabled_v1';
  static const _leaderboardKey = 'td_leaderboard_by_map_v1';
  static const _tutorialCompletedKey = 'td_tutorial_completed_v1';

  static const _salt = 'td_t0w3r_s3cur3_s@lt_v1';

  final FlutterSecureStorage _storage;

  // In-memory cache for fast, synchronous reads by the game engine
  bool _stretchMode = true;
  bool _soundEnabled = false;
  bool _effectsEnabled = true;
  bool _tutorialCompleted = false;
  Map<String, int> _bestWaves = {};

  TdPrefs() : _storage = const FlutterSecureStorage();

  /// Must be called during app initialization to load secure data into memory
  Future<void> init() async {
    final stretchStr = await _storage.read(key: _stretchModeKey);
    if (stretchStr != null) _stretchMode = stretchStr == 'true';

    final soundStr = await _storage.read(key: _soundEnabledKey);
    if (soundStr != null) _soundEnabled = soundStr == 'true';

    final effectsStr = await _storage.read(key: _effectsEnabledKey);
    if (effectsStr != null) _effectsEnabled = effectsStr == 'true';

    final tutStr = await _storage.read(key: _tutorialCompletedKey);
    if (tutStr != null) _tutorialCompleted = tutStr == 'true';

    final lbStr = await _storage.read(key: _leaderboardKey);
    if (lbStr != null && lbStr.isNotEmpty) {
      final validJsonStr = await _deobfuscate(lbStr);
      if (validJsonStr != null) {
        try {
          final decoded = json.decode(validJsonStr) as Map<String, dynamic>;
          _bestWaves = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
        } catch (_) {}
      }
    }
  }

  String _generateChecksum(String data) {
    final key = utf8.encode(_salt);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  Future<String> _obfuscate(String data) async {
    final checksum = _generateChecksum(data);
    final payload = '$checksum|$data';
    return base64.encode(utf8.encode(payload));
  }

  Future<String?> _deobfuscate(String encoded) async {
    if (encoded.isEmpty) return null;
    try {
      final decoded = utf8.decode(base64.decode(encoded));
      if (!decoded.contains('|')) return null;

      final idx = decoded.indexOf('|');
      final checksum = decoded.substring(0, idx);
      final data = decoded.substring(idx + 1);

      if (_generateChecksum(data) != checksum) {
        return null; // Checksum failed (tampered)
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  // --- API Methods (Keep Future signatures for backwards compatibility) ---

  Future<bool> getStretchMode() async => _stretchMode;
  Future<void> setStretchMode(bool value) async {
    _stretchMode = value;
    await _storage.write(key: _stretchModeKey, value: value.toString());
  }

  Future<bool> getSoundEnabled() async => _soundEnabled;
  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _storage.write(key: _soundEnabledKey, value: value.toString());
  }

  Future<bool> getEffectsEnabled() async => _effectsEnabled;
  Future<void> setEffectsEnabled(bool value) async {
    _effectsEnabled = value;
    await _storage.write(key: _effectsEnabledKey, value: value.toString());
  }

  Future<bool> getTutorialCompleted() async => _tutorialCompleted;
  Future<void> setTutorialCompleted(bool value) async {
    _tutorialCompleted = value;
    await _storage.write(key: _tutorialCompletedKey, value: value.toString());
  }

  Future<Map<String, int>> getBestWaves() async => Map.from(_bestWaves);

  Future<int> getBestWaveForMap(String mapKey) async => _bestWaves[mapKey] ?? 0;

  Future<void> updateBestWave(String mapKey, int bestWave) async {
    final cur = _bestWaves[mapKey] ?? 0;
    if (bestWave <= cur) return;

    _bestWaves[mapKey] = bestWave;
    final jsonStr = json.encode(_bestWaves);
    final obf = await _obfuscate(jsonStr);
    await _storage.write(key: _leaderboardKey, value: obf);
  }
}
