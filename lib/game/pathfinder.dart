import 'dart:collection';
import 'package:flame/components.dart';
import 'maps.dart';

bool recalculatePaths(GameMap map) {
  int cols = map.cols;
  int rows = map.rows;
  List<List<int>> newPaths = List.generate(cols, (_) => List.filled(rows, 0));
  List<List<bool>> visited = List.generate(
    cols,
    (_) => List.filled(rows, false),
  );
  Queue<Vector2> frontier = Queue();

  if (map.exit.isEmpty) return false;
  Vector2 target = Vector2(map.exit[0].toDouble(), map.exit[1].toDouble());
  frontier.add(target);
  visited[target.x.toInt()][target.y.toInt()] = true;

  Map<String, Vector2> cameFrom = {};

  while (frontier.isNotEmpty) {
    Vector2 current = frontier.removeFirst();
    int cx = current.x.toInt();
    int cy = current.y.toInt();

    List<Vector2> neighbors = [];
    if (cx > 0) {
      neighbors.add(Vector2((cx - 1).toDouble(), cy.toDouble()));
    }
    if (cy > 0) {
      neighbors.add(Vector2(cx.toDouble(), (cy - 1).toDouble()));
    }
    if (cx < cols - 1) {
      neighbors.add(Vector2((cx + 1).toDouble(), cy.toDouble()));
    }
    if (cy < rows - 1) {
      neighbors.add(Vector2(cx.toDouble(), (cy + 1).toDouble()));
    }

    for (var next in neighbors) {
      int nx = next.x.toInt();
      int ny = next.y.toInt();
      int gridVal = map.grid[nx][ny];

      // Check walkability: wall=1, tower=3
      if (gridVal != 1 && gridVal != 3 && !visited[nx][ny]) {
        visited[nx][ny] = true;
        cameFrom['$nx,$ny'] = current;
        frontier.add(next);
      }
    }
  }

  // Ensure all spawnpoints are still reachable
  for (var s in map.spawnpoints) {
    if (s.isEmpty) {
      continue;
    }
    if (!visited[s[0]][s[1]]) {
      return false;
    }
  }

  for (var key in cameFrom.keys) {
    List<String> parts = key.split(',');
    int x = int.parse(parts[0]);
    int y = int.parse(parts[1]);
    Vector2 next = cameFrom[key]!;

    // Directions: 1=left, 2=up, 3=right, 4=down
    if (next.x < x) {
      newPaths[x][y] = 1;
    } else if (next.y < y) {
      newPaths[x][y] = 2;
    } else if (next.x > x) {
      newPaths[x][y] = 3;
    } else if (next.y > y) {
      newPaths[x][y] = 4;
    }
  }

  map.paths = newPaths;
  return true;
}
