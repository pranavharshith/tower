import 'dart:io';

void main() {
  final file = File('../towerdefense/scripts/maps.js');
  final content = file.readAsStringSync();
  final regex = RegExp(r"maps\.(\w+)\s*=\s*toMap\('([^']+)'\);");
  final matches = regex.allMatches(content);
  
  final buffer = StringBuffer();
  buffer.writeln("import 'dart:convert';");
  buffer.writeln("import 'package:lzstring/lzstring.dart';");
  buffer.writeln();
  buffer.writeln("class GameMap {");
  buffer.writeln("  final List<List<dynamic>> display;");
  buffer.writeln("  final List<List<dynamic>> displayDir;");
  buffer.writeln("  final List<List<int>> grid;");
  buffer.writeln("  final List<List<dynamic>> metadata;");
  buffer.writeln("  final List<List<int>> paths;");
  buffer.writeln("  final List<int> exit;");
  buffer.writeln("  final List<List<int>> spawnpoints;");
  buffer.writeln("  final List<int> bg;");
  buffer.writeln("  final int border;");
  buffer.writeln("  final int borderAlpha;");
  buffer.writeln("  final int cols;");
  buffer.writeln("  final int rows;");
  buffer.writeln();
  buffer.writeln("  GameMap({");
  buffer.writeln("    required this.display,");
  buffer.writeln("    required this.displayDir,");
  buffer.writeln("    required this.grid,");
  buffer.writeln("    required this.metadata,");
  buffer.writeln("    required this.paths,");
  buffer.writeln("    required this.exit,");
  buffer.writeln("    required this.spawnpoints,");
  buffer.writeln("    required this.bg,");
  buffer.writeln("    required this.border,");
  buffer.writeln("    required this.borderAlpha,");
  buffer.writeln("    required this.cols,");
  buffer.writeln("    required this.rows,");
  buffer.writeln("  });");
  buffer.writeln();
  buffer.writeln("  factory GameMap.fromString(String base64Str) {");
  buffer.writeln("    String? decoded = LZString.decompressFromBase64(base64Str);");
  buffer.writeln("    if (decoded == null) throw Exception('Failed to decode map');");
  buffer.writeln("    Map<String, dynamic> m = jsonDecode(decoded);");
  buffer.writeln();
  buffer.writeln("    return GameMap(");
  buffer.writeln("      display: List<List<dynamic>>.from(m['display'].map((x) => List<dynamic>.from(x))),");
  buffer.writeln("      displayDir: List<List<dynamic>>.from(m['displayDir'].map((x) => List<dynamic>.from(x))),");
  buffer.writeln("      grid: List<List<int>>.from(m['grid'].map((x) => List<int>.from(x))),");
  buffer.writeln("      metadata: List<List<dynamic>>.from(m['metadata'].map((x) => List<dynamic>.from(x))),");
  buffer.writeln("      paths: List<List<int>>.from(m['paths'].map((x) => List<int>.from(x))),");
  buffer.writeln("      exit: List<int>.from(m['exit']),");
  buffer.writeln("      spawnpoints: List<List<int>>.from(m['spawnpoints'].map((x) => List<int>.from(x))),");
  buffer.writeln("      bg: List<int>.from(m['bg']),");
  buffer.writeln("      border: m['border'],");
  buffer.writeln("      borderAlpha: m['borderAlpha'],");
  buffer.writeln("      cols: m['cols'],");
  buffer.writeln("      rows: m['rows'],");
  buffer.writeln("    );");
  buffer.writeln("  }");
  buffer.writeln("}");
  buffer.writeln();
  buffer.writeln("final Map<String, String> rawMaps = {");
  
  for (var match in matches) {
    buffer.writeln("  '${match.group(1)}': '${match.group(2)}',");
  }
  
  buffer.writeln("};");
  
  File('lib/game/maps.dart').writeAsStringSync(buffer.toString());
}
