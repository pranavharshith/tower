import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';

/// Confirms quitting the current game session.
class QuitConfirmationDialog extends StatelessWidget {
  final VoidCallback onQuit;

  const QuitConfirmationDialog({super.key, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        'Quit Game?',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        'Are you sure you want to quit? Your progress will be lost.',
        style: GoogleFonts.nunito(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Continue Playing',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            onQuit();
            Navigator.of(context).pop(true);
          },
          child: Text(
            'Quit',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              color: AppTheme.coral,
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper to show [QuitConfirmationDialog], pausing game/countdown around it.
///
/// Returns `true` if the user confirmed quit, `false` if they cancelled.
Future<bool> showQuitConfirmation({
  required BuildContext context,
  required bool wasPaused,
  required VoidCallback pauseSim,
  required VoidCallback resumeSim,
  required VoidCallback pauseCountdown,
  required VoidCallback resumeCountdown,
  required VoidCallback stopAllSounds,
}) async {
  if (!wasPaused) pauseSim();
  pauseCountdown();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => QuitConfirmationDialog(onQuit: stopAllSounds),
  );

  final didQuit = result == true;
  if (!didQuit) {
    resumeCountdown();
    if (!wasPaused) resumeSim();
  }

  return didQuit;
}
