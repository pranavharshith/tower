import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'tower_defense_game.dart';
import '../components/enemy.dart';

class Spawner extends Component with HasGameReference<TowerDefenseGame> {
  final Random rng = Random();
  double _spawnTimer = 0;
  int _enemiesToSpawn = 0;
  String _enemyType = 'weak';
  
  void startNextWave() {
    game.wave++;
    if (game.wave <= 3) {
      _enemiesToSpawn = 10 + game.wave * 5;
      _enemyType = 'weak';
    } else if (game.wave <= 7) {
      _enemiesToSpawn = 20;
      _enemyType = (rng.nextBool()) ? 'strong' : 'fast';
    } else {
      _enemiesToSpawn = 30 + game.wave * 2;
      _enemyType = ['tank', 'medic', 'stronger', 'faster'][rng.nextInt(4)];
    }
  }

  @override
  void update(double dt) {
    if (game.paused) return;
    
    // Auto-start waves if no enemies left and not spawning
    if (_enemiesToSpawn <= 0) {
      bool hasEnemies = game.children.whereType<Enemy>().isNotEmpty;
      if (!hasEnemies) {
        startNextWave();
      }
    }

    if (_enemiesToSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnTimer = 1.0; // spawn every 1 second
        _spawnEnemy(_enemyType);
        _enemiesToSpawn--;
      }
    }
  }

  void _spawnEnemy(String type) {
    if (game.currentMap == null || game.currentMap!.spawnpoints.isEmpty) return;
    
    // Pick random spawn point
    var spawn = game.currentMap!.spawnpoints[rng.nextInt(game.currentMap!.spawnpoints.length)];
    Vector2 gridPos = Vector2(spawn[0].toDouble(), spawn[1].toDouble());
    
    double hp = 35.0 + game.wave * 10;
    double spd = 1.0;
    Color col = Colors.grey;
    int cdrop = 1;
    int dmg = 1;

    if (type == 'strong') { hp *= 2.5; col = Colors.blueGrey; cdrop = 2; }
    else if (type == 'fast') { spd = 2.0; hp *= 1.5; col = Colors.cyan; cdrop = 2; }
    else if (type == 'tank') { spd = 0.8; hp *= 5.0; col = Colors.green; cdrop = 4; dmg = 2; }
    else if (type == 'medic') { hp *= 3.0; col = Colors.red; cdrop = 3; }
    else if (type == 'stronger') { hp *= 4.0; col = Colors.indigo; cdrop = 4; dmg = 2; }
    else if (type == 'faster') { spd = 3.0; hp *= 2.0; col = Colors.orange; cdrop = 4; }

    final enemy = Enemy(
      health: hp,
      speed: spd,
      cashDrop: cdrop,
      damage: dmg,
      color: col,
      startGridPos: gridPos,
    );
    game.add(enemy);
  }
}
