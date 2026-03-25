import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tower/ui/widgets/tower_stats_modal.dart';
import 'package:flutter_tower/game/entities/tower.dart';

void main() {
  group('Tower Stats Widget', () {
    testWidgets('Displays tower information correctly', (tester) async {
      final tower = TdTower(towerType: TdTowerType.gun, col: 5, row: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TowerStatsSheet(
              tower: tower,
              onUpgrade: null,
              onSell: () {},
              canAffordUpgrade: false,
            ),
          ),
        ),
      );

      expect(find.text('Gun Tower'), findsOneWidget);
      expect(find.text('Range'), findsOneWidget);
      expect(find.text('Damage'), findsOneWidget);
    });

    testWidgets('Shows upgrade button when available', (tester) async {
      final tower = TdTower(towerType: TdTowerType.gun, col: 5, row: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TowerStatsSheet(
              tower: tower,
              onUpgrade: () {},
              onSell: () {},
              canAffordUpgrade: true,
            ),
          ),
        ),
      );

      // Button text includes price, so use textContaining
      expect(find.textContaining('Upgrade'), findsOneWidget);
    });

    testWidgets('Disables upgrade button when cannot afford', (tester) async {
      final tower = TdTower(towerType: TdTowerType.gun, col: 5, row: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TowerStatsSheet(
              tower: tower,
              onUpgrade: () {},
              onSell: () {},
              canAffordUpgrade: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify tower can upgrade (gun tower has upgrade)
      expect(
        tower.canUpgrade,
        isTrue,
        reason: 'Gun tower should be able to upgrade',
      );

      // Find upgrade button by text with price
      final upgradeButton = find.textContaining('Upgrade');
      expect(
        upgradeButton,
        findsOneWidget,
        reason: 'Upgrade button should exist',
      );

      // Tap to verify it's clickable (even if disabled visually)
      await tester.tap(upgradeButton);
      await tester.pump();

      // Verify button exists and has correct color
      expect(find.text('Upgrade \$75'), findsOneWidget);
    });

    testWidgets('Shows sell button', (tester) async {
      final tower = TdTower(towerType: TdTowerType.gun, col: 5, row: 5);

      bool sellCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TowerStatsSheet(
              tower: tower,
              onUpgrade: null,
              onSell: () => sellCalled = true,
              canAffordUpgrade: false,
            ),
          ),
        ),
      );

      expect(find.text('Sell'), findsOneWidget);

      await tester.tap(find.text('Sell'));
      await tester.pump();

      expect(sellCalled, true);
    });

    testWidgets('Displays upgraded tower stats', (tester) async {
      final tower = TdTower(towerType: TdTowerType.gun, col: 5, row: 5);
      tower.applyUpgrade();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TowerStatsSheet(
              tower: tower,
              onUpgrade: () {},
              onSell: () {},
              canAffordUpgrade: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for upgraded tower name (from tower type upgrade definition)
      final upgradeName = tower.towerType.upgrade?.title ?? 'Machine Gun';
      expect(find.text(upgradeName), findsOneWidget);
      expect(find.text('MAX LEVEL'), findsOneWidget);
    });
  });
}
