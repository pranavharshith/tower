import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import '../game/tower_defense_game.dart';
import '../game/maps.dart';

class MapComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  static const double ts = 24.0;

  Picture? _cachedBackground;
  int _lastCacheHashCode = 0;

  // Tile colors - dark mode
  static final Map<String, List<int>> _tileColors = {
    'empty': [0, 0, 0],          // Black
    'wall': [1, 50, 67],         // Dark blue/teal blocks
    'tower': [51, 110, 123],
    'grass': [0, 0, 0],          // Black
    'sidewalk': [149, 165, 166],
  };

  Color _getTileColor(String tileType, List<int> bg) {
    // Default to background color for empty tiles
    if (tileType == 'empty') {
      return Color.fromARGB(255, bg[0], bg[1], bg[2]);
    }

    final colors = _tileColors[tileType];
    if (colors != null) {
      return Color.fromARGB(255, colors[0], colors[1], colors[2]);
    }

    // Fallback based on grid value for unknown tile types
    return Color.fromARGB(255, bg[0], bg[1], bg[2]);
  }

  void _createCache(GameMap map) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final mapWidth = map.cols * ts;
    final mapHeight = map.rows * ts;

    // Draw background
    final bgPaint = Paint()
      ..color = Color.fromARGB(255, map.bg[0], map.bg[1], map.bg[2]);
    canvas.drawRect(Rect.fromLTWH(0, 0, mapWidth, mapHeight), bgPaint);

    // Draw tiles using display array (like reference game)
    for (int x = 0; x < map.cols; x++) {
      for (int y = 0; y < map.rows; y++) {
        final rect = Rect.fromLTWH(x * ts, y * ts, ts, ts);

        // Revert back to Column-Major [x][y]!
        String tileType = 'empty';
        if (x < map.display.length && y < map.display[x].length) {
          tileType = map.display[x][y]?.toString() ?? 'empty';
        }

        // Draw tile background
        final tilePaint = Paint()
          ..color = _getTileColor(tileType, map.bg);
        canvas.drawRect(rect, tilePaint);

        // Draw grid border (faint white like the original)
        final borderPaint = Paint()
          ..color = Colors.white.withAlpha(25)
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rect, borderPaint);
      }
    }

    // Draw exit point (red)
    if (map.exit.isNotEmpty && map.exit.length >= 2) {
      final exitPaint = Paint()
        ..color = Colors.red[700]!
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(map.exit[0] * ts, map.exit[1] * ts, ts, ts),
        exitPaint,
      );
      // Exit border
      final exitBorder = Paint()
        ..color = Colors.red[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(map.exit[0] * ts + 2, map.exit[1] * ts + 2, ts - 4, ts - 4),
        exitBorder,
      );
    }

    // Draw spawn points (green)
    final spawnPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;
    final spawnBorder = Paint()
      ..color = Colors.green[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var s in map.spawnpoints) {
      if (s.length >= 2) {
        canvas.drawRect(
          Rect.fromLTWH(s[0] * ts, s[1] * ts, ts, ts),
          spawnPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(s[0] * ts + 2, s[1] * ts + 2, ts - 4, ts - 4),
          spawnBorder,
        );
      }
    }

    _cachedBackground = recorder.endRecording();
    _lastCacheHashCode = _computeGridHash(map);
  }

  int _computeGridHash(GameMap map) {
    int h = 0;
    for (var row in map.grid) {
      for (var cell in row) {
        h = h * 31 + cell;
      }
    }
    return h;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final map = game.currentMap;
    if (map == null) {
      // THE RED SQUARE TEST
      // If the map failed to load, draw a bright red box so we know!
      canvas.drawRect(Rect.fromLTWH(0, 0, 300, 300), Paint()..color = Colors.red);
      return;
    }

    // Create or update cache
    if (_cachedBackground == null ||
        _lastCacheHashCode != _computeGridHash(map)) {
      _createCache(map);
    }

    // Draw cached background
    if (_cachedBackground != null) {
      canvas.drawPicture(_cachedBackground!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final map = game.currentMap;
    if (map != null) {
      size = Vector2(map.cols * ts, map.rows * ts);
    }
  }
}
