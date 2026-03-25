/// Shared game utility functions used across the simulation and managers.
///
/// Centralises helpers that were previously duplicated in:
/// - [TdSim] (top-level `_atTileCenter`)
/// - [EnemyManager] (private `_atTileCenter`)
library;

import 'package:flutter/material.dart';

/// Returns true when the point ([x], [y]) is within [tol] distance of the
/// centre of tile ([col], [row]).
///
/// Tile centre is at (col + 0.5, row + 0.5).
/// Default tolerance matches the JS port: 1/24 of a tile unit.
bool atTileCenter(
  double x,
  double y,
  int col,
  int row, {
  double tol = 1 / 24.0,
}) {
  final cX = col + 0.5;
  final cY = row + 0.5;
  return x > cX - tol && x < cX + tol && y > cY - tol && y < cY + tol;
}

/// Deep-copies a 2-D list of [int].
List<List<int>> deepCopy2DInt(List<List<int>> src) {
  return src.map((col) => col.toList(growable: false)).toList(growable: false);
}

/// Returns the color for a tile based on its display type and grid value.
///
/// This is a pure function extracted from the render loop for performance
/// and code organization (avoids defining a function inside hot-path).
///
/// [display] - The display type string from map data (e.g., 'grass', 'road')
/// [gridValue] - The grid value (0=empty, 1=wall, 2=path, 3=water)
Color tileColor(dynamic display, int gridValue) {
  // Grid value 1 = wall (obstacle) - grey color
  if (gridValue == 1) {
    return const Color(0xFF555555); // Grey for obstacles
  }
  // Grid value 0 = empty/walkable - transparent/no color
  if (gridValue == 0) {
    return const Color(0x00000000); // Transparent for empty tiles
  }
  if (display == null) return const Color(0x00000000);
  final s = display as String;

  // Map theme colors - softer variants
  const road = Color(0xFFE8DCC4); // Soft beige/light brown for path
  const grass = Color(0xFFB8E0D2); // Muted mint green
  const towerTile = Color(0xFF7FD8BE); // Mint
  const sidewalk = Color(0xFFD4D4E0); // Light gray
  const c0LightBrown = Color(0xFFE8DCC4);
  const c0LightPurple = Color(0xFFC5B8E0);
  const c0MediumPurple = Color(0xFF9D8EC4);
  const c0DarkPurple = Color(0xFF7A6BA3);
  const c0PaleGreen = Color(0xFFD4F1E0);
  const c1DarkBlue = Color(0xFF4A5B8C);
  const c1MediumBlue = Color(0xFF6B7FD7);
  const c1LightBlue = Color(0xFF9BB5F0);
  const c1DarkPurple = Color(0xFF7A6BA3);
  const c1NeonPink = Color(0xFFFF8B9A);
  const c2DarkRed = Color(0xFFC45B5B);
  const c2NavyBlue = Color(0xFF4A5B8C);
  const c2DarkBlue = Color(0xFF5B6BA3);
  const c2PaleYellow = Color(0xFFFFF4D4);
  const c2LightYellow = Color(0xFFFFE8B8);

  switch (s) {
    case 'empty':
      return const Color(0x00000000); // Transparent
    case 'grass':
      return grass;
    case 'wall':
      return const Color(0xFF555555); // Grey for walls
    case 'tower':
      return towerTile;
    case 'sidewalk':
      return sidewalk;
    case 'road':
      return road;
    case 'lCorner':
    case 'rCorner':
      return road;
    case 'c0_lightBrown':
      return c0LightBrown;
    case 'c0_lightPurple':
      return c0LightPurple;
    case 'c0_mediumPurple':
      return c0MediumPurple;
    case 'c0_darkPurple':
      return c0DarkPurple;
    case 'c0_paleGreen':
      return c0PaleGreen;
    case 'c1_darkBlue':
      return c1DarkBlue;
    case 'c1_mediumBlue':
      return c1MediumBlue;
    case 'c1_lightBlue':
      return c1LightBlue;
    case 'c1_darkPurple':
      return c1DarkPurple;
    case 'c1_neonPink':
      return c1NeonPink;
    case 'c2_darkRed':
      return c2DarkRed;
    case 'c2_navyBlue':
      return c2NavyBlue;
    case 'c2_darkBlue':
      return c2DarkBlue;
    case 'c2_paleYellow':
      return c2PaleYellow;
    case 'c2_lightYellow':
      return c2LightYellow;
    default:
      return const Color(0x00000000); // Transparent by default
  }
}
