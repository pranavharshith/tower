/// Enemy spawn tower — the pink tower that moves every 2 waves
/// and spawns enemy units.
class TdEnemyTower {
  int col;
  int row;
  bool isBossTower;
  bool isNearExit; // If true, enemies spawned here move at 60% speed
  int health;
  int maxHealth;

  TdEnemyTower({
    required this.col,
    required this.row,
    this.isBossTower = false,
    this.isNearExit = false,
    this.health = 100,
  }) : maxHealth = health;

}
