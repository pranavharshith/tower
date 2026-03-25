import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';

/// In-game settings dialog — sound toggle and future settings.
///
/// Receives callbacks so it does not depend directly on [TdGame].
class GameSettingsDialog extends StatefulWidget {
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;

  const GameSettingsDialog({
    super.key,
    required this.soundEnabled,
    required this.onSoundChanged,
  });

  @override
  State<GameSettingsDialog> createState() => _GameSettingsDialogState();
}

class _GameSettingsDialogState extends State<GameSettingsDialog> {
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.soundEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Row(
        children: [
          Icon(Icons.settings_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          Text(
            'Game Settings',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: SwitchListTile(
              title: Text(
                'Sound Effects',
                style: GoogleFonts.nunito(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _soundEnabled ? 'Enabled' : 'Disabled',
                style: GoogleFonts.nunito(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              value: _soundEnabled,
              activeTrackColor: AppTheme.success.withValues(alpha: 0.5),
              activeThumbColor: AppTheme.success,
              onChanged: (value) {
                setState(() => _soundEnabled = value);
                widget.onSoundChanged(value);
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: GoogleFonts.nunito(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper to show [GameSettingsDialog], pausing/resuming the game around it.
Future<void> showGameSettings({
  required BuildContext context,
  required bool soundEnabled,
  required ValueChanged<bool> onSoundChanged,
  required VoidCallback onPause,
  required VoidCallback onResume,
  required bool wasPaused,
}) async {
  if (!wasPaused) onPause();

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => GameSettingsDialog(
      soundEnabled: soundEnabled,
      onSoundChanged: onSoundChanged,
    ),
  );

  if (!wasPaused) onResume();
}
