import 'package:flutter/material.dart';

import 'game/level_repository.dart';
import 'screens/level_select_screen.dart';
import 'services/monetization.dart';
import 'services/progress_service.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NumberPuzzleApp());
}

class NumberPuzzleApp extends StatefulWidget {
  const NumberPuzzleApp({super.key});

  @override
  State<NumberPuzzleApp> createState() => _NumberPuzzleAppState();
}

class _NumberPuzzleAppState extends State<NumberPuzzleApp> with WidgetsBindingObserver {
  final _soundService = SoundService();
  final _progressService = ProgressService();
  final _levelRepository = LevelRepository();

  // マネタイズは no-op 実装のみ保持しておく（3.2 節参照）。
  // 実際の SDK を導入する際はここを差し替える。
  // ignore: unused_field
  final AdService _adService = NoopAdService();
  // ignore: unused_field
  final PurchaseService _purchaseService = NoopPurchaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soundService.init();
    _soundService.playBgm();
  }

  // ブラウザはユーザー操作を伴わない音声再生をブロックすることがある。
  // 起動直後の playBgm() がそれで無視された場合に備え、最初のタップ／
  // クリックのたびに再試行する（既に鳴っていれば playBgm() は何もしない）。
  void _retryBgmOnGesture(PointerDownEvent _) {
    _soundService.playBgm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _soundService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドに回ったら BGM を止め、復帰したら再開する。
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _soundService.stopBgm();
    } else if (state == AppLifecycleState.resumed) {
      _soundService.playBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数式パズル',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _retryBgmOnGesture,
        child: child!,
      ),
      home: LevelSelectScreen(
        levelRepository: _levelRepository,
        progressService: _progressService,
        soundService: _soundService,
      ),
    );
  }
}
