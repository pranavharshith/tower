import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/td_simulation.dart';
import '../app_theme.dart';

class TowerStatsSheet extends StatelessWidget {
  final TdTower tower;
  final VoidCallback? onUpgrade;
  final VoidCallback onSell;
  final bool canAffordUpgrade;

  const TowerStatsSheet({
    super.key,
    required this.tower,
    required this.onUpgrade,
    required this.onSell,
    this.canAffordUpgrade = true,
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

    String displayTitle = st.title;
    String? appliedUpgradeName;
    if (tower.upgraded && st.upgrade != null) {
      appliedUpgradeName = tower.appliedUpgradeName ?? st.upgrade!.title;
      displayTitle = appliedUpgradeName;
    }

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
                      displayTitle,
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
                    if (tower.upgraded)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tower.appliedUpgradeName?.toUpperCase() ??
                                  'UPGRADED',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StatRow(
            icon: Icons.social_distance_rounded,
            label: 'Range',
            value: '${tower.range} tiles',
            progress: tower.range / 10, 
            color: AppTheme.skyBlue,
          ),
          const SizedBox(height: 12),
          StatRow(
            icon: Icons.bolt_rounded,
            label: 'Damage',
            value:
                '${tower.damageMin.toStringAsFixed(0)}-${tower.damageMax.toStringAsFixed(0)}',
            progress: tower.damageMax / 100,
            color: AppTheme.coral,
          ),
          const SizedBox(height: 12),
          StatRow(
            icon: Icons.timer_rounded,
            label: 'Cooldown',
            value: '${cooldownAvg.toStringAsFixed(2)}s',
            progress: 1 - (cooldownAvg / 2).clamp(0, 1), 
            color: AppTheme.secondary,
          ),
          const SizedBox(height: 24),
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
                      backgroundColor: canAffordUpgrade
                          ? AppTheme.success
                          : Colors.grey,
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
              ] else if (tower.upgraded) ...[
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: AppTheme.success, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: AppTheme.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MAX LEVEL',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
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

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;

  const StatRow({
    super.key,
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
            color: color.withValues(alpha: 0.15),
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

class StatChangeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String oldValue;
  final String newValue;
  final num change;
  final bool isGoodIfHigher; 

  const StatChangeRow({
    super.key,
    required this.icon,
    required this.label,
    required this.oldValue,
    required this.newValue,
    required this.change,
    required this.isGoodIfHigher,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = isGoodIfHigher ? change >= 0 : change <= 0;
    final changeColor = isPositive ? AppTheme.success : AppTheme.error;
    final changeIcon = isPositive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    final changeSign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: changeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            oldValue,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                newValue,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(changeIcon, size: 16, color: changeColor),
              Text(
                '($changeSign${_formatChange(change)})',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatChange(num change) {
    if (change is int) {
      return change.abs().toString();
    } else {
      return change.abs().toStringAsFixed(2);
    }
  }
}
