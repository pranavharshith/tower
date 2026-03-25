part of 'td_game.dart';

extension GameRenderer on TdGame {
  void _drawEnemy(
    Canvas canvas,
    TdEnemy e,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    switch (e.type) {
      case TdEnemyType.fast:
      case TdEnemyType.strongFast:
      case TdEnemyType.faster:
        // Arrow shape - rotated based on velocity direction
        final angle = atan2(e.velY, e.velX);
        _drawArrowEnemy(canvas, cx, cy, r, angle, paint);
      case TdEnemyType.tank:
        // Tank shape - rectangle with barrel
        final angle = atan2(e.velY, e.velX);
        _drawTankEnemy(canvas, cx, cy, r, angle, paint);
      case TdEnemyType.taunt:
        // Square with inner squares
        _drawTauntEnemy(canvas, cx, cy, r, paint);
      case TdEnemyType.boss:
        // Boss - large spiky shape with crown
        _drawBossEnemy(canvas, cx, cy, r, paint);
      case TdEnemyType.weak:
      case TdEnemyType.strong:
      case TdEnemyType.medic:
      case TdEnemyType.stronger:
      case TdEnemyType.spawner:
        // Default circle for these types
        canvas.drawCircle(Offset(cx, cy), max(2, r), paint);
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

    _drawBossHorns(canvas, r);
    canvas.drawCircle(Offset.zero, r, paint);
    _drawBossFace(canvas, r);
    _drawBossCrown(canvas, r);

    canvas.restore();
  }

  void _drawBossHorns(Canvas canvas, double r) {
    final hornPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.fill;

    final leftHornPath = Path()
      ..moveTo(-r * 0.4, -r * 0.6)
      ..quadraticBezierTo(-r * 0.7, -r * 1.3, -r * 0.3, -r * 1.1)
      ..quadraticBezierTo(-r * 0.5, -r * 0.8, -r * 0.4, -r * 0.6)
      ..close();
    canvas.drawPath(leftHornPath, hornPaint);

    final rightHornPath = Path()
      ..moveTo(r * 0.4, -r * 0.6)
      ..quadraticBezierTo(r * 0.7, -r * 1.3, r * 0.3, -r * 1.1)
      ..quadraticBezierTo(r * 0.5, -r * 0.8, r * 0.4, -r * 0.6)
      ..close();
    canvas.drawPath(rightHornPath, hornPaint);
  }

  void _drawBossFace(Canvas canvas, double r) {
    final eyeWhitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(-r * 0.35, -r * 0.1), r * 0.2, eyeWhitePaint);
    canvas.drawCircle(Offset(r * 0.35, -r * 0.1), r * 0.2, eyeWhitePaint);

    final browPaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.5, -r * 0.25)
        ..lineTo(-r * 0.2, -r * 0.15),
      browPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.5, -r * 0.25)
        ..lineTo(r * 0.2, -r * 0.15),
      browPaint,
    );

    final pupilPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-r * 0.35, -r * 0.1), r * 0.1, pupilPaint);
    canvas.drawCircle(Offset(r * 0.35, -r * 0.1), r * 0.1, pupilPaint);

    final mouthPath = Path()
      ..moveTo(-r * 0.4, r * 0.3)
      ..quadraticBezierTo(0, r * 0.6, r * 0.4, r * 0.3);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = const Color(0xFF8B0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawBossCrown(Canvas canvas, double r) {
    final crownPath = Path()
      ..moveTo(-r * 0.5, -r * 0.8)
      ..lineTo(-r * 0.25, -r * 1.2)
      ..lineTo(0, -r * 0.9)
      ..lineTo(r * 0.25, -r * 1.2)
      ..lineTo(r * 0.5, -r * 0.8)
      ..close();
    canvas.drawPath(
      crownPath,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill,
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
    canvas.drawRect(bgRect, GamePaints.whiteFill);

    // Health fill (red)
    final fillWidth = barWidth * percent;
    final fillRect = Rect.fromCenter(
      center: Offset(cx - (barWidth - fillWidth) / 2.0, top),
      width: fillWidth.toDouble(),
      height: barHeight.toDouble(),
    );
    canvas.drawRect(fillRect, GamePaints.healthFill);
  }

  void _drawBossHealthBars(
    Canvas canvas,
    TdEnemy e,
    double cx,
    double cy,
    double r,
    double tileSize,
  ) {
    // Boss has multiple HP bars based on total health
    // Wave 5 boss (800 HP): 1 bar
    // Wave 10+ boss (1200+ HP): 2 bars
    final numBars = e.maxHealth >= 1200 ? 2 : 1;
    final barWidth = r * 3.5;
    final barHeight = max(4, r * 0.35);
    final totalHealth = e.maxHealth;
    final healthPerBar = totalHealth / numBars;

    for (int i = 0; i < numBars; i++) {
      final barTop = cy - r - barHeight * (numBars - i) - 2 * (numBars - i);
      final barStart = healthPerBar * i;
      final barEnd = healthPerBar * (i + 1);

      final barColor = i == 0
          ? const Color(0xFF00FF00)
          : i == 1
          ? const Color(0xFFFFFF00)
          : const Color(0xFFFF0000);

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, barTop),
          width: barWidth + 2,
          height: barHeight + 2,
        ),
        GamePaints.whiteFill,
      );

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
          GamePaints.fill..color = barColor,
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
    double angle = 0;
    final enemiesInRange = _sim!.enemiesInRange(t.posX, t.posY, t.range);
    if (enemiesInRange.isNotEmpty) {
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
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset.zero,
        r * 1.15,
        Paint()
          ..color = const Color(0x40FFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

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

    switch (t.towerType) {
      case TdTowerType.gun:
        _drawRectangularBarrel(
          canvas,
          r * 0.8,
          r * 0.3,
          barrelPaint,
          borderPaint,
        );
      case TdTowerType.sniper:
        _drawTriangleBarrel(canvas, t, r, borderPaint);
      case TdTowerType.rocket:
        _drawDoubleBarrel(canvas, r);
      case TdTowerType.tesla:
        _drawTeslaCore(canvas, t, r);
      case TdTowerType.laser:
      case TdTowerType.slow:
      case TdTowerType.bomb:
        _drawRectangularBarrel(
          canvas,
          r * 0.7,
          r * 0.25,
          barrelPaint,
          borderPaint,
        );
    }
  }

  void _drawRectangularBarrel(
    Canvas canvas,
    double length,
    double width,
    Paint barrelPaint,
    Paint borderPaint,
  ) {
    final rect = Rect.fromLTRB(0, -width / 2, length, width / 2);
    canvas.drawRect(rect, barrelPaint);
    canvas.drawRect(rect, borderPaint);
  }

  void _drawTriangleBarrel(
    Canvas canvas,
    TdTower t,
    double r,
    Paint borderPaint,
  ) {
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
      Paint()..color = Color.fromARGB(255, t.color[0], t.color[1], t.color[2]),
    );
    canvas.drawPath(path, borderPaint);
  }

  void _drawDoubleBarrel(Canvas canvas, double r) {
    final barrelPaint = Paint()
      ..color = const Color(0xFF95A5A6)
      ..style = PaintingStyle.fill;
    final width = r * 0.15;
    final length = r * 0.6;
    canvas.drawRect(Rect.fromLTRB(0, -width * 2, length, -width), barrelPaint);
    canvas.drawRect(Rect.fromLTRB(0, width, length, width * 2), barrelPaint);
    canvas.drawRect(
      Rect.fromLTRB(length, -width * 3, length + width, width * 3),
      GamePaints.healthFill,
    );
  }

  void _drawTeslaCore(Canvas canvas, TdTower t, double r) {
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
      Paint()..color = Color.fromARGB(255, t.color[0], t.color[1], t.color[2]),
    );
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
}
