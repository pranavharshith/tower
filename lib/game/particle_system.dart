import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Represents a single particle in the particle system
class Particle extends Component {
  Vector2 position;
  Vector2 velocity;
  final Color color;
  final double radius;
  final double lifetime;
  final double decayRate;
  double currentLifetime;
  bool isDead;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.lifetime,
    this.decayRate = 1.0,
  }) : currentLifetime = 0.0,
       isDead = false;

  @override
  void update(double dt) {
    super.update(dt);

    // Update lifetime
    currentLifetime += dt * decayRate;
    if (currentLifetime >= lifetime) {
      isDead = true;
      return;
    }

    // Update position based on velocity
    position += velocity * dt;

    // Apply gravity (optional, for falling particles)
    velocity.y += 50 * dt;

    // Apply friction/drag
    velocity *= 0.98;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (isDead) return;

    // Calculate alpha based on remaining lifetime
    final alpha = 1.0 - (currentLifetime / lifetime);
    // Reuse paint object instead of creating new one each frame
    _paint.color = color.withValues(alpha: alpha);

    canvas.drawCircle(Offset(position.x, position.y), radius, _paint);
  }
}

/// Manages a collection of particles for visual effects
class ParticleSystem extends Component {
  final List<Particle> particles = [];
  bool isEnabled = true;

  /// Create an explosion effect at the given position
  void createExplosion({
    required Vector2 position,
    Color? color,
    int particleCount = 20,
    double minSpeed = 50,
    double maxSpeed = 150,
    double minRadius = 2,
    double maxRadius = 5,
    double lifetime = 0.8,
  }) {
    if (!isEnabled) return;

    final random = Random();
    final baseColor = color ?? const Color(0xFFFF6B35); // Orange-red explosion

    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = minSpeed + random.nextDouble() * (maxSpeed - minSpeed);
      final velocity = Vector2(cos(angle) * speed, sin(angle) * speed);

      final radius = minRadius + random.nextDouble() * (maxRadius - minRadius);

      // Vary the color slightly
      final colorVariation = (random.nextDouble() - 0.5) * 50;
      final particleColor = Color.fromRGBO(
        ((baseColor.r * 255.0).round() + colorVariation).clamp(0, 255).toInt(),
        ((baseColor.g * 255.0).round() + colorVariation).clamp(0, 255).toInt(),
        ((baseColor.b * 255.0).round() + colorVariation).clamp(0, 255).toInt(),
        baseColor.a,
      );

      particles.add(
        Particle(
          position: position.clone(),
          velocity: velocity,
          color: particleColor,
          radius: radius,
          lifetime: lifetime,
        ),
      );
    }
  }

  /// Create a hit/spark effect
  void createHit({
    required Vector2 position,
    Color? color,
    int particleCount = 10,
  }) {
    if (!isEnabled) return;

    createExplosion(
      position: position,
      color: color ?? const Color(0xFFFFFF00), // Yellow sparks
      particleCount: particleCount,
      minSpeed: 30,
      maxSpeed: 80,
      minRadius: 1,
      maxRadius: 3,
      lifetime: 0.4,
    );
  }

  /// Create a trail effect (for projectiles/enemies)
  void createTrail({
    required Vector2 position,
    Color? color,
    int particleCount = 3,
  }) {
    if (!isEnabled) return;

    final random = Random();
    final baseColor = color ?? const Color(0xFF888888); // Gray trail

    for (int i = 0; i < particleCount; i++) {
      final offset = Vector2(
        (random.nextDouble() - 0.5) * 10,
        (random.nextDouble() - 0.5) * 10,
      );

      particles.add(
        Particle(
          position: position + offset,
          velocity: Vector2.zero(),
          color: baseColor.withValues(alpha: 0.5),
          radius: 2 + random.nextDouble() * 2,
          lifetime: 0.3,
          decayRate: 2.0,
        ),
      );
    }
  }

  /// Create a celebration/victory effect
  void createCelebration({required Vector2 position, int particleCount = 30}) {
    if (!isEnabled) return;

    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFF45B7D1), // Blue
      const Color(0xFF96CEB4), // Green
    ];

    createExplosion(
      position: position,
      color: colors[Random().nextInt(colors.length)],
      particleCount: particleCount,
      minSpeed: 80,
      maxSpeed: 200,
      minRadius: 3,
      maxRadius: 6,
      lifetime: 1.2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update all particles and remove dead ones
    particles.removeWhere((particle) {
      particle.update(dt);
      return particle.isDead;
    });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Render all particles
    for (final particle in particles) {
      particle.render(canvas);
    }
  }

  /// Clear all particles
  void clear() {
    particles.clear();
  }

  /// Enable or disable the particle system
  void setEnabled(bool enabled) {
    isEnabled = enabled;
    if (!enabled) {
      clear();
    }
  }
}
