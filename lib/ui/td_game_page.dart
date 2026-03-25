import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/td_game.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_leaderboard_page.dart';
import 'tutorial_overlay.dart';
import 'widgets/game_hud_widgets.dart';
import 'widgets/tower_stats_modal.dart';
import 'dialogs/upgrade_dialog.dart';
import 'dialogs/sell_dialog.dart';
import 'dialogs/settings_dialog.dart';
import '../game/entities/tower.dart';
import 'dialogs/quit_dialog.dart';

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

      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

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
      });
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
                Navigator.pop(context);
                _showUpgradeConfirmation(tower);
              }
            : null,
        onSell: () {
          Navigator.pop(context);
          _showSellConfirmation(tower, sellPrice);
        },
        canAffordUpgrade: canAffordUpgrade,
      ),
    );
  }

  void _showGameSettings() {
    final wasPaused = _game.sim.paused;
    showGameSettings(
      context: context,
      soundEnabled: _game.soundService.isEnabled,
      onSoundChanged: (value) {
        _game.setSoundsEnabled(value);
        widget.prefs.setSoundEnabled(value);
      },
      onPause: _game.togglePause,
      onResume: _game.togglePause,
      wasPaused: wasPaused,
    );
  }

  void _showUpgradeConfirmation(TdTower tower) {
    if (tower.towerType.upgrade == null) return;
    showUpgradeConfirmation(
      context: context,
      tower: tower,
      currentCash: _game.sim.cash,
      onConfirm: () => _game.upgradeTower(tower),
    );
  }

  void _showSellConfirmation(TdTower tower, int sellPrice) {
    showSellConfirmation(
      context: context,
      tower: tower,
      sellPrice: sellPrice,
      onConfirm: () => _game.sellTowerDirect(tower),
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
                      // Game Canvas - RepaintBoundary isolates game rendering from UI rebuilds
                      RepaintBoundary(child: GameWidget(game: _game)),
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

                              // Smart button positioning to keep them on-screen
                              const buttonWidth =
                                  160.0; // Approximate width of button container
                              const buttonHeight = 40.0; // Approximate height
                              const padding =
                                  8.0; // Minimum padding from screen edges

                              // Calculate default position (centered above tile)
                              double buttonLeft =
                                  tileCenterX - (buttonWidth / 2);
                              double buttonTop = tileTop - buttonHeight - 10;

                              // Adjust horizontal position if off-screen
                              if (buttonLeft < padding) {
                                // Too far left - align to left edge with padding
                                buttonLeft = padding;
                              } else if (buttonLeft + buttonWidth >
                                  gameWidth - padding) {
                                // Too far right - align to right edge with padding
                                buttonLeft = gameWidth - buttonWidth - padding;
                              }

                              // Adjust vertical position if off-screen
                              if (buttonTop < padding) {
                                // Too close to top - place below tile instead
                                buttonTop = tileTop + tileSize + 10;
                              }

                              // If still off-screen at bottom, place at bottom with padding
                              if (buttonTop + buttonHeight >
                                  gameHeight - padding) {
                                buttonTop = gameHeight - buttonHeight - padding;
                              }

                              return Stack(
                                children: [
                                  // Buttons with smart positioning
                                  Positioned(
                                    left: buttonLeft,
                                    top: buttonTop,
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
                          child: ValueListenableBuilder<int>(
                            valueListenable: _game.selectionRevision,
                            builder: (context, _, __) {
                              final placing = _game.placingType;
                              final selected = _game.selectedTower;
                              // Read HUD once per rebuild instead of nested listener
                              final hud = _game.hud.value;

                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                itemCount: towerTypes.length,
                                itemBuilder: (context, index) {
                                  final key = towerTypes.keys.elementAt(index);
                                  final t = towerTypes[key]!;
                                  final isActive =
                                      placing?.key == t.key ||
                                      selected?.towerType.key == t.key;
                                  final canAfford = hud.cash >= t.cost;
                                  final maxedOut = hud.maxTowersReached;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
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
                                              backgroundColor: AppTheme.error,
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
    final sim = _game.sim;
    final wasPaused = sim.paused;
    return showQuitConfirmation(
      context: context,
      wasPaused: wasPaused,
      pauseSim: sim.togglePause,
      resumeSim: sim.togglePause,
      pauseCountdown: () => _game.pauseCountdown(true),
      resumeCountdown: () => _game.pauseCountdown(false),
      stopAllSounds: () => _game.soundService.stopAll(),
    );
  }
}
