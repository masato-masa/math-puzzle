import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/models.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sheets.dart';
import '../widgets/clear_celebration.dart';
import '../widgets/controller_listener.dart';
import '../widgets/puzzle_board.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.level,
    required this.soundService,
    required this.progressService,
    required this.settingsService,
    this.onNextLevel,
  });

  final Level level;
  final SoundService soundService;
  final ProgressService progressService;
  final SettingsService settingsService;
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
      widget.progressService.recordClear(
        widget.level.levelId,
        _controller.moveCount,
        perfect: _controller.isPerfectClear,
      );
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
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // 行 1 はナビゲーションだけ。残り手数は行 2（ステータスバー）へ。
                  ControllerListener(
                    controller: _controller,
                    builder: (context) {
                      final left = _controller.movesLeft;
                      return AppHeader(
                        title: widget.level.title,
                        onBack: () => Navigator.of(context).pop(),
                        onSettings: () => showSettingsSheet(
                          context,
                          settings: widget.settingsService,
                          onSfxChanged: (v) {
                            widget.settingsService.setSfxEnabled(v);
                            widget.soundService.sfxEnabled = v;
                            setState(() {});
                          },
                        ),
                        onHelp: () => showHelpSheet(context),
                        status: [
                          StatPill(
                            label: 'のこり',
                            value: '$left',
                            valueColor: left <= 2 ? AppColors.warn : null,
                            trailing: '/ ${widget.level.limit}手',
                          ),
                        ],
                      );
                    },
                  ),
                  if (widget.level.hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(widget.level.hint,
                          style: AppTextStyles.caption, textAlign: TextAlign.center),
                    ),
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
                  // 操作のボタンは盤面の下。上＝ナビゲーション、下＝操作で
                  // どのゲームも同じ形にしてある。
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: _ToolRowForGame(
                      controller: _controller,
                      onUndo: () {
                        setState(() => _dialogShown = false);
                        _controller.undo();
                      },
                      onReset: _restart,
                      onHint: () => setState(() => _controller.peekHint()),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$moves 手（制限 $limit 手）\n見事、規定手数で解けました。', style: AppTextStyles.body),
            if (_controller.isPerfectClear) ...[
              const SizedBox(height: 8),
              const Text('✨ ノーヒント・ノーアンドゥクリア',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
            ],
          ],
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

/// 盤面の下のツール行。ヒントは 1 手目にしか出せないので、
/// 出せないときは押せない見た目にする（隠すと位置が動いてしまう）。
class _ToolRowForGame extends StatelessWidget {
  const _ToolRowForGame({
    required this.controller,
    required this.onUndo,
    required this.onReset,
    required this.onHint,
  });

  final GameController controller;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return ControllerListener(
      controller: controller,
      builder: (context) {
        // ヒントは最初の一手にしか対応していないので、1手目でしか出せない。
        final hintAvailable = controller.level.hintMove != null &&
            controller.moveCount == 0 &&
            !controller.isCleared &&
            !controller.isFailed;
        return ToolRow(
          children: [
            ToolButton(
              icon: Icons.undo,
              tooltip: 'もどす',
              onPressed: controller.canUndo ? onUndo : null,
            ),
            ToolButton(
              icon: Icons.refresh,
              tooltip: 'やり直す',
              onPressed: onReset,
            ),
            if (controller.level.hintMove != null)
              ToolButton(
                icon: Icons.lightbulb_outline,
                tooltip: 'ヒント',
                onPressed: hintAvailable ? onHint : null,
              ),
          ],
        );
      },
    );
  }
}
