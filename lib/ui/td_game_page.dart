import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/td_game.dart';
import '../game/td_simulation.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_leaderboard_page.dart';

class TdGamePage extends StatefulWidget {
  final TdPrefs prefs;
  final String mapKey;
  final TdGameSettings settings;
  const TdGamePage({
    super.key,
    required this.prefs,
    required this.mapKey,
    required this.settings,
  });

  @override
  State<TdGamePage> createState() => _TdGamePageState();
}

class _TdGamePageState extends State<TdGamePage> {
  late final TdGame _game;

  @override
  void initState() {
    super.initState();
    _game = TdGame(
      mapKey: widget.mapKey,
      settings: widget.settings,
      onGameOver: _handleGameOver,
    );
  }

  Future<void> _handleGameOver(int bestWave) async {
    await widget.prefs.updateBestWave(widget.mapKey, bestWave);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TdLeaderboardPage(
          prefs: widget.prefs,
          highlightMapKey: widget.mapKey,
        ),
      ),
    );
  }

  void _showTowerStatsModal(TdTower tower) {
    final st = tower.towerType;
    final upPrice = st.upgrade?.cost;
    final cooldownAvg = (tower.cooldownMin + tower.cooldownMax) / 120.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TowerStatsSheet(
        tower: tower,
        onUpgrade: () {
          _game.upgradeSelected();
          Navigator.pop(context);
        },
        onSell: () {
          _game.sellSelected();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Game Canvas
          GameWidget(game: _game),
          // Top HUD Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.softShadow,
                ),
                child: ValueListenableBuilder<TdHudData>(
                  valueListenable: _game.hud,
                  builder: (context, hud, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Health
                        _HudItem(
                          icon: Icons.favorite_rounded,
                          iconColor: AppTheme.coral,
                          value: '${hud.health}/${hud.maxHealth}',
                          label: 'Health',
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 30,
                          color: AppTheme.gridLine,
                        ),
                        // Cash
                        _HudItem(
                          icon: Icons.attach_money_rounded,
                          iconColor: AppTheme.mustard,
                          value: '\$${hud.cash}',
                          label: 'Cash',
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 30,
                          color: AppTheme.gridLine,
                        ),
                        // Wave
                        _HudItem(
                          icon: Icons.waves_rounded,
                          iconColor: AppTheme.skyBlue,
                          value: '${hud.wave}',
                          label: 'Wave',
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 30,
                          color: AppTheme.gridLine,
                        ),
                        // Pause Button
                        GestureDetector(
                          onTap: () => _game.togglePause(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hud.paused
                                  ? AppTheme.warning.withOpacity(0.2)
                                  : AppTheme.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Icon(
                              hud.paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              color: hud.paused
                                  ? AppTheme.warning
                                  : AppTheme.success,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Bottom Store Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.mediumShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Store Title
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tower Store',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tower List
                    SizedBox(
                      height: 90,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _game.selectionRevision,
                        builder: (context, _, __) {
                          final placing = _game.placingType;
                          final selected = _game.selectedTower;

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: towerTypes.length,
                            itemBuilder: (context, index) {
                              final key = towerTypes.keys.elementAt(index);
                              final t = towerTypes[key]!;
                              final isActive =
                                  placing?.key == t.key ||
                                  selected?.towerType.key == t.key;

                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _TowerStoreItem(
                                  towerType: t,
                                  isActive: isActive,
                                  onTap: () => _game.setPlacingType(t),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tower Selection Indicator (when placing)
          Positioned(
            right: 20,
            bottom: 130,
            child: ValueListenableBuilder<int>(
              valueListenable: _game.selectionRevision,
              builder: (context, _, __) {
                final placing = _game.placingType;
                if (placing == null) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap map to place',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Selected Tower Stats (when tower is selected)
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: _game.selectionRevision,
              builder: (context, _, __) {
                final selected = _game.selectedTower;
                if (selected == null) return const SizedBox.shrink();

                // Show modal when tower is selected
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showTowerStatsModal(selected);
                  // Clear selection after showing modal
                  _game.selectTower(null);
                });

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HudItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _HudItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TowerStoreItem extends StatelessWidget {
  final TdTowerType towerType;
  final bool isActive;
  final VoidCallback onTap;

  const _TowerStoreItem({
    required this.towerType,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final towerColor = Color.fromARGB(
      255,
      towerType.color[0],
      towerType.color[1],
      towerType.color[2],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        decoration: BoxDecoration(
          color: isActive
              ? towerColor.withOpacity(0.15)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: isActive ? Border.all(color: towerColor, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tower Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: towerColor,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: towerColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                AppTheme.getTowerIcon(towerType.key),
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            // Tower Name
            Text(
              towerType.title,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Cost Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.mustard.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    size: 10,
                    color: AppTheme.mustard,
                  ),
                  Text(
                    '${towerType.cost}',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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
}

class _TowerStatsSheet extends StatelessWidget {
  final TdTower tower;
  final VoidCallback onUpgrade;
  final VoidCallback onSell;

  const _TowerStatsSheet({
    required this.tower,
    required this.onUpgrade,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final st = tower.towerType;
    final upPrice = st.upgrade?.cost;
    final cooldownAvg = (tower.cooldownMin + tower.cooldownMax) / 120.0;
    final towerColor = Color.fromARGB(
      255,
      st.color[0],
      st.color[1],
      st.color[2],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gridLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: towerColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  AppTheme.getTowerIcon(st.key),
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.title,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Cost: \$${tower.totalCost.toStringAsFixed(0)}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats
          _StatRow(
            icon: Icons.social_distance_rounded,
            label: 'Range',
            value: '${st.range} tiles',
            progress: st.range / 10, // Normalize to 0-1
            color: AppTheme.skyBlue,
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.bolt_rounded,
            label: 'Damage',
            value:
                '${tower.damageMin.toStringAsFixed(0)}-${tower.damageMax.toStringAsFixed(0)}',
            progress: tower.damageMax / 100,
            color: AppTheme.coral,
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.timer_rounded,
            label: 'Cooldown',
            value: '${cooldownAvg.toStringAsFixed(2)}s',
            progress: 1 - (cooldownAvg / 2).clamp(0, 1), // Lower is better
            color: AppTheme.secondary,
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              if (tower.canUpgrade) ...[
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onUpgrade,
                    icon: const Icon(Icons.upgrade_rounded),
                    label: Text(
                      'Upgrade${upPrice != null ? " \$$upPrice" : ""}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSell,
                  icon: const Icon(Icons.sell_rounded),
                  label: const Text('Sell'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceVariant,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.gridLine,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
