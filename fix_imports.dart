import 'dart:io';

void main() {
  final files = [
    'lib/game/collision_detector.dart',
    'lib/game/enemy_manager.dart',
    'lib/game/game_renderer.dart',
    'lib/game/pathfinding_service.dart',
    'lib/game/td_game.dart',
    'lib/game/tower_manager.dart',
    'lib/providers/game_providers.dart',
    'lib/ui/widgets/game_hud_widgets.dart',
    'lib/ui/widgets/tower_stats_modal.dart',
    'lib/ui/widgets/tower_store_bar.dart',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    if (content.contains('import \'entities/entities.dart\';') ||
        content.contains('import \'../game/entities/entities.dart\';')) {
      continue;
    }

    final importStr =
        path.startsWith('lib/ui') || path.startsWith('lib/providers')
        ? "import '../game/entities/entities.dart';"
        : "import 'entities/entities.dart';";

    final lines = content.split('\n');
    int lastImportIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('import ')) {
        lastImportIdx = i;
      }
    }

    if (lastImportIdx != -1) {
      lines.insert(lastImportIdx + 1, importStr);
    } else {
      lines.insert(0, importStr);
    }

    file.writeAsStringSync(lines.join('\n'));
  }
}
