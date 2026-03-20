import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/td_maps.dart';
import '../data/td_random_maps.dart';
import '../services/td_audio.dart';
import 'td_simulation.dart';

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
  const TdHudData({
    required this.wave,
    required this.health,
    required this.maxHealth,
    required this.cash,
    required this.paused,
  });
}

class TdGame extends FlameGame with TapCallbacks {
  final String mapKey;
  final TdGameSettings settings;
  final void Function(int bestWave) onGameOver;

  // UI <-> game selection state
  TdTowerType? placingType;
  TdTower? selectedTower;

  // Expose HUD for overlay widgets.
  final ValueNotifier<TdHudData> hud = ValueNotifier<TdHudData>(
    const TdHudData(wave: 0, health: 40, maxHealth: 40, cash: 0, paused: true),
  );

  /// Used by Flutter UI overlays to re-render when selection changes.
  final ValueNotifier<int> selectionRevision = ValueNotifier<int>(0);

  TdSim? _sim;

  Random _rng = Random();
  late final TdMaps _tdMaps;
  late final TdRandomMapGenerator _randomMapGenerator;

  bool _gameOver = false;
  int _bestWave = 0;

  TdGame({
    required this.mapKey,
    required this.settings,
    required this.onGameOver,
  }) : super();

  TdSim get sim => _sim!;

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

    // Initialize audio
    await TdAudio().init();

    _tdMaps = const TdMaps();
    _randomMapGenerator = TdRandomMapGenerator(_rng);

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
    sim.upgradeTower(selectedTower!);
    selectionRevision.value++;
  }

  void sellSelected() {
    if (selectedTower == null) return;
    sim.sellTower(selectedTower!);
    selectedTower = null;
    selectionRevision.value++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    final sim = _sim;
    if (sim == null) return;

    // Run fixed-step simulation.
    _accum += dt;
    while (_accum >= kSimSecondsPerTick) {
      _accum -= kSimSecondsPerTick;
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

    hud.value = TdHudData(
      wave: sim.wave,
      health: sim.health,
      maxHealth: sim.maxHealth,
      cash: sim.cash,
      paused: sim.paused,
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
    Color _c(int r, int g, int b) => Color.fromARGB(255, r, g, b);
    // New softer colors
    const road = Color(0xFFE8DCC4); // Soft beige/light brown for path
    const grass = Color(0xFFB8E0D2); // Muted mint green
    const wall = Color(0xFF6B7FD7); // Soft indigo
    const towerTile = Color(0xFF7FD8BE); // Mint
    const sidewalk = Color(0xFFD4D4E0); // Light gray
    // Map theme colors - softer variants
    const c0_lightBrown = Color(0xFFE8DCC4);
    const c0_lightPurple = Color(0xFFC5B8E0);
    const c0_mediumPurple = Color(0xFF9D8EC4);
    const c0_darkPurple = Color(0xFF7A6BA3);
    const c0_paleGreen = Color(0xFFD4F1E0);
    const c1_darkBlue = Color(0xFF4A5B8C);
    const c1_mediumBlue = Color(0xFF6B7FD7);
    const c1_lightBlue = Color(0xFF9BB5F0);
    const c1_darkPurple = Color(0xFF7A6BA3);
    const c1_neonPink = Color(0xFFFF8B9A);
    const c2_darkRed = Color(0xFFC45B5B);
    const c2_navyBlue = Color(0xFF4A5B8C);
    const c2_darkBlue = Color(0xFF5B6BA3);
    const c2_paleYellow = Color(0xFFFFF4D4);
    const c2_lightYellow = Color(0xFFFFE8B8);

    Color tileColor(dynamic display, int gridValue) {
      // Grid value 1 = wall (obstacle), 0 = empty/walkable
      if (gridValue == 1) {
        return const Color(0xFF013243); // Navy blue walls like towerdefense
      }
      if (display == null) return const Color(0xFF000000);
      final s = display as String;
      switch (s) {
        case 'empty':
          return const Color(0xFF000000);
        case 'grass':
          return grass;
        case 'wall':
          return const Color(0xFF013243); // Navy blue walls
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
          return c0_lightBrown;
        case 'c0_lightPurple':
          return c0_lightPurple;
        case 'c0_mediumPurple':
          return c0_mediumPurple;
        case 'c0_darkPurple':
          return c0_darkPurple;
        case 'c0_paleGreen':
          return c0_paleGreen;
        case 'c1_darkBlue':
          return c1_darkBlue;
        case 'c1_mediumBlue':
          return c1_mediumBlue;
        case 'c1_lightBlue':
          return c1_lightBlue;
        case 'c1_darkPurple':
          return c1_darkPurple;
        case 'c1_neonPink':
          return c1_neonPink;
        case 'c2_darkRed':
          return c2_darkRed;
        case 'c2_navyBlue':
          return c2_navyBlue;
        case 'c2_darkBlue':
          return c2_darkBlue;
        case 'c2_paleYellow':
          return c2_paleYellow;
        case 'c2_lightYellow':
          return c2_lightYellow;
        default:
          return const Color(0xFF000000);
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

    // Exit + spawnpoints - softer colors.
    final exitPaint = Paint()..color = const Color(0xFFFF8B7B); // Soft coral
    final spawnPaint = Paint()..color = const Color(0xFF06D6A0); // Mint
    canvas.drawRect(
      Rect.fromLTWH(
        originX + map.exit.x * tileW,
        originY + map.exit.y * tileH,
        tileW,
        tileH,
      ),
      exitPaint,
    );
    for (final s in map.spawnpoints) {
      canvas.drawRect(
        Rect.fromLTWH(
          originX + s.x * tileW,
          originY + s.y * tileH,
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
      // Scale down tower radius to fit within tile (towerdefense uses 0.3-0.5 as visual radius)
      final r = t.radiusTiles * tileSizeForRadius * 0.5;

      // Draw range circle if selected or placing
      if (t == selectedTower || placingType?.key == t.towerType.key) {
        final rangeRadius = (t.range + 0.5) * tileSizeForRadius * 2;
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

      // Draw HP bar above enemy
      _drawHealthBar(canvas, e, cx, cy, r, tileSizeForRadius);
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

    // HUD hint: when placing a tower, lightly highlight tap tile in onTapDown.
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

    if (placingType != null) {
      if (_sim!.canPlaceTower(placingType!, col, row)) {
        _sim!.placeTower(placingType!, col, row);
        // Select the newly placed tower.
        final placed = _sim!.getTowerAt(col, row);
        selectedTower = placed;
        placingType = null;
        hud.value = hud.value;
      }
    }
  }
}
