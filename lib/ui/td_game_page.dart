import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/td_game.dart';
import '../game/td_simulation.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_leaderboard_page.dart';
import 'tutorial_overlay.dart';
import 'widgets/game_hud_widgets.dart';
import 'widgets/tower_stats_modal.dart';

class TdGamePage extends ConsumerStatefulWidget {
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
  ConsumerState<TdGamePage> createState() => _TdGamePageState();
}

class _TdGamePageState extends ConsumerState<TdGamePage> {
  late final TdGame _game;

  // "Tap to place" message visibility timer
  bool _showTapToPlace = false;
  Timer? _tapToPlaceTimer;
  TdTowerType? _lastPlacingType;

  // Tutorial overlay
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _game = TdGame(
      mapKey: widget.mapKey,
      settings: widget.settings,
      onGameOver: _handleGameOver,
      onHudUpdate: (data) {
        Future.microtask(() {
          _game.hud.value = data;
          if (ref.exists(hudProvider)) {
            ref.read(hudProvider.notifier).updateData(data);
          }
        });
      },
      onSelectionRevision: () {
        _game.selectionRevision.value++;
        Future.microtask(() {
          if (ref.exists(selectionRevisionProvider)) {
            ref.read(selectionRevisionProvider.notifier).increment();
          }
        });
      },
    );

    // Initialize sound and particles from prefs
    _initEffectsFromPrefs();

    // Check if we should show tutorial - this will pause the game
    _checkAndShowTutorial();

    // Set up callback for placement failure feedback
    _game.onPlacementFailed = (reason) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Reset the tap to place message so it shows again
      setState(() {
        _showTapToPlace = true;
        _lastPlacingType = null; // Reset so it will show again
      });
      _tapToPlaceTimer?.cancel();
      _tapToPlaceTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showTapToPlace = false;
          });
        }
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot place tower: $reason',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    };
  }

  Future<void> _initEffectsFromPrefs() async {
    final soundEnabled = await widget.prefs.getSoundEnabled();
    final effectsEnabled = await widget.prefs.getEffectsEnabled();

    if (mounted) {
      _game.setSoundsEnabled(soundEnabled, fromPrefs: true);
      _game.setParticlesEnabled(effectsEnabled, fromPrefs: true);
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final tutorialCompleted = await widget.prefs.getTutorialCompleted();
    if (!tutorialCompleted && mounted) {
      setState(() {
        _showTutorial = true;
      });
      // Pause the game countdown while tutorial is showing
      _game.pauseCountdown(true);
    }
  }

  @override
  void dispose() {
    _tapToPlaceTimer?.cancel();
    super.dispose();
  }

  void _updateTapToPlaceMessage(TdTowerType? placingType) {
    if (placingType != null && placingType != _lastPlacingType) {
      // New tower type selected - show message for 3 seconds
      setState(() {
        _showTapToPlace = true;
        _lastPlacingType = placingType;
      });
      _tapToPlaceTimer?.cancel();
      _tapToPlaceTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showTapToPlace = false;
          });
        }
      });
    } else if (placingType == null) {
      // Tower placement cancelled/completed
      _tapToPlaceTimer?.cancel();
      setState(() {
        _showTapToPlace = false;
        _lastPlacingType = null;
      });
    }
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
    final sellPrice = tower.sellPrice();
    final upgradeCost = tower.towerType.upgrade?.cost;
    final canUpgrade = !tower.upgraded && tower.towerType.upgrade != null;
    final cash = _game.sim.cash;
    final canAffordUpgrade =
        canUpgrade && upgradeCost != null && cash >= upgradeCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TowerStatsSheet(
        tower: tower,
        onUpgrade: canAffordUpgrade
            ? () {
                // Close modal and show upgrade confirmation
                Navigator.pop(context);
                _showUpgradeConfirmation(tower);
              }
            : null, // Disabled when can't afford or already upgraded
        onSell: () {
          Navigator.pop(context);
          _showSellConfirmation(tower, sellPrice);
        },
        canAffordUpgrade: canAffordUpgrade,
      ),
    );
  }

  void _showGameSettings() {
    // Pause the game when opening settings
    final wasPaused = _game.sim.paused;
    if (!wasPaused) {
      _game.togglePause();
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                // Sound toggle
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
                      _game.soundService.isEnabled ? 'Enabled' : 'Disabled',
                      style: GoogleFonts.nunito(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    value: _game.soundService.isEnabled,
                    activeColor: AppTheme.success,
                    onChanged: (value) {
                      setDialogState(() {
                        _game.setSoundsEnabled(value);
                        widget.prefs.setSoundEnabled(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Resume game if it wasn't paused before
                  if (!wasPaused) {
                    _game.togglePause();
                  }
                },
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
        },
      ),
    ).then((_) {
      // Ensure game resumes when dialog is dismissed by tapping outside
      if (!wasPaused && _game.sim.paused) {
        _game.togglePause();
      }
    });
  }

  void _showUpgradeConfirmation(TdTower tower) {
    final upgrade = tower.towerType.upgrade;
    if (upgrade == null) return;

    final upgradeCost = upgrade.cost;
    final cash = _game.sim.cash;

    // Calculate stat changes
    final oldRange = tower.range;
    final newRange = upgrade.range ?? oldRange;
    final rangeDiff = newRange - oldRange;

    final oldDpsMin = tower.damageMin;
    final newDpsMin = upgrade.damageMin ?? oldDpsMin;
    final dpsMinDiff = newDpsMin - oldDpsMin;

    final oldDpsMax = tower.damageMax;
    final newDpsMax = upgrade.damageMax ?? oldDpsMax;
    // dpsMaxDiff calculated but not displayed separately (we use min diff for color)

    final oldCooldownAvg = (tower.cooldownMin + tower.cooldownMax) / 120.0;
    final newCooldownMin = upgrade.cooldownMin ?? tower.cooldownMin;
    final newCooldownMax = upgrade.cooldownMax ?? tower.cooldownMax;
    final newCooldownAvg = (newCooldownMin + newCooldownMax) / 120.0;
    final cooldownDiff = oldCooldownAvg - newCooldownAvg; // Positive = faster

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              // Cost display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      color: AppTheme.mustard,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cost: \$$upgradeCost',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Stat changes header
              Text(
                'Stat Changes:',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // Range change
              StatChangeRow(
                icon: Icons.social_distance_rounded,
                label: 'Range',
                oldValue: '$oldRange tiles',
                newValue: '$newRange tiles',
                change: rangeDiff,
                isGoodIfHigher: true,
              ),
              // Damage change
              StatChangeRow(
                icon: Icons.bolt_rounded,
                label: 'Damage',
                oldValue:
                    '${oldDpsMin.toStringAsFixed(0)}-${oldDpsMax.toStringAsFixed(0)}',
                newValue:
                    '${newDpsMin.toStringAsFixed(0)}-${newDpsMax.toStringAsFixed(0)}',
                change: dpsMinDiff, // Use min diff for color
                isGoodIfHigher: true,
              ),
              // Cooldown change
              StatChangeRow(
                icon: Icons.timer_rounded,
                label: 'Cooldown',
                oldValue: '${oldCooldownAvg.toStringAsFixed(2)}s',
                newValue: '${newCooldownAvg.toStringAsFixed(2)}s',
                change: cooldownDiff, // Already inverted (positive = good)
                isGoodIfHigher:
                    false, // Lower is better, but we inverted the value
              ),
              // Cash remaining
              const SizedBox(height: 16),
              Container(
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
                      'Cash After: \$${cash - upgradeCost}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
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
              Navigator.pop(context); // Close dialog
              _game.upgradeTower(tower); // Execute upgrade with explicit tower
              HapticFeedback.mediumImpact();
              // Show success feedback
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Tower upgraded to ${upgrade.title}!',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
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
      ),
    );
  }

  void _showSellConfirmation(TdTower tower, int sellPrice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              _game.sellTowerDirect(tower);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Show quit confirmation dialog
        final shouldQuit = await _showQuitConfirmationDialog();
        if (shouldQuit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // Main game UI
            Column(
              children: [
                // Top Stats Bar - Fixed height, separate from game
                SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isNarrow = constraints.maxWidth < 400;
                        return ValueListenableBuilder<TdHudData>(
                          valueListenable: _game.hud,
                          builder: (context, hud, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Health with heal effect
                                Stack(
                                  children: [
                                    HudItem(
                                      icon: Icons.favorite_rounded,
                                      iconColor: hud.isBossWave
                                          ? const Color(0xFFFF00FF)
                                          : AppTheme.coral,
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
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00FF00),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: AppTheme.gridLine,
                                ),
                                // Cash
                                HudItem(
                                  icon: Icons.attach_money_rounded,
                                  iconColor: AppTheme.mustard,
                                  value: '\$${hud.cash}',
                                  label: 'Cash',
                                  showLabel: !isNarrow,
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: AppTheme.gridLine,
                                ),
                                // Wave
                                HudItem(
                                  icon: Icons.waves_rounded,
                                  iconColor: AppTheme.skyBlue,
                                  value: '${hud.wave}',
                                  label: 'Wave',
                                  showLabel: !isNarrow,
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: AppTheme.gridLine,
                                ),
                                // Tower Count
                                HudItem(
                                  icon: Icons.architecture_rounded,
                                  iconColor: hud.maxTowersReached
                                      ? AppTheme.error
                                      : AppTheme.mustard,
                                  value: '${hud.towerCount}/${hud.maxTowers}',
                                  label: 'Towers',
                                  showLabel: !isNarrow,
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: AppTheme.gridLine,
                                ),
                                // Pause Button (only show after game started)
                                if (hud.gameStarted)
                                  GestureDetector(
                                    onTap: () => _game.togglePause(),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: hud.paused
                                            ? AppTheme.warning.withValues(
                                                alpha: 0.2,
                                              )
                                            : AppTheme.success.withValues(
                                                alpha: 0.2,
                                              ),
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
                                // Settings Button (only show after game started)
                                if (hud.gameStarted) ...[
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: AppTheme.gridLine,
                                  ),
                                  GestureDetector(
                                    onTap: () => _showGameSettings(),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.settings_rounded,
                                        color: AppTheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                                // Countdown (show before game starts)
                                if (!hud.gameStarted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                    child: Text(
                                      'Starting in ${hud.countdownSeconds}s',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Game Area - Takes remaining space
                Expanded(
                  child: Stack(
                    children: [
                      // Game Canvas
                      GameWidget(game: _game),
                      // Overlay messages and placement UI inside game area
                      // "Tap to place" message (shows for 3 seconds when tower selected)
                      ValueListenableBuilder<int>(
                        valueListenable: _game.selectionRevision,
                        builder: (context, _, __) {
                          // Only show if tower type is selected but no tile position yet
                          if (!_game.hasSelectedTowerType ||
                              _game.pendingTowerCol != null) {
                            return const SizedBox.shrink();
                          }

                          // Check if we should show the message (3 second timeout)
                          if (!_showTapToPlace) {
                            return const SizedBox.shrink();
                          }

                          return Positioned(
                            left: 0,
                            right: 0,
                            bottom: 20,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Tap map to place ${_game.placingType?.title ?? 'tower'}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Tower Placement Panel (shows on the tile itself)
                      ValueListenableBuilder<TdHudData>(
                        valueListenable: _game.hud,
                        builder: (context, hud, _) {
                          if (!hud.isPlacingTower ||
                              hud.pendingTowerCol == null ||
                              hud.pendingTowerRow == null) {
                            return const SizedBox.shrink();
                          }

                          final placing = _game.placingType;
                          if (placing == null) return const SizedBox.shrink();

                          // Calculate tile position on screen
                          final map = _game.sim.baseMap;
                          final cols = map.cols;
                          final rows = map.rows;

                          // Use LayoutBuilder to get the game area size
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final gameWidth = constraints.maxWidth;
                              final gameHeight = constraints.maxHeight;
                              final tileW = gameWidth / cols;
                              final tileH = gameHeight / rows;
                              final tileSize = tileW < tileH ? tileW : tileH;

                              final originX = (gameWidth - cols * tileSize) / 2;
                              final originY =
                                  (gameHeight - rows * tileSize) / 2;

                              final tileLeft =
                                  originX + hud.pendingTowerCol! * tileSize;
                              final tileTop =
                                  originY + hud.pendingTowerRow! * tileSize;
                              final tileCenterX = tileLeft + tileSize / 2;

                              return Stack(
                                children: [
                                  // Buttons positioned above the tile
                                  Positioned(
                                    left: tileCenterX - 80,
                                    top: tileTop - 50,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Timeout display
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  hud.placementTimeoutSeconds <=
                                                      3
                                                  ? Colors.red.withValues(
                                                      alpha: 0.8,
                                                    )
                                                  : Colors.orange.withValues(
                                                      alpha: 0.8,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${hud.placementTimeoutSeconds}s',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Confirm button
                                          GestureDetector(
                                            onTap: () {
                                              _game.confirmPendingTower();
                                              HapticFeedback.mediumImpact();
                                              _updateTapToPlaceMessage(null);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.success,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Place',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Cancel button
                                          GestureDetector(
                                            onTap: () {
                                              _game.cancelPendingTower();
                                              _updateTapToPlaceMessage(null);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.error,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Cancel',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      // Selected Tower Stats (when tower is double-tapped)
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _game.selectionRevision,
                          builder: (context, _, __) {
                            final selected = _game.selectedTower;
                            final shouldShowModal = _game.shouldShowStatsModal;

                            if (selected == null || !shouldShowModal) {
                              return const SizedBox.shrink();
                            }

                            // Show modal when tower is double-tapped
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showTowerStatsModal(selected);
                              // Clear the modal flag after showing
                              _game.clearStatsModalFlag();
                            });

                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Tower Store Bar - Fixed height, separate from game
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
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
                          child: ValueListenableBuilder<TdHudData>(
                            valueListenable: _game.hud,
                            builder: (context, hud, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: _game.selectionRevision,
                                builder: (context, _, __) {
                                  final placing = _game.placingType;
                                  final selected = _game.selectedTower;

                                  return ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    itemCount: towerTypes.length,
                                    itemBuilder: (context, index) {
                                      final key = towerTypes.keys.elementAt(
                                        index,
                                      );
                                      final t = towerTypes[key]!;
                                      final isActive =
                                          placing?.key == t.key ||
                                          selected?.towerType.key == t.key;
                                      final canAfford = hud.cash >= t.cost;
                                      final maxedOut = hud.maxTowersReached;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: TowerStoreItem(
                                          towerType: t,
                                          isActive: isActive,
                                          isDisabled: !canAfford || maxedOut,
                                          onTap: () {
                                            if (maxedOut) {
                                              // Show max towers message
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Max towers reached (${hud.towerCount}/${hud.maxTowers}). Upgrade or sell existing towers.',
                                                    style: GoogleFonts.nunito(),
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.error,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            // Toggle: If same tower is already selected, deselect it
                                            if (placing?.key == t.key) {
                                              _game.cancelPendingTower();
                                            } else {
                                              _game.startPlacingTower(t);
                                              _updateTapToPlaceMessage(t);
                                            }
                                          },
                                        ),
                                      );
                                    },
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
              ],
            ),
            // Tutorial overlay (shown on first launch)
            if (_showTutorial)
              TutorialOverlay(
                prefs: widget.prefs,
                onComplete: () {
                  setState(() {
                    _showTutorial = false;
                  });
                  // Resume the game countdown after tutorial completes
                  _game.pauseCountdown(false);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showQuitConfirmationDialog() async {
    // Pause the game and countdown timer while showing dialog
    final sim = _game.sim;
    final wasRunning = !sim.paused;
    if (wasRunning) {
      sim.togglePause();
    }

    // Pause the countdown timer (for game start countdown)
    _game.pauseCountdown(true);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              // Stop all sounds
              _game.soundService.stopAll();
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
      ),
    );

    // Resume game and countdown if user chose to continue
    if (result == false) {
      _game.pauseCountdown(false);
      if (wasRunning) {
        sim.togglePause();
      }
    }

    return result;
  }
}
