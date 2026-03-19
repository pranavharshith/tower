import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'maps.dart';
import '../components/map_component.dart';
import '../components/tower.dart';
import 'pathfinder.dart';
import 'spawner.dart';

class TowerDefenseGame extends FlameGame with TapCallbacks {
  // Set the camera to the exact pixel dimensions of the new vertical map.
  // 35 cols * 24px = 840 width
  // 24 rows * 24px = 576 height
  TowerDefenseGame() : super(
    world: World(),
    camera: CameraComponent.withFixedResolution(width: 840, height: 576),
  );

  @override
  Color backgroundColor() => const Color(0xFF222222);

  int cash = 55;
  int health = 40;
  int maxHealth = 40;
  int wave = 0;

  @override
  bool paused = false;
  bool godMode = false;

  GameMap? currentMap;
  MapComponent? mapComponent;
  Spawner? spawner;

  String selectedTower = 'gun';

  // The engine updates entities automatically if we add them as components.
  // We'll store lists if we need custom logic.

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Adjust the viewfinder
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    await resetGame();
  }

  Future<void> loadMap(String mapKey) async {
    try {
      if (rawMaps.containsKey(mapKey)) {
        currentMap = await GameMap.fromString(rawMaps[mapKey]!);
      }
    } catch (e, stacktrace) {
      print('CRITICAL MAP PARSING ERROR: $e');
      print(stacktrace);
    }
  }

  Future<void> resetGame() async {
    await loadMap('loops');

    health = 40;
    maxHealth = 40;
    cash = 55;
    wave = 0;
    // Keep paused = false so the engine runs and components load

    // Remove old map component if exists
    mapComponent?.removeFromParent();
    spawner?.removeFromParent();

    mapComponent = MapComponent();
    await world.add(mapComponent!);

    spawner = Spawner();
    await world.add(spawner!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (paused) return;
    // Spawning logic and pathfinding will go here
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (paused) return;
    final pos = event.localPosition;
    final gx = (pos.x / 24).floor(); // ts = 24
    final gy = (pos.y / 24).floor();

    if (currentMap == null) return;
    if (gx < 0 || gy < 0 || gx >= currentMap!.cols || gy >= currentMap!.rows) {
      return;
    }

    int cell = currentMap!.grid[gx][gy];
    if (cell == 0 || cell == 2) {
      if (cash >= 25 && _canPlaceTower(gx, gy)) {
        cash -= 25;
        currentMap!.grid[gx][gy] = 3; // 3 = tower
        recalculatePaths(currentMap!);

        Color tColor = Colors.blue;
        double dmg = 10;
        double range = 3.0;
        double cd = 0.5;

        if (selectedTower == 'laser') {
          tColor = Colors.lightBlueAccent;
          dmg = 2;
          cd = 0.1;
          range = 2;
        } else if (selectedTower == 'slow') {
          tColor = Colors.indigoAccent;
          dmg = 0;
          cd = 1.0;
          range = 1.5;
        } else if (selectedTower == 'sniper') {
          tColor = Colors.red;
          dmg = 50;
          cd = 2.0;
          range = 8;
        } else if (selectedTower == 'rocket') {
          tColor = Colors.green;
          dmg = 40;
          cd = 1.5;
          range = 6;
        } else if (selectedTower == 'bomb') {
          tColor = Colors.purple;
          dmg = 30;
          cd = 1.2;
          range = 2.5;
        } else if (selectedTower == 'tesla') {
          tColor = Colors.yellow;
          dmg = 100;
          cd = 1.5;
          range = 4;
        }

        world.add(
          Tower(
            gridPos: Vector2(gx.toDouble(), gy.toDouble()),
            title: selectedTower.toUpperCase(),
            type: selectedTower,
            attackRange: range,
            damage: dmg,
            cooldown: cd,
            color: tColor,
            cost: 25,
          ),
        );
      }
    }
  }

  bool _canPlaceTower(int gx, int gy) {
    int oldCell = currentMap!.grid[gx][gy];
    currentMap!.grid[gx][gy] = 3;
    bool valid = recalculatePaths(currentMap!);
    if (!valid) {
      currentMap!.grid[gx][gy] = oldCell;
      recalculatePaths(currentMap!);
    }
    return valid;
  }
}
