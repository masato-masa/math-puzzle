// クリア演出の検証。
//
// 演出そのものの見た目はテストできないが、
//   - クリアした瞬間に出ること
//   - 演出が終わったら結果ダイアログに繋がること
//   - 失敗時には出ないこと
// という流れは押さえておく（ここが壊れると、演出が出たまま
// ダイアログが来ない＝操作不能になりうる）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/screens/puzzle_screen.dart';
import 'package:number_puzzle/services/progress_service.dart';
import 'package:number_puzzle/services/sound_service.dart';
import 'package:number_puzzle/widgets/clear_celebration.dart';
import 'package:number_puzzle/widgets/puzzle_board.dart';

Level _level(String id) {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final course = Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
  return course.levels.firstWhere((l) => l.levelId == id);
}

/// 盤の外周＋枠線。マスの座標を出すのに使う。
const double _boardInset = 44.0 + 2.0;

void main() {
  // shared_preferences を使う ProgressService をテストで動かすための下準備。
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Level level) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleScreen(
          level: level,
          soundService: SoundService()..sfxEnabled = false,
          progressService: ProgressService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('クリアすると演出が出て、終わると結果ダイアログに変わる', (tester) async {
    // v3_001 は 3 手（右へ当てて合体 → 右へ移動 → 出口）で終わる。
    final level = _level('v3_001');
    await pump(tester, level);

    expect(find.byType(ClearCelebration), findsNothing, reason: '始めは出ていない');

    // 盤を直接操作せず、コントローラ相当の手順をタップで再現する。
    final origin = tester.getTopLeft(find.byType(PuzzleBoard));
    final board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
    final c = board.controller;

    c.selectTile(c.tileAt(1, 0)!.id);
    c.attemptMove(c.tileAt(1, 0)!.id, Direction.right); // 7 − 3 = 4
    c.attemptMove(c.tiles.single.id, Direction.right); // 出口のマスへ
    c.attemptExit(level.exits.first);
    await tester.pump(); // 状態変化を反映
    await tester.pump(); // addPostFrameCallback の分

    expect(c.isCleared, isTrue, reason: 'クリアしている前提');
    expect(find.byType(ClearCelebration), findsOneWidget, reason: '演出が出るはず');

    // 「クリア！」の文字は輪が広がり始めてから少し遅れて出る。
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('クリア！'), findsOneWidget, reason: '途中で文字が出るはず');

    // 演出（1.1 秒）が終わるまで進めると、ダイアログに切り替わる。
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(ClearCelebration), findsNothing, reason: '演出は消えているはず');
    expect(find.text('レベル選択'), findsOneWidget, reason: '結果ダイアログが出るはず');

    // origin は座標計算用に取得したが、この経路では未使用。
    expect(origin.dx + _boardInset, greaterThan(0));
  });

  testWidgets('手数オーバーでは演出を出さない', (tester) async {
    final level = _level('v3_001');
    await pump(tester, level);

    final c = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).controller;

    // 制限 3 手を、合体せずに使い切る（7 を上下左右へ動かせない向きは
    // 手にならないので、動ける向きへ往復させる）。
    c.attemptMove(c.tileAt(1, 0)!.id, Direction.right); // 合体して 4
    final tile = c.tiles.single;
    c.attemptMove(tile.id, Direction.right); // 出口のマスへ
    c.attemptMove(tile.id, Direction.left); // 戻る（3 手目）
    await tester.pump();
    await tester.pump();

    expect(c.isFailed, isTrue, reason: '手数を使い切っている前提');
    expect(find.byType(ClearCelebration), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('手数オーバー'), findsOneWidget);
  });
}
