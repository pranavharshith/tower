import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme for Tower Defense Game
///
/// Color Palette (Dark Theme inspired by towerdefense):
/// - Background: Black (#000000)
/// - Surface: Navy blue (#013243)
/// - Primary: Green (#00E640) for borders and accents
/// - Text: Green (#00E640) on dark backgrounds
///
/// Typography: Nunito - friendly, rounded sans-serif
/// Shapes: Squircles (BorderRadius.circular(16))

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Background colors (Dark theme)
  static const Color background = Color(0xFF000000); // Black background
  static const Color surface = Color(0xFF013243); // Navy blue panels
  static const Color surfaceVariant = Color(
    0xFF0A3A4A,
  ); // Slightly lighter navy

  // Primary colors (Green accent like towerdefense)
  static const Color primary = Color(0xFF00E640); // Green accent
  static const Color primaryLight = Color(0xFF4AFF7A);
  static const Color primaryDark = Color(0xFF00B030);

  // Secondary colors
  static const Color secondary = Color(0xFF00E640); // Same green
  static const Color secondaryLight = Color(0xFF4AFF7A);

  // Accent colors (keeping some for tower differentiation)
  static const Color coral = Color(0xFFFF8B7B); // Soft coral red
  static const Color skyBlue = Color(0xFF7BC8FF); // Sky blue
  static const Color mustard = Color(0xFFFFD166); // Mustard yellow
  static const Color mint = Color(0xFF00E640); // Green

  // Semantic colors
  static const Color success = Color(0xFF00E640);
  static const Color warning = Color(0xFFFFD166);
  static const Color error = Color(0xFFFF8B7B);
  static const Color info = Color(0xFF7BC8FF);

  // Text colors (Green on dark)
  static const Color textPrimary = Color(0xFF00E640); // Green text
  static const Color textSecondary = Color(0xFF80F2A0); // Lighter green
  static const Color textMuted = Color(0xFF4A9A60); // Muted green

  // Grid colors for game
  static const Color gridBackground = Color(0xFF001020); // Dark navy
  static const Color gridLine = Color(0xFF00E640); // Green grid lines
  static const Color pathTile = Color(0xFF1A4A5A); // Path tiles

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusPill = 50.0;

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Typography
  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.nunito(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      color: textPrimary,
    ),
    displayMedium: GoogleFonts.nunito(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    headlineLarge: GoogleFonts.nunito(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    headlineMedium: GoogleFonts.nunito(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleLarge: GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textSecondary,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
  );

  // Theme Data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.black,
      primaryContainer: primaryLight,
      onPrimaryContainer: Colors.black,
      secondary: secondary,
      onSecondary: Colors.black,
      secondaryContainer: secondaryLight,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      error: coral,
      onError: Colors.black,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: surface,
      foregroundColor: textPrimary,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        side: const BorderSide(color: primary, width: 2),
        textStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: const BorderSide(color: primary, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge)),
        side: BorderSide(color: primary, width: 1),
      ),
    ),
  );

  // Keep lightTheme as alias for backward compatibility (uses dark theme now)
  static ThemeData get lightTheme => darkTheme;

  // Tower type colors for the game
  static Color getTowerColor(String towerKey) {
    switch (towerKey) {
      case 'gun':
        return const Color(0xFF7BC8FF); // Sky blue
      case 'laser':
        return const Color(0xFFFF8B7B); // Coral
      case 'slow':
        return const Color(0xFF7FD8BE); // Mint
      case 'sniper':
        return const Color(0xFF6B7FD7); // Indigo
      case 'rocket':
        return const Color(0xFFFFD166); // Mustard
      case 'bomb':
        return const Color(0xFFFF6B6B); // Red
      case 'tesla':
        return const Color(0xFF9D4EDD); // Purple
      default:
        return const Color(0xFF6B7FD7);
    }
  }

  // Tower icons
  static IconData getTowerIcon(String towerKey) {
    switch (towerKey) {
      case 'gun':
        return Icons.adjust;
      case 'laser':
        return Icons.bolt;
      case 'slow':
        return Icons.ac_unit;
      case 'sniper':
        return Icons.my_location;
      case 'rocket':
        return Icons.rocket;
      case 'bomb':
        return Icons.circle;
      case 'tesla':
        return Icons.electric_bolt;
      default:
        return Icons.cell_tower;
    }
  }
}
