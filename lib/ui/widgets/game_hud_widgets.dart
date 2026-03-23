import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/td_simulation.dart';
import '../app_theme.dart';

class HudItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool showLabel;

  const HudItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.showLabel = true,
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
        if (showLabel) ...[
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
      ],
    );
  }
}

class TowerStoreItem extends StatelessWidget {
  final TdTowerType towerType;
  final bool isActive;
  final bool isDisabled;
  final VoidCallback onTap;

  const TowerStoreItem({
    super.key,
    required this.towerType,
    required this.isActive,
    required this.onTap,
    this.isDisabled = false,
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
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          width: 70,
          decoration: BoxDecoration(
            color: isActive
                ? towerColor.withValues(alpha: 0.15)
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: isActive ? Border.all(color: towerColor, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: towerColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: towerColor.withValues(alpha: 0.4),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mustard.withValues(alpha: 0.2),
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
      ),
    );
  }
}
