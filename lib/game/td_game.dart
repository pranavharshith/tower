import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../data/td_maps.dart';
import '../data/td_random_maps.dart';
import '../services/sound_service.dart';
import 'td_simulation.dart';
import 'particle_system.dart';

class TdGameSettings {
  final bool stretchMode;
  const TdGameSettings({this.stretchMode = true});
}

class TdHudData {
  final int wave;
  final int health;
  final int maxHealth;
  final int cash;
  final bool paused;
  final int healAmount;
  final int healEffectTicks;
  final bool isBossWave;
  final bool gameStarted;
  final int countdownSeconds;
  final bool isPlacingTower;
  final int? pendingTowerCol;
  final int? pendingTowerRow;
  final TdTowerType? pendingTowerType;
  final int placementTimeoutSeconds;
  final int towerCount;
  final int maxTowers;
  final bool maxTowersReached;
  const TdHudData({
    required this.wave,
    required this.health,
    required this.maxHealth,
    required this.cash,
    required this.paused,
    this.healAmount = 0,
    this.healEffectTicks = 0,
    this.isBossWave = false,
    this.gameStarted = false,
    this.countdownSeconds = 10,
    this.isPlacingTower = false,
    this.pendingTowerCol,
    this.pendingTowerRow,
    this.pendingTowerType,
    this.placementTimeoutSeconds = 7,
    this.towerCount = 0,
    this.maxTowers = 21,
    this.maxTowersReached = false,
  });
}

class TdGame extends FlameGame with TapCallbacks {
  final String mapKey;
  final TdGameSettings settings;
  final void Function(int bestWave) onGameOver;

  // Callback for when tower placement fails (for UI feedback)
  void Function(String reason)? onPlacementFailed;

  // UI <-> game selection state
  TdTowerType? placingType;
  TdTower? selectedTower;

  // Pending tower placement (drag to place, then confirm)
  TdTowerType? _pendingTowerType;
  int? _pendingTowerCol;
  int? _pendingTowerRow;
  double _placementTimeout = 0; // 7 seconds to confirm
  static const double _placementTimeoutMax = 7.0;

  // Game start countdown
  bool _gameStarted = false;
  int _countdownSeconds = 10;
  double _countdownAccum = 0;
  bool _countdownPaused = false; // Pause countdown for tutorial

  // Expose HUD for overlay widgets.
  final ValueNotifier<TdHudData> hud = ValueNotifier<TdHudData>(
    const TdHudData(
      wave: 0,
      health: 40,
      maxHealth: 40,
      cash: 0,
      paused: true,
      healAmount: 0,
      healEffectTicks: 0,
      isBossWave: false,
    ),
  );

  /// Used by Flutter UI overlays to re-render when selection changes.
  final ValueNotifier<int> selectionRevision = ValueNotifier<int>(0);

  TdSim? _sim;

  // Sound and particle effects
  final SoundService _soundService = SoundService();
  final ParticleSystem _particleSystem = ParticleSystem();
  bool _particlesEnabled = true;

  final Random _rng = Random();
  late final TdMaps _tdMaps;
  late final TdRandomMapGenerator _randomMapGenerator;

  bool _gameOver = false;
  int _bestWave = 0;

  // Getters for pending tower
  TdTowerType? get pendingTowerType => _pendingTowerType;
  int? get pendingTowerCol => _pendingTowerCol;
  int? get pendingTowerRow => _pendingTowerRow;
  // Only pause game when a tile position is selected (not just tower type)
  bool get isPlacingTower =>
      _pendingTowerCol != null && _pendingTowerRow != null;
  bool get hasSelectedTowerType => placingType != null;
  bool get gameStarted => _gameStarted;
  int get countdownSeconds => _countdownSeconds;
  int get placementTimeoutSeconds => _placementTimeout.ceil();

  TdGame({
    required this.mapKey,
    required this.settings,
    required this.onGameOver,
  }) : super();

  TdSim get sim => _sim!;

  // Sound and particle system accessors
  SoundService get soundService => _soundService;
  ParticleSystem get particleSystem => _particleSystem;
  bool get particlesEnabled => _particlesEnabled;

  void setParticlesEnabled(bool enabled, {bool fromPrefs = false}) {
    _particlesEnabled = enabled;
    _particleSystem.setEnabled(enabled);
    if (!fromPrefs) {
      // If not from prefs, also update the service
      _soundService.setEnabled(enabled);
    }
  }

  void setSoundsEnabled(bool enabled, {bool fromPrefs = false}) {
    _soundService.setEnabled(enabled);
    if (!fromPrefs) {
      // If not from prefs, also update particles
      _particlesEnabled = enabled;
      _particleSystem.setEnabled(enabled);
    }
  }

  /// Pause or resume the game start countdown (used for tutorial overlay)
  void pauseCountdown(bool pause) {
    _countdownPaused = pause;
  }

  bool get isCountdownPaused => _countdownPaused;

  void setPaused(bool value) {
    final s = _sim;
    if (s == null) return;
    s.paused = value;
  }

  void togglePause() {
    final s = _sim;
    if (s == null) return;
    s.togglePause();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _tdMaps = const TdMaps();
    _randomMapGenerator = TdRandomMapGenerator(_rng);

    // Initialize sound service
    await _soundService.initialize();

    await _loadMapAndInitSim();
  }

  Future<void> _loadMapAndInitSim() async {
    // Determine a "tile count" for random maps based on screen size, like JS `resizeMax()`.
    final colsEstimate = (size.x / 24).floor().clamp(10, 80);
    final rowsEstimate = (size.y / 24).floor().clamp(10, 80);

    TdMapData mapData;
    int cash;
    if (_tdMaps.isPremadeKey(mapKey)) {
      mapData = _tdMaps.loadPremade(mapKey);
      cash = 55;
    } else {
      final gen = _randomMapGenerator.generate(
        key: mapKey,
        cols: colsEstimate,
        rows: rowsEstimate,
      );
      mapData = gen.map;
      cash = gen.cash;
    }

    _sim = TdSim(baseMap: mapData, rng: _rng, cash: cash);
    _sim!.startGame();

    _bestWave = 0;
    _gameOver = false;
    hud.value = TdHudData(
      wave: _sim!.wave,
      health: _sim!.health,
      maxHealth: _sim!.maxHealth,
      cash: _sim!.cash,
      paused: _sim!.paused,
      healAmount: _sim!.healAmount,
      healEffectTicks: _sim!.healEffectTicks,
      isBossWave: _sim!.isBossWave,
      towerCount: _sim!.towers.length,
      maxTowers: TdSim.maxTowers,
      maxTowersReached: _sim!.maxTowersReached,
    );
  }

  void setPlacingType(TdTowerType? type) {
    placingType = type;
    if (type != null) {
      // Selecting store items cancels tower selection.
      selectedTower = null;
    }
    selectionRevision.value++;
  }

  void selectTower(TdTower? tower) {
    selectedTower = tower;
    placingType = null;
    selectionRevision.value++;
  }

  void upgradeSelected() {
    if (selectedTower == null) return;

    // Check if tower can be upgraded
    if (!selectedTower!.canUpgrade) return;

    // Check if player has enough cash
    final upgradeCost = selectedTower!.towerType.upgrade?.cost ?? 0;
    if (_sim!.cash >= upgradeCost) {
      // Deduct cash and upgrade
      _sim!.cash -= upgradeCost;
      sim.upgradeTower(selectedTower!);
      // Don't clear selection - keep it so user can see upgraded stats
      // Just increment revision to trigger UI refresh
      selectionRevision.value++;
    }
    // If not enough cash, do nothing (button should be disabled in UI)
  }

  void sellSelected() {
    if (selectedTower == null) return;
    sim.sellTower(selectedTower!);
    selectedTower = null;
    selectionRevision.value++;
  }

  void sellTowerDirect(TdTower tower) {
    sim.sellTower(tower);
    if (selectedTower == tower) {
      selectedTower = null;
    }
    selectionRevision.value++;
  }

  // Set pending tower position (called when user taps on grid)
  // Returns true if position was set, false if placement not allowed
  bool setPendingTowerPosition(int col, int row) {
    if (_pendingTowerType == null) return false;

    // Check tower limit
    if (_sim!.towers.length >= TdSim.maxTowers) {
      onPlacementFailed?.call('Max towers reached');
      return false;
    }

    // Check if enemy is on this tile
    for (final e in _sim!.enemies) {
      if (e.gridCol == col && e.gridRow == row) {
        onPlacementFailed?.call('Enemy on this tile');
        return false;
      }
    }

    // Check grid value
    final g = _sim!.grid[col][row];
    if (g == 1 || g == 2 || g == 4) {
      onPlacementFailed?.call('Cannot place on obstacle');
      return false;
    }

    // Check if tile is empty
    if (_sim!.hasTowerAt(col, row)) {
      onPlacementFailed?.call('Tower already here');
      return false;
    }

    // Check if path remains valid
    if (!_sim!.placeable(col, row)) {
      onPlacementFailed?.call('Would block enemy path');
      return false;
    }

    // All checks passed, set position
    _pendingTowerCol = col;
    _pendingTowerRow = row;
    _placementTimeout = _placementTimeoutMax; // Start 7 second timeout
    selectionRevision.value++;
    return true;
  }

  // Confirm tower placement
  void confirmPendingTower() {
    if (_pendingTowerType == null ||
        _pendingTowerCol == null ||
        _pendingTowerRow == null) {
      return;
    }
    _sim!.placeTower(_pendingTowerType!, _pendingTowerCol!, _pendingTowerRow!);
    _pendingTowerType = null;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = null;
    selectionRevision.value++;
  }

  // Cancel tower placement
  void cancelPendingTower() {
    _pendingTowerType = null;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = null;
    selectionRevision.value++;
  }

  // Start placing a tower type
  void startPlacingTower(TdTowerType type) {
    _pendingTowerType = type;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = type;
    selectedTower = null;
    selectionRevision.value++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    final sim = _sim;
    if (sim == null) return;

    // Update particle system
    if (_particlesEnabled) {
      _particleSystem.update(dt);
    }

    // Handle placement timeout countdown
    if (_pendingTowerCol != null && _placementTimeout > 0) {
      _placementTimeout -= dt;
      if (_placementTimeout <= 0) {
        // Auto-cancel placement after timeout
        cancelPendingTower();
      }
    }

    // Handle countdown before game starts (paused while placing tower)
    if (!_gameStarted) {
      // Only countdown if not placing a tower and not paused for tutorial
      if (!isPlacingTower && !_countdownPaused) {
        _countdownAccum += dt;
        if (_countdownAccum >= 1.0) {
          _countdownAccum -= 1.0;
          _countdownSeconds--;
          if (_countdownSeconds <= 0) {
            _gameStarted = true;
            sim.paused = false;
          }
        }
      }
      // Update HUD during countdown
      hud.value = TdHudData(
        wave: sim.wave,
        health: sim.health,
        maxHealth: sim.maxHealth,
        cash: sim.cash,
        paused: sim.paused,
        healAmount: sim.healAmount,
        healEffectTicks: sim.healEffectTicks,
        isBossWave: sim.isBossWave,
        gameStarted: _gameStarted,
        countdownSeconds: _countdownSeconds,
        isPlacingTower: isPlacingTower,
        pendingTowerCol: _pendingTowerCol,
        pendingTowerRow: _pendingTowerRow,
        pendingTowerType: _pendingTowerType,
        placementTimeoutSeconds: _placementTimeout.ceil(),
        towerCount: sim.towers.length,
        maxTowers: TdSim.maxTowers,
        maxTowersReached: sim.maxTowersReached,
      );
      return;
    }

    // Run fixed-step simulation at 60Hz (decoupled from rendering)
    // This saves battery while maintaining smooth visuals through interpolation
    if (!isPlacingTower) {
      _accum += dt;
      // Use 60Hz (1/60) instead of 120Hz (1/120) for better battery life
      const simTickRate = 1.0 / 60.0;
      while (_accum >= simTickRate) {
        _accum -= simTickRate;
        sim.step();

        if (!sim.paused) {
          _bestWave = max(_bestWave, sim.wave);
        }

        if (sim.health <= 0 && !_gameOver) {
          _gameOver = true;
          onGameOver(_bestWave);
          break;
        }
      }
    }

    hud.value = TdHudData(
      wave: sim.wave,
      health: sim.health,
      maxHealth: sim.maxHealth,
      cash: sim.cash,
      paused: sim.paused,
      healAmount: sim.healAmount,
      healEffectTicks: sim.healEffectTicks,
      isBossWave: sim.isBossWave,
      gameStarted: _gameStarted,
      countdownSeconds: _countdownSeconds,
      isPlacingTower: isPlacingTower,
      pendingTowerCol: _pendingTowerCol,
      pendingTowerRow: _pendingTowerRow,
      pendingTowerType: _pendingTowerType,
      placementTimeoutSeconds: _placementTimeout.ceil(),
      towerCount: sim.towers.length,
      maxTowers: TdSim.maxTowers,
      maxTowersReached: sim.maxTowersReached,
    );
  }

  double _accum = 0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_sim == null) return;

    final map = _sim!.baseMap;
    final cols = map.cols;
    final rows = map.rows;

    // Tile colors - updated to softer, more aesthetic palette
    // We draw basic colored rectangles + grid lines; advanced shapes (corner
    // geometry) are approximated by using the same road color.
    // New softer colors
    const road = Color(0xFFE8DCC4); // Soft beige/light brown for path
    const grass = Color(0xFFB8E0D2); // Muted mint green
    const towerTile = Color(0xFF7FD8BE); // Mint
    const sidewalk = Color(0xFFD4D4E0); // Light gray
    // Map theme colors - softer variants
    const c0LightBrown = Color(0xFFE8DCC4);
    const c0LightPurple = Color(0xFFC5B8E0);
    const c0MediumPurple = Color(0xFF9D8EC4);
    const c0DarkPurple = Color(0xFF7A6BA3);
    const c0PaleGreen = Color(0xFFD4F1E0);
    const c1DarkBlue = Color(0xFF4A5B8C);
    const c1MediumBlue = Color(0xFF6B7FD7);
    const c1LightBlue = Color(0xFF9BB5F0);
    const c1DarkPurple = Color(0xFF7A6BA3);
    const c1NeonPink = Color(0xFFFF8B9A);
    const c2DarkRed = Color(0xFFC45B5B);
    const c2NavyBlue = Color(0xFF4A5B8C);
    const c2DarkBlue = Color(0xFF5B6BA3);
    const c2PaleYellow = Color(0xFFFFF4D4);
    const c2LightYellow = Color(0xFFFFE8B8);

    Color tileColor(dynamic display, int gridValue) {
      // Grid value 1 = wall (obstacle) - grey color
      if (gridValue == 1) {
        return const Color(0xFF555555); // Grey for obstacles
      }
      // Grid value 0 = empty/walkable - transparent/no color
      if (gridValue == 0) {
        return const Color(0x00000000); // Transparent for empty tiles
      }
      if (display == null) return const Color(0x00000000);
      final s = display as String;
      switch (s) {
        case 'empty':
          return const Color(0x00000000); // Transparent
        case 'grass':
          return grass;
        case 'wall':
          return const Color(0xFF555555); // Grey for walls
        case 'tower':
          return towerTile;
        case 'sidewalk':
          return sidewalk;
        case 'road':
          return road;
        case 'lCorner':
        case 'rCorner':
          return road;
        case 'c0_lightBrown':
          return c0LightBrown;
        case 'c0_lightPurple':
          return c0LightPurple;
        case 'c0_mediumPurple':
          return c0MediumPurple;
        case 'c0_darkPurple':
          return c0DarkPurple;
        case 'c0_paleGreen':
          return c0PaleGreen;
        case 'c1_darkBlue':
          return c1DarkBlue;
        case 'c1_mediumBlue':
          return c1MediumBlue;
        case 'c1_lightBlue':
          return c1LightBlue;
        case 'c1_darkPurple':
          return c1DarkPurple;
        case 'c1_neonPink':
          return c1NeonPink;
        case 'c2_darkRed':
          return c2DarkRed;
        case 'c2_navyBlue':
          return c2NavyBlue;
        case 'c2_darkBlue':
          return c2DarkBlue;
        case 'c2_paleYellow':
          return c2PaleYellow;
        case 'c2_lightYellow':
          return c2LightYellow;
        default:
          return const Color(0x00000000); // Transparent by default
      }
    }

    // Compute pixel mapping for tile units.
    late final double tileW;
    late final double tileH;
    late final double originX;
    late final double originY;
    if (settings.stretchMode) {
      tileW = size.x / cols;
      tileH = size.y / rows;
      originX = 0.0;
      originY = 0.0;
    } else {
      final t = min(size.x / cols, size.y / rows);
      tileW = t;
      tileH = t;
      originX = (size.x - cols * t) / 2;
      originY = (size.y - rows * t) / 2;
    }
    final tileSizeForRadius = min(tileW, tileH);

    // Background based on map bg.
    final bg = Color.fromARGB(255, map.bg[0], map.bg[1], map.bg[2]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = bg);

    // Tile grid fill using `display` keys.
    final tilePaint = Paint()..style = PaintingStyle.fill;
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final d = map.display[c][r];
        final gridValue = map.grid[c][r];
        tilePaint.color = tileColor(d, gridValue);
        final rect = Rect.fromLTWH(
          originX + c * tileW,
          originY + r * tileH,
          tileW,
          tileH,
        );
        canvas.drawRect(rect, tilePaint);
      }
    }

    // Grid lines (every tile) - green on dark background like towerdefense.
    final gridPaint = Paint()
      ..color = const Color(0xFF00E640)
          .withOpacity(0.3) // Green grid lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int c = 0; c <= cols; c++) {
      final x = originX + c * tileW;
      canvas.drawLine(
        Offset(x, originY),
        Offset(x, originY + rows * tileH),
        gridPaint,
      );
    }
    for (int r = 0; r <= rows; r++) {
      final y = originY + r * tileH;
      canvas.drawLine(
        Offset(originX, y),
        Offset(originX + cols * tileW, y),
        gridPaint,
      );
    }

    // Exit - soft coral color
    final exitPaint = Paint()..color = const Color(0xFFFF8B7B); // Soft coral
    canvas.drawRect(
      Rect.fromLTWH(
        originX + map.exit.x * tileW,
        originY + map.exit.y * tileH,
        tileW,
        tileH,
      ),
      exitPaint,
    );

    // Pink spawn towers (current positions) - pink color
    final spawnPaint = Paint()..color = const Color(0xFFFF69B4); // Hot pink
    for (final st in _sim!.spawnTowers) {
      canvas.drawRect(
        Rect.fromLTWH(
          originX + st.col * tileW,
          originY + st.row * tileH,
          tileW,
          tileH,
        ),
        spawnPaint,
      );
    }

    // Temporary spawnpoints.
    for (final ts in _sim!.tempSpawns) {
      final p = ts.pos;
      canvas.drawRect(
        Rect.fromLTWH(
          originX + p.x * tileW,
          originY + p.y * tileH,
          tileW,
          tileH,
        ),
        Paint()..color = const Color(0xFF9D4EDD), // Soft purple
      );
    }

    // Tower range visualization when placing or selected
    if (placingType != null) {
      // Show range at mouse position (using last tap position approximation)
      // This is handled in onTapDown, storing the hover position would need
      // a different approach - for now, show range on selected/placing state
    }

    // Towers
    for (final t in _sim!.towers) {
      final cx = originX + t.posX * tileW;
      final cy = originY + t.posY * tileH;
      // Scale down to fit within grid cell (towerdefense uses ~0.3-0.4 visual radius)
      final r = min(tileW, tileH) * 0.35;

      // Draw range circle if selected or placing
      if (t == selectedTower || placingType?.key == t.towerType.key) {
        // Range in pixels = range in tiles * tile size
        final rangeRadius = t.range * tileSizeForRadius;
        canvas.drawCircle(
          Offset(cx, cy),
          rangeRadius,
          Paint()
            ..color = Color.fromARGB(63, t.color[0], t.color[1], t.color[2])
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          rangeRadius,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      // Draw tower with barrel/base like towerdefense
      _drawTower(canvas, t, cx, cy, r, tileSizeForRadius);

      // If selected tower, show a slightly larger outline.
      if (t == selectedTower) {
        canvas.drawCircle(
          Offset(cx, cy),
          r * 1.15,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFFFFFF),
        );
      }
    }

    // Pink spawn points (enemy spawn locations)
    for (final et in _sim!.spawnTowers) {
      final left = originX + et.col * tileW;
      final top = originY + et.row * tileH;
      final color = et.isBossTower
          ? const Color(0xFFFF0040) // Bright red for boss spawn point
          : const Color(0xFFFF69B4); // Hot pink for normal spawn point

      // Draw square spawn point (same shape as player's green base)
      canvas.drawRect(
        Rect.fromLTWH(left, top, tileW, tileH),
        Paint()..color = color,
      );

      // Draw outline
      canvas.drawRect(
        Rect.fromLTWH(left, top, tileW, tileH),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Enemies
    for (final e in _sim!.enemies) {
      final cx = originX + e.posX * tileW;
      final cy = originY + e.posY * tileH;
      final r = e.type.radiusTiles * tileSizeForRadius * 0.5;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          e.type.color[0],
          e.type.color[1],
          e.type.color[2],
        );

      // Draw enemy shape based on type (matching towerdefense)
      _drawEnemy(canvas, e, cx, cy, r, paint);

      // Draw HP bar(s) above enemy
      if (e.type.key == 'boss') {
        // Boss has 3 HP bars (main + 2 extra)
        _drawBossHealthBars(canvas, e, cx, cy, r, tileSizeForRadius);
      } else {
        _drawHealthBar(canvas, e, cx, cy, r, tileSizeForRadius);
      }
    }

    // Missiles
    for (final m in _sim!.missiles) {
      final cx = originX + m.posX * tileW;
      final cy = originY + m.posY * tileH;
      canvas.drawCircle(
        Offset(cx, cy),
        max(2, tileSizeForRadius * 0.08),
        Paint()..color = const Color(0xFFFF8B7B), // Soft coral
      );
    }

    // Highlight pending tower tile
    if (_pendingTowerCol != null &&
        _pendingTowerRow != null &&
        _pendingTowerType != null) {
      final tileLeft = originX + _pendingTowerCol! * tileW;
      final tileTop = originY + _pendingTowerRow! * tileH;
      final tileCenterX = tileLeft + tileW / 2;
      final tileCenterY = tileTop + tileH / 2;

      // Draw highlighted tile background
      canvas.drawRect(
        Rect.fromLTWH(tileLeft, tileTop, tileW, tileH),
        Paint()
          ..color = _pendingTowerType!.color.isNotEmpty
              ? Color.fromARGB(
                  100,
                  _pendingTowerType!.color[0],
                  _pendingTowerType!.color[1],
                  _pendingTowerType!.color[2],
                )
              : const Color(0x64FFD700)
          ..style = PaintingStyle.fill,
      );

      // Draw pulsing border
      final pulseAlpha =
          (128 +
                  127 *
                      (0.5 +
                          0.5 *
                              (DateTime.now().millisecondsSinceEpoch % 1000) /
                              1000))
              .toInt();
      canvas.drawRect(
        Rect.fromLTWH(tileLeft, tileTop, tileW, tileH),
        Paint()
          ..color = Color.fromARGB(pulseAlpha, 255, 255, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      // Draw range preview
      final rangeRadius = _pendingTowerType!.range * tileSizeForRadius;
      canvas.drawCircle(
        Offset(tileCenterX, tileCenterY),
        rangeRadius,
        Paint()
          ..color = Color.fromARGB(
            40,
            _pendingTowerType!.color[0],
            _pendingTowerType!.color[1],
            _pendingTowerType!.color[2],
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(tileCenterX, tileCenterY),
        rangeRadius,
        Paint()
          ..color = const Color(0x80FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Render particle effects (on top of everything)
    if (_particlesEnabled) {
      _particleSystem.render(canvas);
    }
  }

  void _drawEnemy(
    Canvas canvas,
    TdEnemy e,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    // Draw different shapes based on enemy type (matching towerdefense)
    switch (e.type.key) {
      case 'fast':
      case 'strongFast':
      case 'faster':
        // Arrow shape - rotated based on velocity
        final angle = atan2(e.velY, e.velX);
        _drawArrowEnemy(canvas, cx, cy, r, angle, paint);
        break;
      case 'tank':
        // Tank shape - rectangle with barrel
        final angle = atan2(e.velY, e.velX);
        _drawTankEnemy(canvas, cx, cy, r, angle, paint);
        break;
      case 'taunt':
        // Square with inner squares
        _drawTauntEnemy(canvas, cx, cy, r, paint);
        break;
      case 'boss':
        // Boss - large spiky shape with crown
        _drawBossEnemy(canvas, cx, cy, r, paint);
        break;
      default:
        // Default circle for weak, strong, medic, stronger, spawner
        canvas.drawCircle(Offset(cx, cy), max(2, r), paint);
        break;
    }
  }

  void _drawArrowEnemy(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final back = -0.55 * r;
    final front = back + r * 2;
    final side = r;

    final path = Path()
      ..moveTo(back, -side)
      ..lineTo(0, 0)
      ..lineTo(back, side)
      ..lineTo(front, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawTankEnemy(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Tank body
    final front = r;
    final side = r * 0.7;
    final rect = Rect.fromLTRB(-front, -side, front, side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.2)),
      paint,
    );

    // Tank barrel
    final barrelPaint = Paint()
      ..color = const Color(0xFF95A5A6)
      ..style = PaintingStyle.fill;
    final barrelWidth = r * 0.15;
    final barrelLength = r * 0.7;
    canvas.drawRect(
      Rect.fromLTRB(0, -barrelWidth, barrelLength, barrelWidth),
      barrelPaint,
    );

    // Center circle
    canvas.drawCircle(Offset.zero, r * 0.2, barrelPaint);

    canvas.restore();
  }

  void _drawTauntEnemy(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    // Outer square
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2,
      height: r * 2,
    );
    canvas.drawRect(rect, paint);

    // Inner squares (orange)
    final innerPaint = Paint()
      ..color = const Color(0xFFE87E04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.2, height: r * 1.2),
      innerPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 0.8, height: r * 0.8),
      innerPaint,
    );
  }

  void _drawBossEnemy(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);

    // Draw devil horns (curved triangles on top)
    final hornPaint = Paint()
      ..color =
          const Color(0xFFFF0000) // Red horns
      ..style = PaintingStyle.fill;

    // Left horn (curved)
    final leftHornPath = Path()
      ..moveTo(-r * 0.4, -r * 0.6)
      ..quadraticBezierTo(
        -r * 0.7,
        -r * 1.3, // Control point (curves outward)
        -r * 0.3,
        -r * 1.1, // Tip point
      )
      ..quadraticBezierTo(
        -r * 0.5,
        -r * 0.8, // Control point (curves inward)
        -r * 0.4,
        -r * 0.6, // Back to base
      )
      ..close();
    canvas.drawPath(leftHornPath, hornPaint);

    // Right horn (curved)
    final rightHornPath = Path()
      ..moveTo(r * 0.4, -r * 0.6)
      ..quadraticBezierTo(
        r * 0.7,
        -r * 1.3, // Control point (curves outward)
        r * 0.3,
        -r * 1.1, // Tip point
      )
      ..quadraticBezierTo(
        r * 0.5,
        -r * 0.8, // Control point (curves inward)
        r * 0.4,
        -r * 0.6, // Back to base
      )
      ..close();
    canvas.drawPath(rightHornPath, hornPaint);

    // Draw main body as circle (devil face)
    canvas.drawCircle(Offset.zero, r, paint);

    // Draw angry eyes with pupils
    final eyeWhitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    // Eye whites
    canvas.drawCircle(Offset(-r * 0.35, -r * 0.1), r * 0.2, eyeWhitePaint);
    canvas.drawCircle(Offset(r * 0.35, -r * 0.1), r * 0.2, eyeWhitePaint);

    // Angry eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final leftBrowPath = Path()
      ..moveTo(-r * 0.5, -r * 0.25)
      ..lineTo(-r * 0.2, -r * 0.15);
    canvas.drawPath(leftBrowPath, browPaint);

    final rightBrowPath = Path()
      ..moveTo(r * 0.5, -r * 0.25)
      ..lineTo(r * 0.2, -r * 0.15);
    canvas.drawPath(rightBrowPath, browPaint);

    // Red glowing pupils
    final pupilPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-r * 0.35, -r * 0.1), r * 0.1, pupilPaint);
    canvas.drawCircle(Offset(r * 0.35, -r * 0.1), r * 0.1, pupilPaint);

    // Draw sinister smile
    final mouthPaint = Paint()
      ..color =
          const Color(0xFF8B0000) // Dark red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final mouthPath = Path()
      ..moveTo(-r * 0.4, r * 0.3)
      ..quadraticBezierTo(
        0,
        r * 0.6, // Control point (creates smile curve)
        r * 0.4,
        r * 0.3,
      );
    canvas.drawPath(mouthPath, mouthPaint);

    // Draw crown on top (gold)
    final crownPaint = Paint()
      ..color =
          const Color(0xFFFFD700) // Gold crown
      ..style = PaintingStyle.fill;

    final crownPath = Path()
      ..moveTo(-r * 0.5, -r * 0.8)
      ..lineTo(-r * 0.25, -r * 1.2)
      ..lineTo(0, -r * 0.9)
      ..lineTo(r * 0.25, -r * 1.2)
      ..lineTo(r * 0.5, -r * 0.8)
      ..close();
    canvas.drawPath(crownPath, crownPaint);

    canvas.restore();
  }

  void _drawHealthBar(
    Canvas canvas,
    TdEnemy e,
    double cx,
    double cy,
    double r,
    double tileSize,
  ) {
    if (e.health >= e.maxHealth) return;

    final percent = e.health / e.maxHealth;
    final barWidth = r * 2.8;
    final barHeight = max(3, r * 0.3);
    final top = cy - r - barHeight - 2;

    // Background (white border)
    final bgRect = Rect.fromCenter(
      center: Offset(cx, top),
      width: barWidth + 2,
      height: barHeight + 2,
    );
    canvas.drawRect(bgRect, Paint()..color = const Color(0xFFFFFFFF));

    // Health fill (red)
    final fillWidth = barWidth * percent;
    final fillRect = Rect.fromCenter(
      center: Offset(cx - (barWidth - fillWidth) / 2.0, top),
      width: fillWidth.toDouble(),
      height: barHeight.toDouble(),
    );
    canvas.drawRect(fillRect, Paint()..color = const Color(0xFFCF000F));
  }

  void _drawBossHealthBars(
    Canvas canvas,
    TdEnemy e,
    double cx,
    double cy,
    double r,
    double tileSize,
  ) {
    // Boss has 3 HP bars stacked vertically
    // Each bar represents 1/3 of total health
    final barWidth = r * 3.5;
    final barHeight = max(4, r * 0.35);
    final totalHealth = e.maxHealth;
    final healthPerBar = totalHealth / 3;

    for (int i = 0; i < 3; i++) {
      final barTop = cy - r - barHeight * (3 - i) - 2 * (3 - i);
      final barStart = healthPerBar * i;
      final barEnd = healthPerBar * (i + 1);

      // Determine bar color based on position (green -> yellow -> red)
      final barColor = i == 0
          ? const Color(0xFF00FF00) // Green for first bar
          : i == 1
          ? const Color(0xFFFFFF00) // Yellow for second
          : const Color(0xFFFF0000); // Red for last

      // Background (white border)
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, barTop),
          width: barWidth + 2,
          height: barHeight + 2,
        ),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      // Calculate fill
      double fillPercent = 0;
      if (e.health > barEnd) {
        fillPercent = 1.0;
      } else if (e.health > barStart) {
        fillPercent = (e.health - barStart) / healthPerBar;
      }

      if (fillPercent > 0) {
        final fillWidth = (barWidth * fillPercent).toDouble();
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx - (barWidth - fillWidth) / 2, barTop),
            width: fillWidth,
            height: barHeight.toDouble(),
          ),
          Paint()..color = barColor,
        );
      }
    }

    // Draw "BOSS" text above bars
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'BOSS',
        style: TextStyle(
          color: const Color(0xFFFF00FF),
          fontSize: r * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - r - barHeight * 4 - 10),
    );
  }

  void _drawTower(
    Canvas canvas,
    TdTower t,
    double cx,
    double cy,
    double r,
    double tileSize,
  ) {
    // Calculate angle toward target if any enemy in range
    double angle = 0;
    final enemiesInRange = _sim!.enemiesInRange(t.posX, t.posY, t.range);
    if (enemiesInRange.isNotEmpty) {
      // Find target (first or strongest for sniper)
      TdEnemy? target;
      if (t.towerType.isSniper) {
        target = _sim!.getStrongestTarget(enemiesInRange);
      } else {
        target = _sim!.getFirstTarget(enemiesInRange);
      }
      if (target != null) {
        angle = atan2(target.posY - t.posY, target.posX - t.posX);
      }
    }

    canvas.save();
    canvas.translate(cx, cy);

    // Draw base (if not sniper/tesla which have no base)
    if (!t.towerType.isSniper && !t.towerType.isTesla) {
      final basePaint = Paint()
        ..color = Color.fromARGB(255, t.color[0], t.color[1], t.color[2])
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, r, basePaint);

      // Border
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Visual indicator for upgraded towers - golden ring
    if (t.upgraded) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.1,
        Paint()
          ..color =
              const Color(0xFFFFD700) // Gold color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // Add a subtle glow effect
      canvas.drawCircle(
        Offset.zero,
        r * 1.15,
        Paint()
          ..color =
              const Color(0x40FFD700) // Semi-transparent gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Draw barrel based on tower type
    canvas.rotate(angle);
    _drawTowerBarrel(canvas, t, r, tileSize);

    canvas.restore();
  }

  void _drawTowerBarrel(Canvas canvas, TdTower t, double r, double tileSize) {
    final barrelPaint = Paint()
      ..color = Color.fromARGB(
        255,
        t.secondary[0],
        t.secondary[1],
        t.secondary[2],
      )
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    switch (t.towerType.key) {
      case 'gun':
        // Simple rectangle barrel
        final length = r * 0.8;
        final width = r * 0.3;
        final rect = Rect.fromLTRB(0, -width / 2, length, width / 2);
        canvas.drawRect(rect, barrelPaint);
        canvas.drawRect(rect, borderPaint);
        break;
      case 'sniper':
        // Triangle shape
        final height = r * sqrt(3) / 2;
        final back = -height / 3;
        final front = height * 2 / 3;
        final side = r / 2;
        final path = Path()
          ..moveTo(back, -side)
          ..lineTo(back, side)
          ..lineTo(front, 0)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.fromARGB(255, t.color[0], t.color[1], t.color[2]),
        );
        canvas.drawPath(path, borderPaint);
        break;
      case 'rocket':
        // Double barrel with fins
        final width = r * 0.15;
        final length = r * 0.6;
        canvas.drawRect(
          Rect.fromLTRB(0, -width * 2, length, -width),
          barrelPaint,
        );
        canvas.drawRect(
          Rect.fromLTRB(0, width, length, width * 2),
          barrelPaint,
        );
        // Fins
        final finPaint = Paint()..color = const Color(0xFFCF000F);
        canvas.drawRect(
          Rect.fromLTRB(length, -width * 3, length + width, width * 3),
          finPaint,
        );
        break;
      case 'tesla':
        // Hexagon base with circle
        _drawPolygon(
          canvas,
          6,
          r * 0.5,
          Paint()
            ..color = Color.fromARGB(
              255,
              t.secondary[0],
              t.secondary[1],
              t.secondary[2],
            ),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 0.55,
          Paint()
            ..color = Color.fromARGB(255, t.color[0], t.color[1], t.color[2]),
        );
        break;
      default:
        // Default barrel
        final length = r * 0.7;
        final width = r * 0.25;
        final rect = Rect.fromLTRB(0, -width / 2, length, width / 2);
        canvas.drawRect(rect, barrelPaint);
        canvas.drawRect(rect, borderPaint);
        break;
    }
  }

  void _drawPolygon(Canvas canvas, int sides, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = 2 * pi * i / sides - pi / 2;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_sim == null || _gameOver) return;

    final map = _sim!.baseMap;
    final cols = map.cols;
    final rows = map.rows;

    // Convert touch to tile coordinates using same mapping as render.
    final localTileW = settings.stretchMode
        ? size.x / cols
        : min(size.x / cols, size.y / rows);
    final localTileH = settings.stretchMode ? size.y / rows : localTileW;
    final localOriginX = settings.stretchMode
        ? 0.0
        : (size.x - cols * localTileW) / 2;
    final localOriginY = settings.stretchMode
        ? 0.0
        : (size.y - rows * localTileH) / 2;

    final x = event.canvasPosition.x;
    final y = event.canvasPosition.y;

    final col = ((x - localOriginX) / localTileW).floor();
    final row = ((y - localOriginY) / localTileH).floor();

    if (col < 0 || row < 0 || col >= cols || row >= rows) return;

    final existing = _sim!.getTowerAt(col, row);
    if (existing != null) {
      selectTower(existing);
      return;
    }

    // If we have a pending tower type, set the position
    if (_pendingTowerType != null) {
      setPendingTowerPosition(col, row);
    }
  }
}
