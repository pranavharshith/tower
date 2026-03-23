import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/td_prefs.dart';
import 'app_theme.dart';

/// Tutorial overlay that shows on first game launch
class TutorialOverlay extends StatefulWidget {
  final TdPrefs prefs;
  final VoidCallback onComplete;

  const TutorialOverlay({
    super.key,
    required this.prefs,
    required this.onComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Strictly dispose controller before super.dispose to prevent active Ticker exceptions
    _pulseController.dispose();
    super.dispose();
  }

  final List<_TutorialPage> _pages = [
    _TutorialPage(
      icon: Icons.architecture_rounded,
      title: 'Build Towers',
      description:
          'Place towers along the path to stop enemies from reaching the exit.',
      tip: 'Tap a tower from the store, then tap on the map to place it.',
    ),
    _TutorialPage(
      icon: Icons.touch_app_rounded,
      title: 'Tower Store Controls',
      description:
          'Tap a tower in the store to select it for placement.\n\nTap the same tower again to deselect and cancel placement.\n\nTap empty space on the map to deselect a placed tower.',
      tip: 'Use the toggle to quickly change your mind about placement!',
    ),
    _TutorialPage(
      icon: Icons.ads_click_rounded,
      title: 'Placed Tower Controls',
      description:
          'Single tap a placed tower to see its attack range.\n\nDouble tap a tower to view detailed stats and upgrade options.\n\nTap empty space to hide the range circle.',
      tip: 'Use range circles to plan optimal tower placement!',
    ),
    _TutorialPage(
      icon: Icons.attach_money_rounded,
      title: 'Earn & Upgrade',
      description:
          'Defeat enemies to earn cash. Use it to upgrade or sell towers.',
      tip: 'Upgraded towers are more powerful and have better range.',
    ),
    _TutorialPage(
      icon: Icons.waves_rounded,
      title: 'Survive Waves',
      description:
          'Enemies come in waves. Stronger enemies appear in later waves.',
      tip: 'Every 5th wave is a boss wave - be prepared!',
    ),
    _TutorialPage(
      icon: Icons.tips_and_updates_rounded,
      title: 'Tower Types',
      description:
          'Each tower has unique strengths:\n\n• Gun: Fast, cheap, short range\n• Laser: Balanced damage & range\n• Sniper: Long range, high damage\n• Rocket: Area damage, splash effect\n• Tesla: Chain lightning to multiple enemies',
      tip: 'Mix different tower types for maximum effectiveness!',
    ),
  ];

  Future<void> _completeTutorial() async {
    await widget.prefs.setTutorialCompleted(true);
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? AppTheme.primary
                          : AppTheme.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Icon (Animated Pulse)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Icon(page.icon, size: 64, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                page.title,
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // Tip box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppTheme.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        page.tip,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Navigation buttons
              Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentPage--;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                        ),
                        child: Text('Back', style: GoogleFonts.nunito()),
                      ),
                    )
                  else
                    const SizedBox(width: 100),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _completeTutorial();
                        } else {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Start Playing' : 'Next',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage {
  final IconData icon;
  final String title;
  final String description;
  final String tip;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.tip,
  });
}
