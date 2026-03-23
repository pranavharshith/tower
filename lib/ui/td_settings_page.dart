import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/td_prefs.dart';
import 'app_theme.dart';

class TdSettingsPage extends StatefulWidget {
  final TdPrefs prefs;
  const TdSettingsPage({super.key, required this.prefs});

  @override
  State<TdSettingsPage> createState() => _TdSettingsPageState();
}

class _TdSettingsPageState extends State<TdSettingsPage> {
  bool? _stretchMode;
  bool? _soundEnabled;
  bool? _effectsEnabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _showTutorial() async {
    // Reset tutorial completion to allow rewatching
    await widget.prefs.setTutorialCompleted(false);

    if (!mounted) return;

    // Navigate back to entry menu (tutorial will show on next game start)
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst); // Go to root

      // Show snackbar with instructions
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial reset! Start a new game to watch.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    _stretchMode = await widget.prefs.getStretchMode();
    _soundEnabled = await widget.prefs.getSoundEnabled();
    _effectsEnabled = await widget.prefs.getEffectsEnabled();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_stretchMode == null ||
        _soundEnabled == null ||
        _effectsEnabled == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Display Section
            _SectionHeader(
              title: 'Display',
              icon: Icons.display_settings_rounded,
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.aspect_ratio_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Stretch Mode',
                    subtitle: 'Makes the map fill the whole screen',
                    trailing: Switch(
                      value: _stretchMode!,
                      onChanged: (v) async {
                        setState(() => _stretchMode = v);
                        await widget.prefs.setStretchMode(v);
                      },
                      activeThumbColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Audio Section
            _SectionHeader(title: 'Audio', icon: Icons.volume_up_rounded),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.music_note_rounded,
                    iconColor: AppTheme.skyBlue,
                    title: 'Sound',
                    subtitle: 'Enable game sounds',
                    trailing: Switch(
                      value: _soundEnabled!,
                      onChanged: (v) async {
                        setState(() => _soundEnabled = v);
                        await widget.prefs.setSoundEnabled(v);
                      },
                      activeThumbColor: AppTheme.skyBlue,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppTheme.mint,
                    title: 'Effects',
                    subtitle: 'Enable particle effects',
                    trailing: Switch(
                      value: _effectsEnabled!,
                      onChanged: (v) async {
                        setState(() => _effectsEnabled = v);
                        await widget.prefs.setEffectsEnabled(v);
                      },
                      activeThumbColor: AppTheme.mint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tutorial Section
            _SectionHeader(title: 'Tutorial', icon: Icons.school_rounded),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.play_arrow_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Watch Tutorial',
                    subtitle: 'Learn how to play the game',
                    showArrow: true,
                    onTap: () => _showTutorial(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Info Section
            _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.gamepad_rounded,
                    iconColor: AppTheme.coral,
                    title: 'Tower Defense',
                    subtitle: 'Version 1.0.0',
                    showArrow: false,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showArrow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showArrow)
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
