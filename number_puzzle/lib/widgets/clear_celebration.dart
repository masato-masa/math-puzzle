import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// クリアしたときに盤の上へ一度だけ重ねる演出。
///
/// 盤面が空になった瞬間はいちばん気持ちのいい場面なのに、
/// これまでは結果ダイアログがすぐ出るだけで手応えが無かった。
/// 金色の輪と粒を短く弾けさせ、少し置いてからダイアログを出すことで
/// 「解けた」という手応えを挟む。
///
/// 演出そのものは操作を受け付けない（[IgnorePointer] で下に通す）。
class ClearCelebration extends StatefulWidget {
  const ClearCelebration({super.key, this.onFinished});

  /// 演出が終わったときに一度だけ呼ばれる。
  final VoidCallback? onFinished;

  @override
  State<ClearCelebration> createState() => _ClearCelebrationState();
}

class _ClearCelebrationState extends State<ClearCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward().whenComplete(() => widget.onFinished?.call());
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
        builder: (context, _) => CustomPaint(
          painter: _BurstPainter(_controller.value),
          child: Center(child: _label(_controller.value)),
        ),
      ),
    );
  }

  /// 「クリア！」の文字。少し遅れて現れ、わずかに拡大しながら定着する。
  Widget _label(double t) {
    const start = 0.18;
    if (t < start) return const SizedBox.shrink();
    final p = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
    return Opacity(
      opacity: Curves.easeOut.transform(math.min(1.0, p * 3)),
      child: Transform.scale(
        scale: 0.7 + 0.3 * eased,
        child: Text(
          'クリア！',
          style: AppTextStyles.display.copyWith(
            fontSize: 34,
            color: AppColors.gold,
            shadows: [
              const Shadow(color: AppColors.gold, blurRadius: 18),
              Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// 中心から広がる輪と、外へ飛ぶ粒。
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  /// 0.0 → 1.0 の進み具合。
  final double t;

  static const _particleCount = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.max(size.width, size.height) * 0.55;

    // 広がる輪を少しずつ時間をずらして 3 本。
    for (var i = 0; i < 3; i++) {
      final delay = i * 0.12;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final eased = Curves.easeOutCubic.transform(p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1 - eased) + 0.6
        ..color = AppColors.gold.withValues(alpha: (1 - eased) * 0.5);
      canvas.drawCircle(center, maxR * eased, paint);
    }

    // 外へ飛ぶ粒。終わりぎわに小さくなって消える。
    final pp = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * math.pi * 2;
      // 粒ごとに飛距離を散らして、機械的な放射に見えないようにする。
      final reach = maxR * (0.55 + 0.45 * ((i * 37) % 100) / 100);
      final d = reach * pp;
      final pos = center + Offset(math.cos(angle) * d, math.sin(angle) * d);
      final paint = Paint()
        ..color = AppColors.gold.withValues(alpha: fade * 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.2 * fade + 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
