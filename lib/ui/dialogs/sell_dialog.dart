import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../../game/entities/tower.dart';

/// Confirms selling a tower before removing it from the map.
class SellConfirmationDialog extends StatelessWidget {
  final TdTower tower;
  final int sellPrice;
  final VoidCallback onConfirm;

  const SellConfirmationDialog({
    super.key,
    required this.tower,
    required this.sellPrice,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        'Sell Tower?',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        'Sell ${tower.towerType.title} for \$$sellPrice?',
        style: GoogleFonts.nunito(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.nunito(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
            HapticFeedback.lightImpact();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
          child: Text(
            'Sell for \$$sellPrice',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper to show the [SellConfirmationDialog] as a modal.
Future<void> showSellConfirmation({
  required BuildContext context,
  required TdTower tower,
  required int sellPrice,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    builder: (_) => SellConfirmationDialog(
      tower: tower,
      sellPrice: sellPrice,
      onConfirm: onConfirm,
    ),
  );
}
