import 'package:flutter/material.dart';

import '../game/course.dart';
import '../game/level_repository.dart';
import '../game/models.dart';
import '../services/progress_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gimmick_chips.dart';
import 'puzzle_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.levelRepository,
    required this.progressService,
    required this.soundService,
  });

  final LevelRepository levelRepository;
  final ProgressService progressService;
  final SoundService soundService;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  List<Course>? _courses;
  Map<String, LevelProgress> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courses = await widget.levelRepository.loadCourses();
    final progress = await widget.progressService.loadAll();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _progress = progress;
    });
  }

  Future<void> _refreshProgress() async {
    final progress = await widget.progressService.loadAll();
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  void _openLevel(Course course, int index) {
    final level = course.levels[index];
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PuzzleScreen(
          level: level,
          soundService: widget.soundService,
          progressService: widget.progressService,
          onNextLevel: index + 1 < course.levels.length
              ? () => _openLevel(course, index + 1)
              : null,
        ),
      ),
    )
        .then((_) => _refreshProgress());
  }

  @override
  Widget build(BuildContext context) {
    final courses = _courses;
    return Scaffold(
      appBar: AppBar(title: const Text('数式パズル')),
      body: courses == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  for (final course in courses) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        course.title,
                        style: AppTextStyles.display.copyWith(fontSize: 18),
                      ),
                    ),
                    Expanded(
                      // レベル 1 を一番下に、番号が増えるほど上へ積む
                      // 「上り階段」の一本道にする（reverse: true で先頭
                      // 要素＝レベル1を下端に配置し、初期表示もそこにする）。
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        itemCount: course.levels.length,
                        itemBuilder: (context, i) {
                          final level = course.levels[i];
                          final progress = _progress[level.levelId];
                          return _LevelPathNode(
                            index: i + 1,
                            level: level,
                            progress: progress,
                            hasNext: i + 1 < course.levels.length,
                            onTap: () => _openLevel(course, i),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// レベル選択の一本道（縦一列）を構成する 1 ノード。
/// 円い番号バッジ＋横長カードで、下のノードとの間を線でつないで
/// 「登っていく道」に見せる。
class _LevelPathNode extends StatelessWidget {
  const _LevelPathNode({
    required this.index,
    required this.level,
    required this.progress,
    required this.hasNext,
    required this.onTap,
  });

  final int index;
  final Level level;
  final LevelProgress? progress;
  final bool hasNext; // このノードより上（番号が大きい側）にまだノードがあるか
  final VoidCallback onTap;

  static const _badgeSize = 44.0;
  static const _connectorHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final cleared = progress?.cleared ?? false;
    return Column(
      children: [
        if (hasNext)
          Container(
            width: 3,
            height: _connectorHeight,
            color: AppColors.rule,
          ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.tileTop, AppColors.tileBottom],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cleared ? AppColors.gold : AppColors.rule, width: cleared ? 1.6 : 1.2),
              boxShadow: cleared
                  ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
            child: Row(
              children: [
                _Badge(index: index, cleared: cleared, isBoss: index % 5 == 0),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              level.title,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (progress?.everPerfect ?? false)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Tooltip(
                                message: 'ノーヒント・ノーアンドゥクリア済み',
                                child: Text('✨', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('${level.limit}手以内', style: AppTextStyles.caption),
                          const SizedBox(width: 8),
                          Flexible(child: GimmickChips(gimmicks: gimmicksOf(level))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (cleared) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.gold, size: 18),
                      const SizedBox(height: 2),
                      Text('best ${progress!.bestMoves}手',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.index, required this.cleared, this.isBoss = false});

  final int index;
  final bool cleared;

  /// 5ステージ1ブロックの最後（ボス面）かどうか。Angry Birds 等の
  /// レベルマップで節目の面が一目で分かるのを参考に、王冠を添える。
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: _LevelPathNode._badgeSize,
      height: _LevelPathNode._badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: cleared
            ? const LinearGradient(colors: [Color(0xFFFFE29A), AppColors.gold])
            : null,
        color: cleared ? null : AppColors.tileFixed,
        border: Border.all(
          color: isBoss
              ? AppColors.warn
              : (cleared ? AppColors.goldDeep : AppColors.rule),
          width: isBoss ? 1.8 : 1.2,
        ),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: cleared ? AppColors.goldDeep : AppColors.textPrimary,
        ),
      ),
    );
    if (!isBoss) return badge;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        const Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(child: Text('👑', style: TextStyle(fontSize: 16))),
        ),
      ],
    );
  }
}
