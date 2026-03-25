import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../game/td_game.dart';
import '../app_theme.dart';
import 'game_hud_widgets.dart';

class GameStatsBar extends StatelessWidget {
  final TdGame game;

  const GameStatsBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.softShadow,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 400;
            return ValueListenableBuilder<TdHudData>(
              valueListenable: game.hud,
              builder: (context, hud, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHealthItem(hud, isNarrow),
                    _buildDivider(),
                    HudItem(
                      icon: Icons.attach_money_rounded,
                      iconColor: AppTheme.mustard,
                      value: '\${hud.cash}',
                      label: 'Cash',
                      showLabel: !isNarrow,
                    ),
                    _buildDivider(),
                    HudItem(
                      icon: Icons.waves_rounded,
                      iconColor: AppTheme.skyBlue,
                      value: '${hud.wave}',
                      label: 'Wave',
                      showLabel: !isNarrow,
                    ),
                    _buildDivider(),
                    HudItem(
                      icon: Icons.architecture_rounded,
                      iconColor: hud.maxTowersReached
                          ? AppTheme.error
                          : AppTheme.mustard,
                      value: '${hud.towerCount}/${hud.maxTowers}',
                      label: 'Towers',
                      showLabel: !isNarrow,
                    ),
                    _buildDivider(),
                    if (hud.gameStarted) _buildPauseButton(hud),
                    if (hud.gameStarted) ...[
                      _buildDivider(),
                      _buildSettingsButton(context),
                    ],
                    if (!hud.gameStarted) _buildCountdown(hud),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHealthItem(TdHudData hud, bool isNarrow) {
    return Stack(
      children: [
        HudItem(
          icon: Icons.favorite_rounded,
          iconColor: hud.isBossWave ? const Color(0xFFFF00FF) : AppTheme.coral,
          value: '${hud.health}/${hud.maxHealth}',
          label: 'Health',
          showLabel: !isNarrow,
        ),
        if (hud.healEffectTicks > 0)
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: hud.healEffectTicks / 60.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${hud.healAmount}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 30, color: AppTheme.gridLine);
  }

  Widget _buildPauseButton(TdHudData hud) {
    return GestureDetector(
      onTap: () => game.togglePause(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hud.paused
              ? AppTheme.warning.withValues(alpha: 0.2)
              : AppTheme.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Icon(
          hud.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: hud.paused ? AppTheme.warning : AppTheme.success,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Trigger settings callback if needed
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Icon(Icons.settings_rounded, color: AppTheme.primary, size: 24),
      ),
    );
  }

  Widget _buildCountdown(TdHudData hud) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Text(
        'Starting in ${hud.countdownSeconds}s',
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.warning,
        ),
      ),
    );
  }
}
