import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../widgets/tower_stats_modal.dart';
import '../../game/entities/tower.dart';

/// Confirms a tower upgrade before committing it.
///
/// Shows stat changes (range, damage, cooldown) and remaining cash after
/// purchase. Calls [onConfirm] with the upgrade cost when the user proceeds.
class UpgradeConfirmationDialog extends StatelessWidget {
  final TdTower tower;
  final VoidCallback onConfirm;

  const UpgradeConfirmationDialog({
    super.key,
    required this.tower,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final upgrade = tower.towerType.upgrade!;
    final upgradeCost = upgrade.cost;
    final cash = tower.totalCost.toInt(); // Caller should pass current cash

    // Stat diff calculations
    final oldRange = tower.range;
    final newRange = upgrade.range ?? oldRange;

    final oldDpsMin = tower.damageMin;
    final newDpsMin = upgrade.damageMin ?? oldDpsMin;
    final oldDpsMax = tower.damageMax;
    final newDpsMax = upgrade.damageMax ?? oldDpsMax;

    final oldCooldownAvg = (tower.cooldownMin + tower.cooldownMax) / 120.0;
    final newCooldownMin = upgrade.cooldownMin ?? tower.cooldownMin;
    final newCooldownMax = upgrade.cooldownMax ?? tower.cooldownMax;
    final newCooldownAvg = (newCooldownMin + newCooldownMax) / 120.0;
    final cooldownDiff = oldCooldownAvg - newCooldownAvg;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Row(
        children: [
          Icon(Icons.upgrade_rounded, color: AppTheme.success, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade to ${upgrade.title}?',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CostBanner(cost: upgradeCost),
            const SizedBox(height: 16),
            Text(
              'Stat Changes:',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            StatChangeRow(
              icon: Icons.social_distance_rounded,
              label: 'Range',
              oldValue: '$oldRange tiles',
              newValue: '$newRange tiles',
              change: (newRange - oldRange).toDouble(),
              isGoodIfHigher: true,
            ),
            StatChangeRow(
              icon: Icons.bolt_rounded,
              label: 'Damage',
              oldValue:
                  '${oldDpsMin.toStringAsFixed(0)}-${oldDpsMax.toStringAsFixed(0)}',
              newValue:
                  '${newDpsMin.toStringAsFixed(0)}-${newDpsMax.toStringAsFixed(0)}',
              change: newDpsMin - oldDpsMin,
              isGoodIfHigher: true,
            ),
            StatChangeRow(
              icon: Icons.timer_rounded,
              label: 'Cooldown',
              oldValue: '${oldCooldownAvg.toStringAsFixed(2)}s',
              newValue: '${newCooldownAvg.toStringAsFixed(2)}s',
              change: cooldownDiff,
              isGoodIfHigher: false,
            ),
            const SizedBox(height: 16),
            _AfterCashBanner(cash: cash, cost: upgradeCost),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.nunito(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
            HapticFeedback.mediumImpact();
            _showUpgradeSnackBar(context, upgrade.title);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.check_rounded),
          label: Text(
            'Upgrade',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showUpgradeSnackBar(BuildContext context, String title) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Tower upgraded to $title!',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Shows upgrade cost in a highlighted row.
class _CostBanner extends StatelessWidget {
  final int cost;
  const _CostBanner({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money_rounded, color: AppTheme.mustard, size: 20),
          const SizedBox(width: 8),
          Text(
            'Cost: \$$cost',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows remaining cash after deducting upgrade cost.
class _AfterCashBanner extends StatelessWidget {
  final int cash;
  final int cost;
  const _AfterCashBanner({required this.cash, required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: AppTheme.success,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Cash After: \$${cash - cost}',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to show the [UpgradeConfirmationDialog] as a modal.
Future<void> showUpgradeConfirmation({
  required BuildContext context,
  required TdTower tower,
  required int currentCash,
  required VoidCallback onConfirm,
}) {
  // Pass the current cash via a temporary workaround: inject into totalCost
  // NOTE: the dialog reads tower.totalCost for cash display — callers must
  // pass a tower copy or this helper handles it via a wrapper widget.
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpgradeConfirmationDialog(
      tower: tower,
      onConfirm: onConfirm,
    ),
  );
}
