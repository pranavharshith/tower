import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/td_game.dart';
import '../game/entities/tower.dart';

// â”€â”€ HUD Data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final hudProvider = NotifierProvider<HudNotifier, TdHudData>(HudNotifier.new);

class HudNotifier extends Notifier<TdHudData> {
  @override
  TdHudData build() {
    return const TdHudData(
      wave: 0,
      health: 40,
      maxHealth: 40,
      cash: 0,
      paused: true,
      healAmount: 0,
      healEffectTicks: 0,
      isBossWave: false,
    );
  }

  void updateData(TdHudData data) {
    state = data;
  }
}

// â”€â”€ Placing Type (which tower the user is placing) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final placingTypeProvider = NotifierProvider<PlacingTypeNotifier, TdTowerType?>(
  PlacingTypeNotifier.new,
);

class PlacingTypeNotifier extends Notifier<TdTowerType?> {
  @override
  TdTowerType? build() => null;

  void set(TdTowerType? t) => state = t;
}

// â”€â”€ Selection Revision counter (forces rebuild on selection change) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final selectionRevisionProvider =
    NotifierProvider<SelectionRevisionNotifier, int>(
      SelectionRevisionNotifier.new,
    );

class SelectionRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}
