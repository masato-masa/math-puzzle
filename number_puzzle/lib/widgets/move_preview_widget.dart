import 'package:flutter/material.dart';

import '../game/direction.dart';
import '../theme/app_theme.dart';

/// 選択中のタイルが「その向きへ動いたらどうなるか」を盤の上に重ねて見せる。
///
/// ルールの中核（接する 2 辺のうち片方だけに演算子があるときだけ合体できる）は
/// 盤を見ただけでは読み取りにくく、試して初めて分かる状態だった。
/// 動かせる先と、合体したときの結果をあらかじめ出すことで、
/// 「手を無駄にしないと確かめられない」状況を無くすのがねらい。
///
/// 表示は 2 種類:
///  - 移動先マス … 角の枠と中央のドット。値が変わる床なら変化後の値も出す。
///  - 合体先タイル … 結果の値を金色のふきだしで相手タイルの上に出す。
class MoveDestinationMarker extends StatelessWidget {
  const MoveDestinationMarker({
    super.key,
    required this.cellSize,
    required this.direction,
    this.newValue,
  });

  final double cellSize;
  final Direction direction;

  /// 床の効果で値が変わる場合の変化後の値（変わらないなら null）。
  final int? newValue;

  @override
  Widget build(BuildContext context) {
    final inset = cellSize * 0.16;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cellSize * 0.12),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.6,
            ),
            color: AppColors.gold.withValues(alpha: 0.07),
          ),
          alignment: Alignment.center,
          child: newValue == null
              ? Icon(
                  _arrowFor(direction),
                  size: cellSize * 0.26,
                  color: AppColors.gold.withValues(alpha: 0.75),
                )
              : FittedBox(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: cellSize * 0.06),
                    child: Text(
                      '$newValue',
                      style: TextStyle(
                        fontFamily: 'SFMono-Regular',
                        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
                        fontWeight: FontWeight.w800,
                        fontSize: cellSize * 0.3,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  IconData _arrowFor(Direction d) => switch (d) {
        Direction.up => Icons.keyboard_arrow_up,
        Direction.down => Icons.keyboard_arrow_down,
        Direction.left => Icons.keyboard_arrow_left,
        Direction.right => Icons.keyboard_arrow_right,
      };
}

/// 合体したときの結果を、相手タイルの上に金色のふきだしで出す。
class MergeResultBadge extends StatelessWidget {
  const MergeResultBadge({
    super.key,
    required this.cellSize,
    required this.value,
  });

  final double cellSize;
  final int value;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: cellSize * 0.12,
            vertical: cellSize * 0.05,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE29A), AppColors.gold],
            ),
            borderRadius: BorderRadius.circular(cellSize * 0.18),
            border: Border.all(color: AppColors.ground, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.7),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontFamily: 'SFMono-Regular',
              fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
              fontWeight: FontWeight.w800,
              fontSize: cellSize * 0.28,
              color: AppColors.goldDeep,
            ),
          ),
        ),
      ),
    );
  }
}
