import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/tower_defense_game.dart';
import 'store_overlay.dart';
import 'status_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Create the game instance here, not in initState!
  final TowerDefenseGame game = TowerDefenseGame();
  
  bool isUIHidden = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Force the GameWidget to take up the whole screen
          Positioned.fill(
            child: GameWidget(
              game: game,
            ),
          ),
          
          // 2. The Reveal/Hide UI Button floating at top right
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(isUIHidden ? Icons.visibility : Icons.visibility_off, color: Colors.white, size: 32),
              onPressed: () {
                setState(() {
                  isUIHidden = !isUIHidden;
                });
              },
            ),
          ),

          // 3. Status/Top Panel (collapsable via AnimatedPositioned)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: isUIHidden ? -150 : 20,
            left: 20,
            child: StatusOverlay(game: game),
          ),

          // 4. Store/Bottom Panel (collapsable via AnimatedPositioned)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: isUIHidden ? -200 : 20,
            left: 20,
            right: 20, // stretch across bottom if possible, or centered
            child: Align(
              alignment: Alignment.bottomCenter,
              child: StoreOverlay(game: game),
            ),
          ),
        ],
      ),
    );
  }
}
