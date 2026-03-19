import 'package:flutter/material.dart';
import '../game/tower_defense_game.dart';

class StoreOverlay extends StatelessWidget {
  final TowerDefenseGame game;
  const StoreOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    // This replicates the left aside #store from index.html
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StoreItem(game: game, id: 'gun', name: 'Gun (1)', icon: Icons.straighten),
          _StoreItem(game: game, id: 'laser', name: 'Laser (2)', icon: Icons.highlight),
          _StoreItem(game: game, id: 'slow', name: 'Slow (3)', icon: Icons.ac_unit),
          _StoreItem(game: game, id: 'sniper', name: 'Sniper (4)', icon: Icons.my_location),
          _StoreItem(game: game, id: 'rocket', name: 'Rocket (5)', icon: Icons.rocket_launch),
          _StoreItem(game: game, id: 'bomb', name: 'Bomb (6)', icon: Icons.dangerous),
          _StoreItem(game: game, id: 'tesla', name: 'Tesla (7)', icon: Icons.electric_bolt),
        ],
      ),
    );
  }
}

class _StoreItem extends StatelessWidget {
  final TowerDefenseGame game;
  final String id;
  final String name;
  final IconData icon;

  const _StoreItem({required this.game, required this.id, required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    bool isSelected = game.selectedTower == id;
    return GestureDetector(
      onTap: () {
        game.selectedTower = id;
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[700] : Colors.grey[850],
          border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 28),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
