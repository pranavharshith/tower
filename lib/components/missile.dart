import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tower_defense_game.dart';
import 'enemy.dart';

class Missile extends PositionComponent with HasGameReference<TowerDefenseGame> {
  final Enemy target;
  final double damage;
  final Color color;
  
  Vector2 velocity = Vector2.zero();
  final double speed = 300.0; // pixels per sec

  Missile({
    required Vector2 spawnPos,
    required this.target,
    required this.damage,
    required this.color,
  }) : super(
          position: spawnPos,
          size: Vector2(8, 4),
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    if (game.paused) return;
    super.update(dt);

    if (target.isRemoved) {
      removeFromParent();
      return;
    }

    Vector2 dir = (target.position - position).normalized();
    velocity = dir * speed;
    angle = atan2(dir.y, dir.x);
    position.add(velocity * dt);

    if (position.distanceTo(target.position) < 10.0) {
      target.takeDamage(damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1);
  }
}
