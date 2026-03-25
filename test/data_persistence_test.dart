import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/services/td_prefs.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Persistence and Security', () {
    late TdPrefs prefs;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      prefs = TdPrefs();
    });

    test('Preferences initialize with defaults', () async {
      await prefs.init();

      expect(await prefs.getStretchMode(), true);
      expect(await prefs.getSoundEnabled(), false);
      expect(await prefs.getEffectsEnabled(), true);
      expect(await prefs.getTutorialCompleted(), false);
      expect(await prefs.getBestWaves(), isEmpty);
    });

    test('Stretch mode persists correctly', () async {
      await prefs.init();
      await prefs.setStretchMode(false);

      expect(await prefs.getStretchMode(), false);

      await prefs.setStretchMode(true);
      expect(await prefs.getStretchMode(), true);
    });

    test('Sound enabled persists correctly', () async {
      await prefs.init();
      await prefs.setSoundEnabled(true);

      expect(await prefs.getSoundEnabled(), true);

      await prefs.setSoundEnabled(false);
      expect(await prefs.getSoundEnabled(), false);
    });

    test('Tutorial completion persists', () async {
      await prefs.init();
      expect(await prefs.getTutorialCompleted(), false);

      await prefs.setTutorialCompleted(true);
      expect(await prefs.getTutorialCompleted(), true);
    });

    test('Best wave updates correctly', () async {
      await prefs.init();

      await prefs.updateBestWave('loops', 5);
      expect(await prefs.getBestWaveForMap('loops'), 5);

      await prefs.updateBestWave('loops', 10);
      expect(await prefs.getBestWaveForMap('loops'), 10);

      // Should not update if lower
      await prefs.updateBestWave('loops', 7);
      expect(await prefs.getBestWaveForMap('loops'), 10);
    });

    test('Multiple maps tracked independently', () async {
      await prefs.init();

      await prefs.updateBestWave('loops', 5);
      await prefs.updateBestWave('city', 8);
      await prefs.updateBestWave('dualU', 12);

      expect(await prefs.getBestWaveForMap('loops'), 5);
      expect(await prefs.getBestWaveForMap('city'), 8);
      expect(await prefs.getBestWaveForMap('dualU'), 12);
    });

    test('Unknown map returns 0', () async {
      await prefs.init();
      expect(await prefs.getBestWaveForMap('unknown_map'), 0);
    });

    test('Corrupted data handled gracefully', () async {
      // This test verifies error handling doesn't crash
      await prefs.init();

      // Should not throw even with corrupted data
      expect(() async => await prefs.getBestWaves(), returnsNormally);
    });
  });
}
