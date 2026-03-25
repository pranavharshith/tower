/// Interface for sound service to decouple from implementation
abstract class ISoundService {
  bool get isEnabled;
  void setEnabled(bool enabled);
  Future<void> initialize();
  Future<void> play(String soundName, {double volume = 1.0, double rate = 1.0});
  Future<void> playQuiet(String soundName, {double volume = 0.3});
  Future<void> stopAll();
  void dispose();
}
