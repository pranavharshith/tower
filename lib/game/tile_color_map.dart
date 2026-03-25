import 'package:flutter/material.dart';

/// Provides the colour for each named tile type used in map display data.
///
/// The colour mapping is extracted from [TdGame.render()] so that the
/// rendering method is no longer a monolith and the mapping can be reused
/// or tested independently.
class TileColorMap {
  const TileColorMap._();

  // ---------------------------------------------------------------------------
  // Tile colour palette (soft / aesthetic variants)
  // ---------------------------------------------------------------------------
  static const Color road = Color(0xFFE8DCC4);
  static const Color grass = Color(0xFFB8E0D2);
  static const Color towerTile = Color(0xFF7FD8BE);
  static const Color sidewalk = Color(0xFFD4D4E0);

  // Theme c0 tiles (purple / brown)
  static const Color c0LightBrown = Color(0xFFE8DCC4);
  static const Color c0LightPurple = Color(0xFFC5B8E0);
  static const Color c0MediumPurple = Color(0xFF9D8EC4);
  static const Color c0DarkPurple = Color(0xFF7A6BA3);
  static const Color c0PaleGreen = Color(0xFFD4F1E0);

  // Theme c1 tiles (blue / pink)
  static const Color c1DarkBlue = Color(0xFF4A5B8C);
  static const Color c1MediumBlue = Color(0xFF6B7FD7);
  static const Color c1LightBlue = Color(0xFF9BB5F0);
  static const Color c1DarkPurple = Color(0xFF7A6BA3);
  static const Color c1NeonPink = Color(0xFFFF8B9A);

  // Theme c2 tiles (red / yellow / navy)
  static const Color c2DarkRed = Color(0xFFC45B5B);
  static const Color c2NavyBlue = Color(0xFF4A5B8C);
  static const Color c2DarkBlue = Color(0xFF5B6BA3);
  static const Color c2PaleYellow = Color(0xFFFFF4D4);
  static const Color c2LightYellow = Color(0xFFFFE8B8);

  // Shared structural colours
  static const Color wall = Color(0xFF555555);
  static const Color transparent = Color(0x00000000);

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Returns the display colour for a tile based on its [gridValue] (0–3) and
  /// optional [displayKey] string from the map's `display` array.
  ///
  /// - gridValue 0 → transparent (empty/buildable)
  /// - gridValue 1 → wall (grey)
  /// - gridValue 2 → path (uses [displayKey] for themed paths, else transparent)
  /// - gridValue 3 → water/void (transparent)
  static Color forTile(dynamic displayKey, int gridValue) {
    if (gridValue == 1) return wall;
    if (gridValue == 0) return transparent;
    if (displayKey == null) return transparent;

    return _byDisplayKey(displayKey as String);
  }

  static Color _byDisplayKey(String key) {
    switch (key) {
      case 'grass':
        return grass;
      case 'wall':
        return wall;
      case 'tower':
        return towerTile;
      case 'sidewalk':
        return sidewalk;
      case 'road':
      case 'lCorner':
      case 'rCorner':
        return road;
      case 'c0_lightBrown':
        return c0LightBrown;
      case 'c0_lightPurple':
        return c0LightPurple;
      case 'c0_mediumPurple':
        return c0MediumPurple;
      case 'c0_darkPurple':
        return c0DarkPurple;
      case 'c0_paleGreen':
        return c0PaleGreen;
      case 'c1_darkBlue':
        return c1DarkBlue;
      case 'c1_mediumBlue':
        return c1MediumBlue;
      case 'c1_lightBlue':
        return c1LightBlue;
      case 'c1_darkPurple':
        return c1DarkPurple;
      case 'c1_neonPink':
        return c1NeonPink;
      case 'c2_darkRed':
        return c2DarkRed;
      case 'c2_navyBlue':
        return c2NavyBlue;
      case 'c2_darkBlue':
        return c2DarkBlue;
      case 'c2_paleYellow':
        return c2PaleYellow;
      case 'c2_lightYellow':
        return c2LightYellow;
      default:
        return transparent;
    }
  }
}
