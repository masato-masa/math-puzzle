import 'package:flutter/material.dart';

import '../game/direction.dart';
import '../theme/app_theme.dart';

/// 選択中のタイルが「その向きへ動いたらどうなるか」を盤の上に重ねて見せる。
///
/// ルールの中核（接する 2 辺のうち片方だけに演算子があるときだけ合体できる）は
/// 盤を見ただけでは読み取りにくく、試して初めて分かる状態だった。
/// 動かせる先・合体できる先をあらかじめ出すことで、
/// 「手を無駄にしないと確かめられない」状況を無くすのがねらい。
///
/// 計算後の値は出さない。数字を出すと「タイル本来の数字」なのか
/// 「計算した後の数字」なのか一見して区別がつかず、しかも床の色
/// （床の発光色は floor_cell_widget.dart 参照）と重なって見づらかった。
/// 計算自体は暗算できる範囲、あるいは実際に動かして確かめられる範囲に
/// とどめてあるので、先出しの数字が無くても支障は無い。
///
/// 出すのは移動先マスの枠と向きの矢印だけ。合体できる相手には何も
/// 重ねない（相手のマスにはタイルが載っているので、枠を重ねると
/// 数字が隠れるうえ、印の形によっては「そこへは行けない」という
/// 逆の意味に見えてしまう）。
class MoveDestinationMarker extends StatelessWidget {
  const MoveDestinationMarker({
    super.key,
    required this.cellSize,
    required this.direction,
  });

  final double cellSize;
  final Direction direction;

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
          child: Icon(
            _arrowFor(direction),
            size: cellSize * 0.26,
            color: AppColors.gold.withValues(alpha: 0.75),
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

/// ヒントで示された向きだけを、他の行き先プレビューと区別する飾り。
/// 中身（矢印や合体マーク）はそのまま、周りに脈打つ光の輪を足す。
class HintGlow extends StatefulWidget {
  const HintGlow({super.key, required this.cellSize, required this.child});

  final double cellSize;
  final Widget child;

  @override
  State<HintGlow> createState() => _HintGlowState();
}

class _HintGlowState extends State<HintGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value; // 0 -> 1 -> 0
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.cellSize * (0.7 + 0.16 * t),
                height: widget.cellSize * (0.7 + 0.16 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.8 - 0.5 * t),
                    width: 2,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

