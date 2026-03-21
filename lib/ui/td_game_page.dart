import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/td_game.dart';
import '../game/td_simulation.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_leaderboard_page.dart';
import 'tutorial_overlay.dart';

class TdGamePage extends StatefulWidget {
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
  State<TdGamePage> createState() => _TdGamePageState();
}

class _TdGamePageState extends State<TdGamePage> {
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
    );

    // Initialize sound and particles from prefs
    _initEffectsFromPrefs();

    // Check if we should show tutorial - this will pause the game
    _checkAndShowTutorial();

    // Set up callback for placement failure feedback
    _game.onPlacementFailed = (reason) {
      if (!mounted) return;
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
      builder: (context) => _TowerStatsSheet(
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
                  color: AppTheme.error.withOpacity(0.1),
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
              _StatChangeRow(
                icon: Icons.social_distance_rounded,
                label: 'Range',
                oldValue: '$oldRange tiles',
                newValue: '$newRange tiles',
                change: rangeDiff,
                isGoodIfHigher: true,
              ),
              // Damage change
              _StatChangeRow(
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
              _StatChangeRow(
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
                  color: AppTheme.success.withOpacity(0.1),
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
    return Scaffold(
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
                    color: AppTheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ValueListenableBuilder<TdHudData>(
                    valueListenable: _game.hud,
                    builder: (context, hud, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Health with heal effect
                          Stack(
                            children: [
                              _HudItem(
                                icon: Icons.favorite_rounded,
                                iconColor: hud.isBossWave
                                    ? const Color(0xFFFF00FF)
                                    : AppTheme.coral,
                                value: '${hud.health}/${hud.maxHealth}',
                                label: 'Health',
                              ),
                              if (hud.healEffectTicks > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: AnimatedOpacity(
                                    opacity: hud.healEffectTicks / 60.0,
                                    duration: const Duration(milliseconds: 100),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00FF00),
                                        borderRadius: BorderRadius.circular(4),
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
                          _HudItem(
                            icon: Icons.attach_money_rounded,
                            iconColor: AppTheme.mustard,
                            value: '\$${hud.cash}',
                            label: 'Cash',
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 30,
                            color: AppTheme.gridLine,
                          ),
                          // Wave
                          _HudItem(
                            icon: Icons.waves_rounded,
                            iconColor: AppTheme.skyBlue,
                            value: '${hud.wave}',
                            label: 'Wave',
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 30,
                            color: AppTheme.gridLine,
                          ),
                          // Tower Count
                          _HudItem(
                            icon: Icons.architecture_rounded,
                            iconColor: hud.maxTowersReached
                                ? AppTheme.error
                                : AppTheme.mustard,
                            value: '${hud.towerCount}/${hud.maxTowers}',
                            label: 'Towers',
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
                                      ? AppTheme.warning.withOpacity(0.2)
                                      : AppTheme.success.withOpacity(0.2),
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
                          // Countdown (show before game starts)
                          if (!hud.gameStarted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.2),
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
                                color: Colors.black.withOpacity(0.8),
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
                            final originY = (gameHeight - rows * tileSize) / 2;

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
                                      color: Colors.black.withOpacity(0.8),
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
                                                hud.placementTimeoutSeconds <= 3
                                                ? Colors.red.withOpacity(0.8)
                                                : Colors.orange.withOpacity(
                                                    0.8,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                            _updateTapToPlaceMessage(null);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
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
                                            padding: const EdgeInsets.symmetric(
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
                    // Selected Tower Stats (when tower is selected)
                    Positioned.fill(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _game.selectionRevision,
                        builder: (context, _, __) {
                          final selected = _game.selectedTower;
                          if (selected == null) return const SizedBox.shrink();

                          // Show modal when tower is selected
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _showTowerStatsModal(selected);
                            // Clear selection immediately after showing modal
                            _game.selectTower(null);
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
                    color: AppTheme.surface.withOpacity(0.95),
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
                                      padding: const EdgeInsets.only(right: 10),
                                      child: _TowerStoreItem(
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
                                          _game.startPlacingTower(t);
                                          _updateTapToPlaceMessage(t);
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
    );
  }
}

// Widget to display stat changes with visual indicators
class _StatChangeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String oldValue;
  final String newValue;
  final num change;
  final bool isGoodIfHigher; // true if higher value is better (range, damage)
  // false if lower value is better (cooldown)

  const _StatChangeRow({
    required this.icon,
    required this.label,
    required this.oldValue,
    required this.newValue,
    required this.change,
    required this.isGoodIfHigher,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if the change is positive or negative
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
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: changeColor),
          ),
          const SizedBox(width: 12),
          // Label
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
          // Old value
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
          // Arrow
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          // New value with change indicator
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

class _HudItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _HudItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
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
    );
  }
}

class _TowerStoreItem extends StatelessWidget {
  final TdTowerType towerType;
  final bool isActive;
  final bool isDisabled;
  final VoidCallback onTap;

  const _TowerStoreItem({
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
                ? towerColor.withOpacity(0.15)
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: isActive ? Border.all(color: towerColor, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tower Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: towerColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: towerColor.withOpacity(0.4),
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
              // Tower Name
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
              // Cost Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mustard.withOpacity(0.2),
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

class _TowerStatsSheet extends StatelessWidget {
  final TdTower tower;
  final VoidCallback? onUpgrade;
  final VoidCallback onSell;
  final bool canAffordUpgrade;

  const _TowerStatsSheet({
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

    // Determine display title - show upgrade name if upgraded
    String displayTitle = st.title;
    String? appliedUpgradeName;
    if (tower.upgraded && st.upgrade != null) {
      // Use the stored upgrade name if available, otherwise fallback to upgrade title
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
          // Handle bar
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
          // Header
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
                          color: AppTheme.success.withOpacity(0.2),
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
          // Stats
          _StatRow(
            icon: Icons.social_distance_rounded,
            label: 'Range',
            value: '${tower.range} tiles',
            progress: tower.range / 10, // Normalize to 0-1
            color: AppTheme.skyBlue,
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.bolt_rounded,
            label: 'Damage',
            value:
                '${tower.damageMin.toStringAsFixed(0)}-${tower.damageMax.toStringAsFixed(0)}',
            progress: tower.damageMax / 100,
            color: AppTheme.coral,
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.timer_rounded,
            label: 'Cooldown',
            value: '${cooldownAvg.toStringAsFixed(2)}s',
            progress: 1 - (cooldownAvg / 2).clamp(0, 1), // Lower is better
            color: AppTheme.secondary,
          ),
          const SizedBox(height: 24),
          // Action Buttons
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
                // Show "Max Level" badge instead of upgrade button
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
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

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _StatRow({
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
            color: color.withOpacity(0.15),
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
