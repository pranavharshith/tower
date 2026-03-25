import 'dart:io';

void main() {
  final dir = Directory('test');
  if (!dir.existsSync()) return;

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    if (content.contains('package:flutter_tower/game/entities/entities.dart') ||
        content.contains('import \'../lib/game/entities/entities.dart\';')) {
      continue;
    }

    final importStr =
        "import 'package:flutter_tower/game/entities/entities.dart';";

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
