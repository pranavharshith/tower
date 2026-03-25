/// Enum representing all valid map identifiers in the game.
///
/// Using an enum instead of raw strings provides:
/// - Type safety at compile time
/// - IDE autocomplete support
/// - Prevention of typos in map keys
/// - Easy iteration over all maps
enum MapKey {
  /// Simple loop map - basic circular path
  loops,

  /// Dual U-turn map - two parallel U-shaped paths
  dualU,

  /// Boss battle map - special arena for boss fights
  boss,

  /// Simple straight path (used for testing)
  simple,
}

extension MapKeyExtension on MapKey {
  /// Get the string representation for loading from TdMaps
  String get keyString {
    switch (this) {
      case MapKey.loops:
        return 'loops';
      case MapKey.dualU:
        return 'dualU';
      case MapKey.boss:
        return 'boss';
      case MapKey.simple:
        return 'simple';
    }
  }

  /// Check if this is a valid premade map key
  bool get isPremade => this != MapKey.simple;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case MapKey.loops:
        return 'Loops';
      case MapKey.dualU:
        return 'Dual U-Turn';
      case MapKey.boss:
        return 'Boss Arena';
      case MapKey.simple:
        return 'Simple (Test)';
    }
  }
}

/// Helper to convert string to MapKey safely
MapKey? mapKeyFromString(String key) {
  try {
    return MapKey.values.firstWhere((mk) => mk.keyString == key);
  } catch (e) {
    return null;
  }
}
