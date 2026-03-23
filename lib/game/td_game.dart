import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../data/td_maps.dart';
import '../data/td_random_maps.dart';
import '../services/sound_service.dart';
import 'td_simulation.dart';
import 'particle_system.dart';

part 'game_renderer.dart';

class GamePaints {
  static final Paint fill = Paint()..style = PaintingStyle.fill;
  static final Paint stroke1 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint stroke2 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint stroke3 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  static final Paint grid = Paint()
    ..color = const Color(0xFF00E640).withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint exit = Paint()
    ..color = const Color(0xFFFF6B6B)
    ..style = PaintingStyle.fill;
  static final Paint spawn = Paint()
    ..color = const Color(0xFFFF69B4)
    ..style = PaintingStyle.fill;
  static final Paint tempSpawn = Paint()
    ..color = const Color(0xFF9D4EDD)
    ..style = PaintingStyle.fill;
  static final Paint bossSpawn = Paint()
    ..color = const Color(0xFFFF0040)
    ..style = PaintingStyle.fill;
  static final Paint whiteStroke1 = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint whiteStroke2 = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint blackStroke1 = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint missile = Paint()
    ..color = const Color(0xFFFFFF00)
    ..style = PaintingStyle.fill;
  static final Paint healthBg = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint healthFill = Paint()
    ..color = const Color(0xFFE53935)
    ..style = PaintingStyle.fill;
  static final Paint tankBarrel = Paint()
    ..color = const Color(0xFF95A5A6)
    ..style = PaintingStyle.fill;
  static final Paint tauntInner = Paint()
    ..color = const Color(0xFFE87E04)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint bossHorn = Paint()
    ..color = const Color(0xFFFF0000)
    ..style = PaintingStyle.fill;
  static final Paint whiteFill = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint bossBrow = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint bossPupil = Paint()
    ..color = const Color(0xFFFF0000)
    ..style = PaintingStyle.fill;
  static final Paint bossMouth = Paint()
    ..color = const Color(0xFF8B0000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint bossCrown = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.fill;
  static final Paint fin = Paint()
    ..color = const Color(0xFF43A047)
    ..style = PaintingStyle.fill;
  static final Paint goldStroke2 = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint goldStroke1Glow = Paint()
    ..color = const Color(0x40FFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint greyFill = Paint()
    ..color = const Color(0xFF555555)
    ..style = PaintingStyle.fill;

  static final TextPainter bossText = TextPainter(
    text: const TextSpan(
      text: 'BOSS',
      style: TextStyle(
        color: Color(0xFFFF00FF),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

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
  final void Function(TdHudData data) onHudUpdate;
  final void Function()? onSelectionRevision;

  ui.Picture? _bgCache;
  Vector2? _lastSize;

  // Callback for when tower placement fails (for UI feedback)
  void Function(String reason)? onPlacementFailed;

  // UI <-> game selection state
  TdTowerType? placingType;
  TdTower? selectedTower;

  // Double-tap detection for tower stats
  TdTower? _lastTappedTower;
  DateTime? _lastTapTime;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  bool _shouldShowStatsModal = false;

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
  bool get shouldShowStatsModal => _shouldShowStatsModal;

  TdGame({
    required this.mapKey,
    required this.settings,
    required this.onGameOver,
    required this.onHudUpdate,
    this.onSelectionRevision,
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

    _sim = TdSim(
      baseMap: mapData,
      rng: _rng,
      cash: cash,
      soundService: _soundService,
      mapKey: mapKey,
    );
    _sim!.startGame();

    _bestWave = 0;
    _gameOver = false;
    onHudUpdate(
      TdHudData(
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
      ),
    );
  }

  void setPlacingType(TdTowerType? type) {
    placingType = type;
    if (type != null) {
      // Selecting store items cancels tower selection.
      selectedTower = null;
    }
    onSelectionRevision?.call();
  }

  void selectTower(TdTower? tower) {
    selectedTower = tower;
    _shouldShowStatsModal = false; // Reset modal flag
    placingType = null;
    onSelectionRevision?.call();
  }

  void clearStatsModalFlag() {
    _shouldShowStatsModal = false;
  }

  void upgradeTower(TdTower tower) {
    if (!tower.canUpgrade) return;

    final upgradeCost = tower.towerType.upgrade?.cost ?? 0;

    if (_sim!.cash < upgradeCost) {
      onPlacementFailed?.call('Not enough cash for upgrade');
      return;
    }

    _sim!.upgradeTower(tower, upgradeCost);
    onSelectionRevision?.call();
  }

  void upgradeSelected() {
    if (selectedTower == null) return;
    upgradeTower(selectedTower!);
  }

  void sellSelected() {
    if (selectedTower == null) return;
    sim.sellTower(selectedTower!);
    selectedTower = null;
    onSelectionRevision?.call();
  }

  void sellTowerDirect(TdTower tower) {
    sim.sellTower(tower);
    if (selectedTower == tower) {
      selectedTower = null;
    }
    onSelectionRevision?.call();
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
    onSelectionRevision?.call();
    return true;
  }

  // Confirm tower placement
  void confirmPendingTower() {
    if (_pendingTowerType == null ||
        _pendingTowerCol == null ||
        _pendingTowerRow == null) {
      return;
    }

    final col = _pendingTowerCol!;
    final row = _pendingTowerRow!;
    final towerType = _pendingTowerType!;

    // Re-validate: Check if enemy moved onto this tile
    for (final e in _sim!.enemies) {
      if (e.gridCol == col && e.gridRow == row) {
        onPlacementFailed?.call('Enemy moved onto this tile');
        cancelPendingTower();
        return;
      }
    }

    // Re-validate: Check if path is still valid
    if (!_sim!.placeable(col, row)) {
      onPlacementFailed?.call('Would block enemy path');
      cancelPendingTower();
      return;
    }

    // Check if player has enough cash
    final towerCost = towerType.cost;
    if (_sim!.cash < towerCost) {
      // Not enough cash - cancel placement
      onPlacementFailed?.call('Not enough cash');
      cancelPendingTower();
      return;
    }

    // Deduct cash and place tower
    _sim!.cash -= towerCost;
    _sim!.placeTower(towerType, col, row);

    // Clear pending state
    _pendingTowerType = null;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = null;
    onSelectionRevision?.call();
  }

  // Cancel tower placement
  void cancelPendingTower() {
    _pendingTowerType = null;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = null;
    onSelectionRevision?.call();
  }

  // Start placing a tower type
  void startPlacingTower(TdTowerType type) {
    _pendingTowerType = type;
    _pendingTowerCol = null;
    _pendingTowerRow = null;
    _placementTimeout = 0;
    placingType = type;
    selectedTower = null;
    onSelectionRevision?.call();
  }

  @override
  void update(double dt) {
    // Cap delta time to 100 ms to prevent physics tunneling after lag spikes
    // (e.g. GC pause, app resume from background).
    dt = dt.clamp(0.0, 0.1);
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
      onHudUpdate(
        TdHudData(
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
        ),
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

    onHudUpdate(
      TdHudData(
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
      ),
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

    if (_bgCache == null || _lastSize != size) {
      _lastSize = size.clone();
      final recorder = ui.PictureRecorder();
      final bgCanvas = Canvas(recorder);

      // Background based on map bg.
      final bg = Color.fromARGB(255, map.bg[0], map.bg[1], map.bg[2]);
      bgCanvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        GamePaints.fill..color = bg,
      );

      // Tile grid fill using `display` keys.
      final tilePaint = GamePaints.fill;
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
          bgCanvas.drawRect(rect, tilePaint);
        }
      }

      // Grid lines (every tile) - green on dark background like towerdefense.
      final gridPaint = Paint()
        ..color = const Color(0xFF00E640)
            .withValues(alpha: 0.3) // Green grid lines
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (int c = 0; c <= cols; c++) {
        final x = originX + c * tileW;
        bgCanvas.drawLine(
          Offset(x, originY),
          Offset(x, originY + rows * tileH),
          gridPaint,
        );
      }
      for (int r = 0; r <= rows; r++) {
        final y = originY + r * tileH;
        bgCanvas.drawLine(
          Offset(originX, y),
          Offset(originX + cols * tileW, y),
          gridPaint,
        );
      }

      _bgCache = recorder.endRecording();
    }

    if (_bgCache != null) {
      canvas.drawPicture(_bgCache!);
    }

    // Exit - soft coral color
    final exitPaint = GamePaints.exit; // Soft coral
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
    final spawnPaint = GamePaints.spawn; // Hot pink
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
        GamePaints.tempSpawn, // Soft purple
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

      // Draw range circle based on selection type
      // Priority: selectedTower (single tower) > placingType (all of same type)
      final shouldShowRange =
          (selectedTower != null && t == selectedTower) ||
          (selectedTower == null && placingType?.key == t.towerType.key);

      if (shouldShowRange) {
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
        GamePaints.fill..color = color,
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
        GamePaints.missile, // Soft coral
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
      // Double-tap detection
      final now = DateTime.now();
      final isDoubleTap =
          _lastTappedTower == existing &&
          _lastTapTime != null &&
          now.difference(_lastTapTime!) < _doubleTapWindow;

      if (isDoubleTap) {
        // Double tap - show stats modal
        selectTower(existing);
        _shouldShowStatsModal = true;
        _lastTappedTower = null;
        _lastTapTime = null;
      } else {
        // Single tap - just show range (select tower)
        selectTower(existing);
        _lastTappedTower = existing;
        _lastTapTime = now;
      }
      return;
    }

    // If we have a pending tower type, set the position
    if (_pendingTowerType != null) {
      setPendingTowerPosition(col, row);
      return;
    }

    // Tapping empty space - deselect manually selected tower (but keep tower store selection)
    if (selectedTower != null) {
      selectTower(null);
    }
  }
}
