import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/td_maps.dart';
import '../game/td_game.dart';
import '../services/td_prefs.dart';
import 'app_theme.dart';
import 'td_game_page.dart';

class TdMapSelectPage extends StatefulWidget {
  final TdPrefs prefs;
  const TdMapSelectPage({super.key, required this.prefs});

  @override
  State<TdMapSelectPage> createState() => _TdMapSelectPageState();
}

class _TdMapSelectPageState extends State<TdMapSelectPage> {
  late String _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = TdMaps.options.first.key;
    // Match web version: sparse2 selected by default.
    for (final o in TdMaps.options) {
      if (o.key == 'sparse2') _selectedKey = o.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = TdMaps.options;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'Select Map',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options[index];
                  final isSelected = opt.key == _selectedKey;
                  return _MapCard(
                    option: opt,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedKey = opt.key),
                  );
                },
              ),
            ),
            // Play Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                boxShadow: AppTheme.softShadow,
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final stretch = await widget.prefs.getStretchMode();
                      final settings = TdGameSettings(stretchMode: stretch);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TdGamePage(
                            prefs: widget.prefs,
                            mapKey: _selectedKey,
                            settings: settings,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      elevation: 4,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final MapOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: isSelected
              ? Border.all(color: AppTheme.primary, width: 3)
              : null,
          boxShadow: isSelected ? AppTheme.mediumShadow : AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Preview
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.gridBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: _MiniMapPreview(option: option),
              ),
            ),
            // Map Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.label,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (option.isRandom)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryLight,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          'Random',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          'Premade',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  final MapOption option;

  const _MiniMapPreview({required this.option});

  @override
  Widget build(BuildContext context) {
    // Generate a stylized mini-grid preview based on map type
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = 8;
        final rows = 8;
        final cellWidth = constraints.maxWidth / cols;
        final cellHeight = constraints.maxHeight / rows;

        return Stack(
          children: [
            // Grid background
            Container(
              decoration: BoxDecoration(
                color: AppTheme.gridBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            // Grid lines
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _GridPainter(cols: cols, rows: rows),
            ),
            // Path preview based on map name
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PathPainter(mapKey: option.key, cols: cols, rows: rows),
            ),
            // Spawn and exit markers
            if (_showMarkers(option.key))
              ..._buildMarkers(cellWidth, cellHeight),
          ],
        );
      },
    );
  }

  bool _showMarkers(String key) {
    // Show markers for premade maps
    return !option.isRandom;
  }

  List<Widget> _buildMarkers(double cellWidth, double cellHeight) {
    return [
      // Exit (red)
      Positioned(
        right: 0,
        bottom: cellHeight * 3,
        child: Container(
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: AppTheme.coral.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      // Spawn (green)
      Positioned(
        left: 0,
        top: cellHeight * 3,
        child: Container(
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ];
  }
}

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;

  // Cache paint object
  static final Paint _gridPaint = Paint()
    ..color = AppTheme.gridLine
    ..strokeWidth = 0.5;

  _GridPainter({required this.cols, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // Draw vertical lines
    for (int i = 0; i <= cols; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }

    // Draw horizontal lines
    for (int i = 0; i <= rows; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathPainter extends CustomPainter {
  final String mapKey;
  final int cols;
  final int rows;

  // Cache paint object
  static final Paint _pathPaint = Paint()
    ..color = AppTheme.pathTile
    ..style = PaintingStyle.fill;

  _PathPainter({required this.mapKey, required this.cols, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // Draw different path patterns based on map type
    final pathCells = _getPathCells();

    for (final cell in pathCells) {
      final rect = Rect.fromLTWH(
        cell.col * cellWidth,
        cell.row * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, _pathPaint);
    }
  }

  List<_Cell> _getPathCells() {
    // Generate accurate path patterns based on actual map layouts
    switch (mapKey) {
      case 'loops':
        // Loops map: Multiple circular paths
        return _generateLoopPath();
      case 'branch':
        // Branch map: Single path that splits into two branches
        return _generateBranchPath();
      case 'city':
        // City map: Grid-like streets with turns
        return _generateCityPath();
      case 'freeway':
        // Freeway: Long straight highway-style path
        return _generateFreewayPath();
      case 'walls':
        // Walls: Maze-like path with many walls
        return _generateWallsPath();
      case 'fork':
        // Fork: Path splits into two separate routes
        return _generateForkPath();
      case 'dualU':
        // Dual-U: Two U-shaped corridors
        return _generateDualUPath();
      case 'empty2':
      case 'empty3':
        // Empty maps: No walls, just open space
        return _generateEmptyPath();
      case 'sparse2':
      case 'sparse3':
        // Sparse: Few scattered walls (10% coverage)
        return _generateSparsePath();
      case 'dense2':
      case 'dense3':
        // Dense: Many walls (20% coverage)
        return _generateDensePath();
      case 'solid2':
        // Solid: Very dense walls (30% coverage)
        return _generateSolidPath();
      default:
        return _generateSimplePath();
    }
  }

  List<_Cell> _generateLoopPath() {
    return [
      // Outer loop
      _Cell(0, 3), _Cell(1, 3), _Cell(2, 3), _Cell(3, 3),
      _Cell(3, 2), _Cell(3, 1), _Cell(4, 1), _Cell(5, 1),
      _Cell(5, 2), _Cell(5, 3), _Cell(6, 3), _Cell(7, 3),
    ];
  }

  List<_Cell> _generateBranchPath() {
    return [
      _Cell(0, 2),
      _Cell(1, 2),
      _Cell(2, 2),
      _Cell(3, 2),
      _Cell(3, 3),
      _Cell(3, 4),
      _Cell(0, 6),
      _Cell(1, 6),
      _Cell(2, 6),
      _Cell(3, 6),
      _Cell(4, 6),
      _Cell(5, 6),
      _Cell(6, 6),
      _Cell(7, 6),
    ];
  }

  List<_Cell> _generateCityPath() {
    return [
      _Cell(0, 1),
      _Cell(1, 1),
      _Cell(2, 1),
      _Cell(3, 1),
      _Cell(3, 2),
      _Cell(3, 3),
      _Cell(4, 3),
      _Cell(5, 3),
      _Cell(5, 4),
      _Cell(5, 5),
      _Cell(6, 5),
      _Cell(7, 5),
    ];
  }

  List<_Cell> _generateFreewayPath() {
    return [
      _Cell(0, 3),
      _Cell(1, 3),
      _Cell(2, 3),
      _Cell(3, 3),
      _Cell(4, 3),
      _Cell(5, 3),
      _Cell(6, 3),
      _Cell(7, 3),
    ];
  }

  List<_Cell> _generateWallsPath() {
    return [
      _Cell(0, 2),
      _Cell(1, 2),
      _Cell(2, 2),
      _Cell(2, 3),
      _Cell(2, 4),
      _Cell(2, 5),
      _Cell(3, 5),
      _Cell(4, 5),
      _Cell(5, 5),
      _Cell(5, 4),
      _Cell(5, 3),
      _Cell(5, 2),
      _Cell(6, 2),
      _Cell(7, 2),
    ];
  }

  List<_Cell> _generateForkPath() {
    return [
      _Cell(0, 4),
      _Cell(1, 4),
      _Cell(2, 4),
      _Cell(3, 4),
      _Cell(3, 3),
      _Cell(3, 2),
      _Cell(4, 2),
      _Cell(5, 2),
      _Cell(3, 5),
      _Cell(3, 6),
      _Cell(4, 6),
      _Cell(5, 6),
      _Cell(6, 2),
      _Cell(6, 6),
      _Cell(7, 2),
      _Cell(7, 6),
    ];
  }

  List<_Cell> _generateDualUPath() {
    // Dual-U: Two U-shaped corridors
    return [
      // Upper U
      _Cell(1, 1),
      _Cell(2, 1),
      _Cell(3, 1),
      _Cell(4, 1),
      _Cell(5, 1),
      _Cell(6, 1),
      _Cell(1, 2), _Cell(1, 3),
      _Cell(6, 2), _Cell(6, 3),
      // Lower U
      _Cell(1, 5),
      _Cell(2, 5),
      _Cell(3, 5),
      _Cell(4, 5),
      _Cell(5, 5),
      _Cell(6, 5),
      _Cell(1, 6), _Cell(1, 7),
      _Cell(6, 6), _Cell(6, 7),
      // Center connector
      _Cell(3, 3), _Cell(3, 4), _Cell(4, 3), _Cell(4, 4),
      _Cell(7, 3), _Cell(7, 4),
    ];
  }

  List<_Cell> _generateSimplePath() {
    return [
      _Cell(0, 4),
      _Cell(1, 4),
      _Cell(2, 4),
      _Cell(3, 4),
      _Cell(4, 4),
      _Cell(5, 4),
      _Cell(6, 4),
      _Cell(7, 4),
    ];
  }

  List<_Cell> _generateEmptyPath() {
    // Empty map: Simple straight path across middle
    return [
      _Cell(0, 4),
      _Cell(1, 4),
      _Cell(2, 4),
      _Cell(3, 4),
      _Cell(4, 4),
      _Cell(5, 4),
      _Cell(6, 4),
      _Cell(7, 4),
    ];
  }

  List<_Cell> _generateSparsePath() {
    // Sparse: Simple path with a few scattered walls shown
    return [
      _Cell(0, 3),
      _Cell(1, 3),
      _Cell(2, 3),
      _Cell(3, 3),
      _Cell(3, 4),
      _Cell(4, 4),
      _Cell(5, 4),
      _Cell(6, 4),
      _Cell(7, 4),
    ];
  }

  List<_Cell> _generateDensePath() {
    // Dense: Winding path to show more walls
    return [
      _Cell(0, 2),
      _Cell(1, 2),
      _Cell(2, 2),
      _Cell(2, 3),
      _Cell(2, 4),
      _Cell(3, 4),
      _Cell(4, 4),
      _Cell(5, 4),
      _Cell(5, 5),
      _Cell(6, 5),
      _Cell(7, 5),
    ];
  }

  List<_Cell> _generateSolidPath() {
    // Solid: Very winding path showing heavy wall coverage
    return [
      _Cell(0, 1),
      _Cell(1, 1),
      _Cell(1, 2),
      _Cell(1, 3),
      _Cell(2, 3),
      _Cell(3, 3),
      _Cell(3, 4),
      _Cell(3, 5),
      _Cell(4, 5),
      _Cell(5, 5),
      _Cell(6, 5),
      _Cell(6, 6),
      _Cell(7, 6),
    ];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Cell {
  final int col;
  final int row;
  _Cell(this.col, this.row);
}
