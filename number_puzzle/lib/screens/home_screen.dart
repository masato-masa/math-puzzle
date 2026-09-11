import 'package:flutter/material.dart';

import '../game/course.dart';
import '../game/level_repository.dart';
import '../game/models.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_sheets.dart';
import 'level_select_screen.dart';
import 'puzzle_screen.dart';

/// タイトル画面。
///
/// これまでは起動していきなりレベル選択だった。4 つのゲームで同じ形にするため
/// 新しく作った ― 「つづきから」を主ボタンにして、右上に設定、右下に
/// 開発者メニューを置く。「あそびかた」はここには置かない（? はプレイ画面の
/// 右上に集約した）。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.levelRepository,
    required this.progressService,
    required this.soundService,
    required this.settingsService,
  });

  final LevelRepository levelRepository;
  final ProgressService progressService;
  final SoundService soundService;
  final SettingsService settingsService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _refresh() async {
    final progress = await widget.progressService.loadAll();
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  List<Level> get _allLevels => [for (final c in _courses ?? const <Course>[]) ...c.levels];

  int get _clearedCount =>
      _allLevels.where((l) => _progress[l.levelId]?.cleared ?? false).length;

  /// 「つづきから」の行き先。未クリアのうち最初のもの。
  (Course, int)? get _next {
    for (final c in _courses ?? const <Course>[]) {
      for (var i = 0; i < c.levels.length; i++) {
        if (!(_progress[c.levels[i].levelId]?.cleared ?? false)) return (c, i);
      }
    }
    final courses = _courses;
    if (courses == null || courses.isEmpty) return null;
    return (courses.first, 0);
  }

  void _openLevel(Course course, int index) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PuzzleScreen(
              level: course.levels[index],
              soundService: widget.soundService,
              progressService: widget.progressService,
              settingsService: widget.settingsService,
              onNextLevel: index + 1 < course.levels.length
                  ? () => _openLevel(course, index + 1)
                  : null,
            ),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final courses = _courses;
    if (courses == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = _allLevels.length;
    final cleared = _clearedCount;
    final next = _next;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              right: 16,
              child: RoundIconButton(
                icon: Icons.settings,
                tooltip: '設定',
                onPressed: () => showSettingsSheet(
                  context,
                  settings: widget.settingsService,
                  onSfxChanged: (v) {
                    widget.settingsService.setSfxEnabled(v);
                    widget.soundService.sfxEnabled = v;
                    setState(() {});
                  },
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TitleArt(),
                    const SizedBox(height: 6),
                    Text(
                      '数式パズル',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display.copyWith(fontSize: 34, letterSpacing: 0.06),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'タイルをぶつけて 出口へ はこぼう',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    _HomeButton(
                      label: cleared > 0 ? 'つづきから' : 'はじめる',
                      sublabel: cleared > 0 && next != null
                          ? next.$1.levels[next.$2].title
                          : null,
                      primary: true,
                      onPressed: next == null ? null : () => _openLevel(next.$1, next.$2),
                    ),
                    const SizedBox(height: 12),
                    _HomeButton(
                      label: 'ステージを えらぶ',
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) => LevelSelectScreen(
                                  levelRepository: widget.levelRepository,
                                  progressService: widget.progressService,
                                  soundService: widget.soundService,
                                  settingsService: widget.settingsService,
                                ),
                              ),
                            )
                            .then((_) => _refresh());
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'クリア $cleared / $total',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DevPill(
                onPressed: () => showDevSheet(
                  context,
                  courses: courses,
                  progress: widget.progressService,
                  onChanged: _refresh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// タイトルの絵。盤面と同じ「面取りしたブロックにネオンのリムライト」で
/// 数式を組み、このゲームが何かを 1 枚で伝える。
class _TitleArt extends StatelessWidget {
  const _TitleArt();

  static const _cells = [
    ('6', AppColors.cyan),
    ('×', AppColors.amber),
    ('7', AppColors.violet),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (text, rim) in _cells)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.tileTop, AppColors.tileBottom],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rim, width: 1.4),
                  boxShadow: [BoxShadow(color: rim.withValues(alpha: 0.28), blurRadius: 12)],
                ),
                child: Text(
                  text,
                  style: AppTextStyles.tile.copyWith(fontSize: 28, color: rim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.label,
    this.sublabel,
    this.primary = false,
    this.onPressed,
  });

  final String label;
  final String? sublabel;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.gold : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      shape: primary
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: AppColors.rule, width: 1.2),
            ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primary ? AppColors.goldDeep : AppColors.textPrimary,
                ),
              ),
              if (sublabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (primary ? AppColors.goldDeep : AppColors.textMuted)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右下の小さな「テスト用」。本番の操作導線には出さない。
class _DevPill extends StatelessWidget {
  const _DevPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            'テスト用',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
