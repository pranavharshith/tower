import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TdPrefs {
  static const _stretchModeKey = 'td_stretch_mode_v1';
  static const _soundEnabledKey = 'td_sound_enabled_v1';
  static const _effectsEnabledKey = 'td_effects_enabled_v1';
  static const _leaderboardKey = 'td_leaderboard_by_map_v1';
  static const _tutorialCompletedKey = 'td_tutorial_completed_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<bool> getStretchMode() async {
    final p = await _prefs();
    return p.getBool(_stretchModeKey) ?? true;
  }

  Future<void> setStretchMode(bool value) async {
    final p = await _prefs();
    await p.setBool(_stretchModeKey, value);
  }

  Future<bool> getSoundEnabled() async {
    final p = await _prefs();
    return p.getBool(_soundEnabledKey) ?? false;
  }

  Future<void> setSoundEnabled(bool value) async {
    final p = await _prefs();
    await p.setBool(_soundEnabledKey, value);
  }

  Future<bool> getEffectsEnabled() async {
    final p = await _prefs();
    return p.getBool(_effectsEnabledKey) ?? true;
  }

  Future<void> setEffectsEnabled(bool value) async {
    final p = await _prefs();
    await p.setBool(_effectsEnabledKey, value);
  }

  /// Returns best wave reached per map key.
  Future<Map<String, int>> getBestWaves() async {
    final p = await _prefs();
    final raw = p.getString(_leaderboardKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<int> getBestWaveForMap(String mapKey) async {
    final all = await getBestWaves();
    return all[mapKey] ?? 0;
  }

  /// Updates best wave only if new wave is higher.
  Future<void> updateBestWave(String mapKey, int bestWave) async {
    final p = await _prefs();
    final all = await getBestWaves();
    final cur = all[mapKey] ?? 0;
    if (bestWave <= cur) return;
    all[mapKey] = bestWave;
    await p.setString(_leaderboardKey, json.encode(all));
  }

  /// Tutorial completion tracking
  Future<bool> getTutorialCompleted() async {
    final p = await _prefs();
    return p.getBool(_tutorialCompletedKey) ?? false;
  }

  Future<void> setTutorialCompleted(bool value) async {
    final p = await _prefs();
    await p.setBool(_tutorialCompletedKey, value);
  }
}
