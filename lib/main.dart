import 'package:flutter/material.dart';

import 'services/td_prefs.dart';
import 'ui/app_theme.dart';
import 'ui/td_entry_menu.dart';

void main() {
  runApp(MyApp(prefs: TdPrefs()));
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
