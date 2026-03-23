import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_tower/ui/widgets/game_hud_widgets.dart';

void main() {
  group('HudItem Widget Tests', () {
    testWidgets('Displays text and values correctly when showLabel is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HudItem(
                icon: Icons.attach_money,
                iconColor: Colors.yellow,
                value: '\$150',
                label: 'Cash',
                showLabel: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('\$150'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('Hides label text when showLabel is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HudItem(
                icon: Icons.favorite,
                iconColor: Colors.red,
                value: '10/10',
                label: 'Health',
                showLabel: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('Health'), findsNothing);
    });
  });
}
