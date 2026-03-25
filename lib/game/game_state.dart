/// Encapsulates game state to reduce TdSim complexity.
///
/// Manages player state including cash, health, and visual effects.
/// Provides methods for state manipulation with proper bounds checking.
class GameState {
  // Player state
  int cash;
  int health;
  int maxHealth;

  // Heal effect state
  int healAmount = 0;
  int healEffectTicks = 0;

  // Game control
  bool paused = true;

  /// Creates a new game state with initial values.
  GameState({
    required this.cash,
    required this.health,
    required this.maxHealth,
  });

  /// Resets the game state to initial values.
  void reset({required int initialCash}) {
    cash = initialCash;
    health = 40;
    maxHealth = 40;
    healAmount = 0;
    healEffectTicks = 0;
    paused = true;
  }

  /// Applies healing to the player with visual effect.
  ///
  /// Health is clamped to [0, maxHealth] range.
  /// Sets [healAmount] and [healEffectTicks] for UI feedback.
  void applyHeal(int amount) {
    final oldHealth = health;
    health = (health + amount).clamp(0, maxHealth);
    healAmount = health - oldHealth;
    healEffectTicks = 60; // Show heal effect for 60 ticks
  }

  /// Applies damage to the player.
  ///
  /// Health is clamped to [0, maxHealth] range to prevent negative values.
  /// Returns true if this damage caused game over.
  bool takeDamage(int damage) {
    final oldHealth = health;
    health = (health - damage).clamp(0, maxHealth);

    // Ensure health never goes below zero (extra safety)
    if (health < 0) health = 0;

    // Return true if game over occurred
    return health <= 0;
  }

  /// Updates the heal effect timer (call once per tick).
  void updateHealEffect() {
    if (healEffectTicks > 0) {
      healEffectTicks--;
    }
  }

  /// Returns true if the game is over (health <= 0).
  bool get isGameOver => health <= 0;
}
