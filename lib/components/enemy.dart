import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tower_defense_game.dart';

class Enemy extends PositionComponent with HasGameReference<TowerDefenseGame> {
  double health;
  double maxHealth;
  double speed;
  int cashDrop;
  int damage;
  Color color;
  Vector2 gridPos;
  
  static const double ts = 24.0; // Tile size
  Vector2 velocity = Vector2.zero();

  Enemy({
    required this.health,
    required this.speed,
    required this.cashDrop,
    required this.damage,
    required this.color,
    required Vector2 startGridPos,
  })  : maxHealth = health,
        gridPos = startGridPos,
        super(position: Vector2(startGridPos.x * ts + ts / 2, startGridPos.y * ts + ts / 2), size: Vector2(ts * 0.8, ts * 0.8), anchor: Anchor.center);

  @override
  void update(double dt) {
    if (game.paused) return;
    super.update(dt);

    // Flow field steering
    final map = game.currentMap;
    if (map == null) return;
    
    int gx = (position.x / ts).floor();
    int gy = (position.y / ts).floor();
    
    if (gx >= 0 && gy >= 0 && gx < map.cols && gy < map.rows) {
      gridPos = Vector2(gx.toDouble(), gy.toDouble());
      
      // Check if at center of tile to turn
      Vector2 tileCenter = Vector2(gx * ts + ts / 2, gy * ts + ts / 2);
      if (position.distanceTo(tileCenter) < (speed * ts * dt)) {
        position.setFrom(tileCenter); // Snap to center
        
        int dir = map.paths[gx][gy];
        double pxSpeed = speed * ts;
        if (dir == 1) velocity = Vector2(-pxSpeed, 0); // left
        if (dir == 2) velocity = Vector2(0, -pxSpeed); // up
        if (dir == 3) velocity = Vector2(pxSpeed, 0);  // right
        if (dir == 4) velocity = Vector2(0, pxSpeed);  // down
      }
    }
    
    // Apply velocity constraints
    position.add(velocity * dt);
    
    // If reached exit
    if (gx == map.exit[0] && gy == map.exit[1]) {
      game.health -= damage;
      removeFromParent();
    }
  }

  void takeDamage(double dmg) {
    health -= dmg;
    if (health <= 0) {
      game.cash += cashDrop;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Rotation based on velocity
    if (velocity.length2 > 0) {
      angle = atan2(velocity.y, velocity.x);
    }
    
    final paint = Paint()..color = color;
    final r = size.x / 2;
    // Draw generic geometric shape
    canvas.drawCircle(Offset(r, r), r, paint);
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1);
    
    // Health bar
    if (health < maxHealth) {
      double pct = health / maxHealth;
      canvas.drawRect(Rect.fromLTWH(0, -6, size.x, 3), Paint()..color = Colors.red);
      canvas.drawRect(Rect.fromLTWH(0, -6, size.x * pct, 3), Paint()..color = Colors.green);
    }
  }
}
