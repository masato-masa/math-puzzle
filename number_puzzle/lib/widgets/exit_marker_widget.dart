import 'package:flutter/material.dart';

import '../game/models.dart';
import '../theme/app_theme.dart';

/// 盤外に描く出口マーカー。受け付ける値（または範囲）を表示する。
/// 向きは盤の外周に置かれた位置そのもので分かるので矢印は出さない。
/// 「選択中タイル」「クリア」と同じ金色の言語を使い、
/// 「ここで行動できる」という合図を一貫させている。
class ExitMarkerWidget extends StatelessWidget {
  const ExitMarkerWidget({
    super.key,
    required this.exit,
    required this.ready,
    required this.onTap,
  });

  final ExitSpec exit;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE29A), AppColors.gold],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ground, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: ready ? 0.75 : 0.35),
              blurRadius: ready ? 12 : 6,
              spreadRadius: ready ? 1 : 0,
            ),
          ],
        ),
        child: Text(
          exit.label,
          style: const TextStyle(
            fontFamily: 'SFMono-Regular',
            fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
            color: AppColors.goldDeep,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
