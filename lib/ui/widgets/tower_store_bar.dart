import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../game/td_game.dart';
import '../app_theme.dart';
import 'game_hud_widgets.dart';
import '../../game/entities/tower.dart';

class TowerStoreBar extends StatelessWidget {
  final TdGame game;
  final Function(TdTowerType) onTowerSelected;
  final Function() onMaxTowersReached;

  const TowerStoreBar({
    super.key,
    required this.game,
    required this.onTowerSelected,
    required this.onMaxTowersReached,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.mediumShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildStoreTitle(), _buildTowerList(context)],
        ),
      ),
    );
  }

  Widget _buildStoreTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Row(
        children: [
          Icon(Icons.store_rounded, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            'Tower Store',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTowerList(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ValueListenableBuilder<TdHudData>(
        valueListenable: game.hud,
        builder: (context, hud, _) {
          return ValueListenableBuilder<int>(
            valueListenable: game.selectionRevision,
            builder: (context, _, __) {
              final placing = game.placingType;
              final selected = game.selectedTower;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: towerTypes.length,
                itemBuilder: (context, index) {
                  final key = towerTypes.keys.elementAt(index);
                  final t = towerTypes[key]!;
                  final isActive =
                      placing?.key == t.key || selected?.towerType.key == t.key;
                  final canAfford = hud.cash >= t.cost;
                  final maxedOut = hud.maxTowersReached;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: TowerStoreItem(
                      towerType: t,
                      isActive: isActive,
                      isDisabled: !canAfford || maxedOut,
                      onTap: () {
                        if (maxedOut) {
                          onMaxTowersReached();
                          return;
                        }

                        if (placing?.key == t.key) {
                          game.cancelPendingTower();
                        } else {
                          game.startPlacingTower(t);
                          onTowerSelected(t);
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
