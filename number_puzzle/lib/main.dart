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

class _NumberPuzzleAppState extends State<NumberPuzzleApp> {
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
    // 効果音の音源を先に読み込んでおく（初回のタップで無音にならないように）。
    _soundService.init();
  }

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数式パズル',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: LevelSelectScreen(
        levelRepository: _levelRepository,
        progressService: _progressService,
        soundService: _soundService,
      ),
    );
  }
}
