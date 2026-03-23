import 'package:flutter/material.dart';

import 'services/td_prefs.dart';
import 'ui/app_theme.dart';
import 'ui/td_entry_menu.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = TdPrefs();
  await prefs.init();

  runApp(
    ProviderScope(
      child: MyApp(prefs: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final TdPrefs prefs;
  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tower Defense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: TdEntryMenu(prefs: prefs),
    );
  }
}
