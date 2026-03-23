import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_leaderboard_page.dart';
import 'td_map_select_page.dart';
import 'td_settings_page.dart';

class TdEntryMenu extends StatelessWidget {
  final TdPrefs prefs;
  const TdEntryMenu({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo/Title Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    children: [
                      // Game Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        'Tower Defense',
                        style: GoogleFonts.nunito(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'Defend your base!',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Play Button - Primary
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TdMapSelectPage(prefs: prefs),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      elevation: 4,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Settings Button - Secondary
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TdSettingsPage(prefs: prefs),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded, size: 22),
                    label: const Text('Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceVariant,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      elevation: 0,
                      textStyle: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Leaderboard Button - Secondary
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TdLeaderboardPage(prefs: prefs),
                        ),
                      );
                    },
                    icon: const Icon(Icons.emoji_events_rounded, size: 22),
                    label: const Text('Leaderboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceVariant,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      elevation: 0,
                      textStyle: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
