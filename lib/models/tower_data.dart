enum TowerType {
  gun,
  laser,
  slow,
  sniper,
  rocket,
  bomb,
  tesla
}

class Tower {
  final TowerType type;
  final double cost;
  final double damage;
  final double range;
  final double cooldown;

  Tower({required this.type, required this.cost, required this.damage, required this.range, required this.cooldown});
}