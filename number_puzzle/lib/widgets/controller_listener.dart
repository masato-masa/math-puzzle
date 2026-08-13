import 'package:flutter/widgets.dart';

import '../game/game_controller.dart';

/// AnimatedBuilder の代わり。GameController が package:flutter の
/// Listenable を実装していない（game/ 層を Flutter 非依存の純粋 Dart に
/// 保つため、dart:ui に依存する ChangeNotifier を使っていない）ので、
/// 同じ役割の購読ウィジェットを自前で用意している。
class ControllerListener extends StatefulWidget {
  const ControllerListener({
    super.key,
    required this.controller,
    required this.builder,
  });

  final GameController controller;
  final WidgetBuilder builder;

  @override
  State<ControllerListener> createState() => _ControllerListenerState();
}

class _ControllerListenerState extends State<ControllerListener> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant ControllerListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
