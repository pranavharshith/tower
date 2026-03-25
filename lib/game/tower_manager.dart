import '../data/td_maps.dart';
import '../core/validators/input_validator.dart';
import 'td_simulation.dart';
import 'entities/entities.dart';

/// Manages tower lifecycle, placement, upgrades, and attacks
/// Extracted from TdSim for better separation of concerns
class TowerManager {
  final TdMapData baseMap;

  // Tower list
  final List<TdTower> towers = [];

  // Tower limit
  static const int maxTowers = 21;

  TowerManager({required this.baseMap});

  /// Clear all towers (for game reset)
  void clear() {
    towers.clear();
  }

  /// Get tower at grid position
  TdTower? getTowerAt(int col, int row) {
    for (final t in towers) {
      if (t.col == col && t.row == row) return t;
    }
    return null;
  }

  /// Check if tower exists at position
  bool hasTowerAt(int col, int row) => getTowerAt(col, row) != null;

  /// Check if tower limit reached
  bool get maxTowersReached => towers.length >= maxTowers;

  /// Check if tower can be placed at position
  bool canPlaceTower({
    required TdTowerType towerType,
    required int col,
    required int row,
    required List<List<int>> grid,
    required List<TdCoord> spawnpoints,
    required TdCoord exit,
    required List<dynamic> enemies,
    required bool Function(int col, int row) isPlaceable,
  }) {
    // Input validation using centralized validator
    if (!InputValidator.isValidPosition(
      col,
      row,
      grid.length,
      grid[0].length,
    )) {
      return false;
    }

    // Check tower limit
    if (towers.length >= maxTowers) return false;

    // Check if an enemy is currently on this tile
    for (final e in enemies) {
      final enemy = e as TdEnemy;
      if (enemy.gridCol == col && enemy.gridRow == row) {
        return false; // Can't place tower on enemy position
      }
    }

    // Check grid constraints
    final g = grid[col][row];
    if (g == 3) return true;
    if (g == 1 || g == 2 || g == 4) return false;

    // Check if tile is empty
    if (!_emptyTile(col, row, grid, spawnpoints, exit)) return false;

    // Check if placement blocks paths
    if (!isPlaceable(col, row)) return false;

    return true;
  }

  /// Place tower at position
  void placeTower({
    required TdTowerType towerType,
    required int col,
    required int row,
    required List<dynamic> enemies,
    required Function() onRecalculate,
  }) {
    final tower = TdTower(towerType: towerType, col: col, row: row);
    towers.add(tower);

    // Kill any enemies that are currently on this tile or moving through it
    // This prevents enemies from getting stuck when a tower is placed
    for (int i = (enemies.length - 1); i >= 0; i--) {
      final e = enemies[i] as TdEnemy;
      // Check if enemy is on this tile (within the tile boundaries)
      if (e.gridCol == col && e.gridRow == row) {
        e.kill();
        enemies.removeAt(i);
      }
    }

    onRecalculate();
  }

  /// Sell tower and return cash
  int sellTower(TdTower tower) {
    final idx = towers.indexOf(tower);
    if (idx == -1) return 0;

    final sellPrice = tower.sellPrice();
    towers.removeAt(idx);
    return sellPrice;
  }

  /// Upgrade tower
  bool upgradeTower({
    required TdTower tower,
    required int upgradeCost,
    required int currentCash,
  }) {
    if (!tower.canUpgrade) return false;
    if (currentCash < upgradeCost) return false;

    // Apply the upgrade
    tower.applyUpgrade();
    return true;
  }

  /// Update all towers (targeting and cooldowns)
  void updateTowers({required TdSim sim, required bool paused}) {
    if (paused) return;

    // Target and fire
    for (final t in towers) {
      t.tryFire(sim);
    }

    // Update cooldowns
    for (final t in towers) {
      t.updateCooldown();
    }
  }

  /// Check if tile is empty (helper method)
  bool _emptyTile(
    int col,
    int row,
    List<List<int>> grid,
    List<TdCoord> spawnpoints,
    TdCoord exit,
  ) {
    if (!_walkableForPlacement(col, row, grid)) return false;
    for (final s in spawnpoints) {
      if (s.x == col && s.y == row) return false;
    }
    if (exit.x == col && exit.y == row) return false;
    return true;
  }

  /// Check if tile is walkable for placement (helper method)
  bool _walkableForPlacement(int col, int row, List<List<int>> grid) {
    final g = grid[col][row];
    // Grid value 0 and 2 are buildable
    // 0 = Empty (buildable)
    // 1 = Wall/Scenery (blocked)
    // 2 = Enemy Path (buildable, but path will recalculate when tower placed)
    // 3 = Water/Void (blocked for building, enemies can't walk here)
    if (g == 1 || g == 3) return false;
    if (hasTowerAt(col, row)) return false;
    return true;
  }
}

