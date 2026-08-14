import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/models.dart';
import '../services/progress_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clear_celebration.dart';
import '../widgets/controller_listener.dart';
import '../widgets/puzzle_board.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.level,
    required this.soundService,
    required this.progressService,
    this.onNextLevel,
  });

  final Level level;
  final SoundService soundService;
  final ProgressService progressService;
  final VoidCallback? onNextLevel;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late GameController _controller;
  bool _dialogShown = false;

  /// クリア演出を出している間 true。演出が終わってから結果を出す。
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController(widget.level)..onSound = widget.soundService.playEvent;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_dialogShown) return;
    if (_controller.isCleared) {
      _dialogShown = true;
      widget.progressService.recordClear(widget.level.levelId, _controller.moveCount);
      // 演出を挟んでから結果を出す（[_onCelebrationFinished] で続く）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _celebrating = true);
      });
    } else if (_controller.isFailed) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFailDialog());
    }
  }

  void _onCelebrationFinished() {
    if (!mounted) return;
    setState(() => _celebrating = false);
    _showClearDialog();
  }

  void _restart() {
    setState(() {
      _dialogShown = false;
      _celebrating = false;
      _controller.restart();
    });
  }

  void _undoAndClearDialog() {
    setState(() {
      _dialogShown = false;
      _celebrating = false;
      _controller.undo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.level.title)),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _Hud(controller: _controller, onUndo: () {
                    setState(() => _dialogShown = false);
                    _controller.undo();
                  }, onReset: _restart),
                  const SizedBox(height: 4),
                  if (widget.level.hint.isNotEmpty)
                    Text(widget.level.hint,
                        style: AppTextStyles.caption, textAlign: TextAlign.center),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: PuzzleBoard(controller: _controller),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 22,
                    child: ControllerListener(
                      controller: _controller,
                      builder: (context) => Text(
                        _controller.message ?? '',
                        style: const TextStyle(color: AppColors.warn, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_celebrating)
              Positioned.fill(
                child: ClearCelebration(onFinished: _onCelebrationFinished),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearDialog() async {
    final moves = _controller.moveCount;
    final limit = widget.level.limit;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
        title: const Text('クリア！', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        content: Text(
          '$moves 手（制限 $limit 手）\n${moves <= limit ? "見事、規定手数で解けました。" : ""}',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('レベル選択'),
          ),
          if (widget.onNextLevel != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                widget.onNextLevel!();
              },
              child: const Text('次へ'),
            ),
        ],
      ),
    );
  }

  Future<void> _showFailDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.warn, width: 1.2),
        ),
        title: const Text('手数オーバー', style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w700)),
        content: Text('${widget.level.limit} 手以内にタイルを出し切れませんでした', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _undoAndClearDialog();
            },
            child: const Text('1手戻す'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restart();
            },
            child: const Text('やり直す'),
          ),
        ],
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.controller, required this.onUndo, required this.onReset});
  final GameController controller;
  final VoidCallback onUndo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ControllerListener(
      controller: controller,
      builder: (context) {
        final left = controller.movesLeft;
        final warn = left <= 2;
        return Row(
          children: [
            Text.rich(
              TextSpan(
                style: AppTextStyles.body,
                children: [
                  const TextSpan(text: '残り手数 '),
                  TextSpan(
                    text: '$left',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: warn ? AppColors.warn : AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(text: ' / ${controller.level.limit}手以内', style: AppTextStyles.caption),
                ],
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: controller.canUndo ? onUndo : null,
              child: const Text('戻す'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onReset, child: const Text('リセット')),
          ],
        );
      },
    );
  }
}
