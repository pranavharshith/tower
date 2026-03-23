import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/td_maps.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';

class TdLeaderboardPage extends StatefulWidget {
  final TdPrefs prefs;
  final String? highlightMapKey;
  const TdLeaderboardPage({
    super.key,
    required this.prefs,
    this.highlightMapKey,
  });

  @override
  State<TdLeaderboardPage> createState() => _TdLeaderboardPageState();
}

class _TdLeaderboardPageState extends State<TdLeaderboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'Leaderboard',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: widget.prefs.getBestWaves(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {};
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final options = TdMaps.options;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final opt = options[index];
                final best = data[opt.key] ?? 0;
                final isHighlight = widget.highlightMapKey == opt.key;
                return _LeaderboardCard(
                  option: opt,
                  bestWave: best,
                  isHighlight: isHighlight,
                  rank: index + 1,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final MapOption option;
  final int bestWave;
  final bool isHighlight;
  final int rank;

  const _LeaderboardCard({
    required this.option,
    required this.bestWave,
    required this.isHighlight,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isHighlight
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Map Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isHighlight
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isHighlight)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Just Played',
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: option.isRandom
                          ? AppTheme.secondaryLight
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      option.isRandom ? 'Random Map' : 'Premade Map',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: option.isRandom
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Best Wave
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bestWave > 0
                    ? (isHighlight
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.mustard.withValues(alpha: 0.2))
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bestWave > 0 ? '$bestWave' : '-',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: bestWave > 0
                          ? (isHighlight
                                ? AppTheme.primary
                                : AppTheme.textPrimary)
                          : AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    'Wave',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: bestWave > 0
                          ? (isHighlight
                                ? AppTheme.primary.withValues(alpha: 0.7)
                                : AppTheme.textSecondary)
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppTheme.surfaceVariant;
    }
  }
}
