// 生成物。直接編集しない。出どころは C:\claude\shared-ui\tool-icons.mjs。

import 'package:flutter/widgets.dart';

/// 盤面の下のツール行に置くアイコン。4 つのゲームで同じ形を使う。
enum ToolIconKind { undo, reset, hint }

/// 24x24 で描いた線画を、渡された大きさと色で描く。
class ToolIcon extends StatelessWidget {
  const ToolIcon({super.key, required this.kind, required this.color, this.size = 28});

  final ToolIconKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ToolIconPainter(kind: kind, color: color),
    );
  }
}

class _ToolIconPainter extends CustomPainter {
  _ToolIconPainter({required this.kind, required this.color});

  final ToolIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 24 の枠で描いてから拡げる。線幅もいっしょに拡がるので、
    // どの大きさでも線の太さの比が変わらない。
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      _path(kind),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  static Path _path(ToolIconKind kind) {
    switch (kind) {
      /// もどす
      case ToolIconKind.undo:
        return Path()
      ..moveTo(9, 14)
      ..lineTo(4, 9)
      ..relativeLineTo(5, -5)
      ..moveTo(4, 9)
      ..relativeLineTo(11, 0)
      ..relativeArcToPoint(const Offset(0, 10), radius: const Radius.circular(5), largeArc: false, clockwise: true)
      ..relativeLineTo(-4, 0);
      /// やり直す
      case ToolIconKind.reset:
        return Path()
      ..moveTo(21, 12)
      ..relativeArcToPoint(const Offset(-3, -6.7), radius: const Radius.circular(9), largeArc: true, clockwise: true)
      ..moveTo(21, 3)
      ..relativeLineTo(0, 6)
      ..relativeLineTo(-6, 0);
      /// ヒント
      case ToolIconKind.hint:
        return Path()
      ..moveTo(9, 18)
      ..relativeLineTo(6, 0)
      ..moveTo(10, 22)
      ..relativeLineTo(4, 0)
      ..moveTo(12, 2)
      ..relativeArcToPoint(const Offset(-4, 12.7), radius: const Radius.circular(7), largeArc: false, clockwise: false)
      ..lineTo(8, 18)
      ..relativeLineTo(8, 0)
      ..relativeLineTo(0, -3.3)
      ..arcToPoint(const Offset(12, 2), radius: const Radius.circular(7), largeArc: false, clockwise: false)
      ..close();
    }
  }

  @override
  bool shouldRepaint(_ToolIconPainter old) => old.kind != kind || old.color != color;
}
