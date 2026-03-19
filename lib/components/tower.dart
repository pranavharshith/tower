import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tower_defense_game.dart';
import 'enemy.dart';
import 'missile.dart';

class Tower extends PositionComponent with HasGameReference<TowerDefenseGame> {
  Vector2 gridPos;
  String title;
  String type;
  double attackRange;
  double damage;
  double cooldown;
  Color color;
  int cost;

  double _attackTimer = 0;
  static const double ts = 24.0;
  Enemy? target;

  Tower({
    required this.gridPos,
    required this.title,
    required this.type,
    required this.attackRange,
    required this.damage,
    required this.cooldown,
    required this.color,
    required this.cost,
  }) : super(
          position: Vector2(gridPos.x * ts, gridPos.y * ts),
          size: Vector2(ts, ts),
        );

  @override
  void update(double dt) {
    if (game.paused) return;
    super.update(dt);
    
    _attackTimer -= dt;
    
    if (target != null && (target!.isRemoved || target!.position.distanceTo(position + size / 2) > attackRange * ts)) {
      target = null;
    }
    
    if (target == null) {
      // Find nearest enemy
      double minD = attackRange * ts;
      for (var e in game.children.whereType<Enemy>()) {
        double d = e.position.distanceTo(position + size / 2);
        if (d <= minD) {
          minD = d;
          target = e;
        }
      }
    }
    
    if (target != null) {
      // Point towards target
      angle = atan2(target!.position.y - (position.y + size.y / 2), target!.position.x - (position.x + size.x / 2));
      
      // Shoot
      if (_attackTimer <= 0) {
        _attackTimer = cooldown;
        game.add(Missile(
           spawnPos: position + size / 2,
           target: target!,
           damage: damage,
           color: color,
        ));
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Barrel
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2); // To center
    final barrelPaint = Paint()..color = Colors.grey[400]!;
    canvas.drawRect(Rect.fromLTWH(0, -size.y / 6, size.x * 0.8, size.y / 3), barrelPaint);
    
    // Base
    canvas.drawCircle(Offset.zero, size.x * 0.4, Paint()..color = color);
    canvas.drawCircle(Offset.zero, size.x * 0.4, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset.zero, size.x * 0.15, Paint()..color = Colors.black45);
    canvas.restore();
  }
}
