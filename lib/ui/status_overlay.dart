import 'dart:async';
import 'package:flutter/material.dart';
import '../game/tower_defense_game.dart';

class StatusOverlay extends StatefulWidget {
  final TowerDefenseGame game;
  const StatusOverlay({super.key, required this.game});

  @override
  State<StatusOverlay> createState() => _StatusOverlayState();
}

class _StatusOverlayState extends State<StatusOverlay> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Re-render UI to automatically reflect Game state (cash, health, waves, paused)
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wave ${game.wave}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text('${game.health}/${game.maxHealth}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.yellow, size: 16),
              const SizedBox(width: 4),
              Text('${game.cash}', style: const TextStyle(fontSize: 16, color: Colors.yellow)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  game.paused = !game.paused;
                  setState(() {});
                },
                child: Text(game.paused ? 'Start' : 'Pause'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await game.resetGame();
                  setState(() {});
                },
                child: const Text('Restart'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
