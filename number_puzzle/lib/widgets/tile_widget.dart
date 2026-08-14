import 'package:flutter/material.dart';

import '../game/direction.dart';
import '../game/edges.dart';
import '../theme/app_theme.dart';

/// 演算子の色ファミリー。床の発光色（floor_cell_widget.dart）と対応させてある
/// ―― 同じ色相なら「同じ仲間の効果」だと直感的に分かるようにするため。
Color operatorColor(String op) => switch (op) {
      '+' => AppColors.cyan,
      '−' => AppColors.magenta,
      '×' => AppColors.amber,
      '÷' => AppColors.violet,
      _ => AppColors.textMuted,
    };

/// 盤面上のタイル本体。黒曜石の板をイメージした面取り＋艶のグラデーションで、
/// 辺に演算子があれば発光する小さな宝石として外周に載せる。
///
/// タップ判定は持たない（セル側の GestureDetector と重なって競合するのを
/// 避けるため、タップは PuzzleBoard がセル単位で一元的に処理する）。
class TileWidget extends StatelessWidget {
  const TileWidget({
    super.key,
    required this.value,
    required this.edges,
    required this.fixed,
    required this.selected,
    required this.cellSize,
    this.opacity = 1.0,
  });

  final int value;
  final Edges edges;
  final bool fixed;
  final bool selected;
  final double cellSize;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final inset = cellSize * 0.13;
    final radius = cellSize * 0.16;

    final body = Container(
      margin: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: fixed
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.tileTop, AppColors.tileBottom],
              ),
        color: fixed ? AppColors.tileFixed : null,
        // 枠線は全辺同じ色にする。角丸と「辺ごとに違う色の枠線」は
        // 併用できず描画時に弾かれるため（リリースビルドでは
        // アサーションが無効なので今まで表面化していなかった）、
        // 面取りの陰影は下の foregroundDecoration で表現している。
        border: Border.all(
          color: Colors.white.withValues(alpha: fixed ? 0.07 : 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          if (selected)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.65),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
      ),
      // 左上を明るく、右下を暗く落として面取りブロックに見せる。
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: fixed ? 0.06 : 0.11),
            Colors.transparent,
            Colors.black.withValues(alpha: fixed ? 0.18 : 0.30),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: AppTextStyles.tile.copyWith(
          fontSize: _fontSizeFor(value, cellSize),
          color: fixed ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ),
    );

    return Opacity(
      opacity: opacity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius + 3),
              border: Border.all(
                color: selected ? AppColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
            child: body,
          ),
          for (final d in kAllDirections)
            if (edges[d] != null) _edgeGem(d, cellSize, edges[d]!),
        ],
      ),
    );
  }

  double _fontSizeFor(int value, double cellSize) {
    final len = '$value'.length;
    final base = cellSize * 0.42;
    final byLength = cellSize * 0.9 / len;
    return base < byLength ? base : byLength;
  }

  Widget _edgeGem(Direction d, double cellSize, String op) {
    final size = cellSize * 0.28;
    final color = operatorColor(op);
    final style = TextStyle(
      fontFamily: 'SFMono-Regular',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      fontWeight: FontWeight.w800,
      fontSize: size * 0.6,
      color: AppColors.ground,
    );
    final gem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.85), blurRadius: 7, spreadRadius: 0.5),
        ],
      ),
      alignment: Alignment.center,
      child: Text(op, style: style),
    );

    // 辺の外へはみ出させない（= size * 0 が境界ぴったり）。隣のタイルにも
    // 同じ向きの宝石があるとき、互いのタイル領域を侵さないので重ならない。
    const inset = 0.10;
    return switch (d) {
      Direction.up => Positioned(top: size * inset, left: 0, right: 0, child: Center(child: gem)),
      Direction.down => Positioned(bottom: size * inset, left: 0, right: 0, child: Center(child: gem)),
      Direction.left => Positioned(left: size * inset, top: 0, bottom: 0, child: Center(child: gem)),
      Direction.right => Positioned(right: size * inset, top: 0, bottom: 0, child: Center(child: gem)),
    };
  }
}
