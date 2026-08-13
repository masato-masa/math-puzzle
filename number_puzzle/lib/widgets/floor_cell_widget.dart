import 'package:flutter/material.dart';

import '../game/floor.dart';
import '../theme/app_theme.dart';

const Map<FloorKind, String> kFloorGlyph = {
  FloorKind.ice: '≈',
  FloorKind.rotate: '↻',
  FloorKind.swap: '⇄',
  FloorKind.sqrt: '√',
  FloorKind.fact: '!',
};

/// 床の発光色。タイルの辺の演算子（tile_widget.dart の operatorColor）と
/// 色相を揃えてある ―― 氷=寒色、辺を変える床=紫、値を変える床=琥珀。
Color floorColor(FloorKind kind) => switch (kind) {
      FloorKind.ice => AppColors.cyan,
      FloorKind.rotate || FloorKind.swap => AppColors.violet,
      FloorKind.sqrt || FloorKind.fact => AppColors.amber,
    };

/// マスの背景（壁・床）。タイルより下のレイヤーに敷く。
class FloorCellWidget extends StatelessWidget {
  const FloorCellWidget({
    super.key,
    required this.cellSize,
    this.isWall = false,
    this.floor,
    this.usesLeft,
  });

  final double cellSize;
  final bool isWall;
  final FloorKind? floor;
  final int? usesLeft;

  @override
  Widget build(BuildContext context) {
    if (isWall) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.wallHighlight, AppColors.wallBody],
            stops: [0.0, 0.6],
          ),
          border: Border(
            top: const BorderSide(color: AppColors.wallRim, width: 1.4),
            left: BorderSide(color: AppColors.wallRim.withValues(alpha: 0.55), width: 1.4),
            right: const BorderSide(color: AppColors.wallShadow, width: 1.4),
            bottom: const BorderSide(color: AppColors.wallShadow, width: 1.4),
          ),
          boxShadow: [
            BoxShadow(color: AppColors.wallRim.withValues(alpha: 0.12), blurRadius: 6),
          ],
        ),
      );
    }
    if (floor == null) return const SizedBox.shrink();

    final spent = usesLeft != null && usesLeft! <= 0;
    final color = floorColor(floor!);
    final glowAlpha = spent ? 0.06 : 0.22;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color.withValues(alpha: glowAlpha), Colors.transparent],
          radius: 0.85,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: spent ? 0.3 : 0.95,
              child: Text(
                kFloorGlyph[floor] ?? '?',
                style: TextStyle(
                  fontSize: cellSize * 0.32,
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(color, Colors.white, 0.25),
                  shadows: spent ? null : [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8)],
                ),
              ),
            ),
          ),
          if (usesLeft != null)
            Positioned(
              right: cellSize * 0.06,
              bottom: cellSize * 0.02,
              child: Opacity(
                opacity: spent ? 0.35 : 0.9,
                child: Text(
                  '$usesLeft',
                  style: TextStyle(
                    fontFamily: 'SFMono-Regular',
                    fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
                    fontWeight: FontWeight.w700,
                    fontSize: cellSize * 0.16,
                    color: Color.lerp(color, Colors.white, 0.25),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
