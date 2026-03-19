import 'dart:math';
import 'package:flame/components.dart';

// Tile sizes
const int ts = 24;

bool between(double num, double min, double max) {
  return num > (min < max ? min : max) && num < (min > max ? min : max);
}

List<List<T>> buildArray<T>(int cols, int rows, T val) {
  return List.generate(cols, (_) => List.generate(rows, (_) => val));
}

Vector2 center(int col, int row) {
  return Vector2((col * ts + ts / 2).toDouble(), (row * ts + ts / 2).toDouble());
}

Vector2 gridPos(double x, double y) {
  return Vector2((x / ts).floorToDouble(), (y / ts).floorToDouble());
}

bool insideCircle(double x, double y, double cx, double cy, double r) {
  return pow(x - cx, 2) + pow(y - cy, 2) < pow(r, 2);
}

bool outsideRect(double x, double y, double cx, double cy, double w, double h) {
  return x < cx || y < cy || x > cx + w || y > cy + h;
}

Vector2 stv(String str) {
  var arr = str.split(',');
  return Vector2(double.parse(arr[0]), double.parse(arr[1]));
}

String vts(Vector2 v) {
  return '${v.x.toInt()},${v.y.toInt()}';
}

String cts(int col, int row) {
  return '$col,$row';
}

List<String> neighbors(List<List<int>> grid, int col, int row, int val) {
  List<String> n = [];
  if (col != 0 && grid[col - 1][row] == val) {
    n.add(cts(col - 1, row));
  }
  if (row != 0 && grid[col][row - 1] == val) {
    n.add(cts(col, row - 1));
  }
  if (col != grid.length - 1 && grid[col + 1][row] == val) {
    n.add(cts(col + 1, row));
  }
  if (row != grid[col].length - 1 && grid[col][row + 1] == val) {
    n.add(cts(col, row + 1));
  }
  return n;
}
