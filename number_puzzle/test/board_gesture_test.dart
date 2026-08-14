// 盤の操作（タップ・スワイプ）の検証。
//
// 盤は Canvas 上に描かれるので実機の見た目からは中身を確かめられない。
// ジェスチャーが正しく手に変換されているかは、ここで押さえておく。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/widgets/puzzle_board.dart';

/// 盤の外周（出口マーカーを描く余白）と盤の枠線の合計。
/// マスの座標を出すのに使う。
const double _boardInset = 44.0 + 2.0;
const double _cellSize = 100.0;

Level _level(String levelId) {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final course = Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
  return course.levels.firstWhere((l) => l.levelId == levelId);
}

/// 3×3 の盤がちょうど 1 マス 100px になる大きさで組む。
Future<void> _pumpBoard(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _cellSize * 3 + 88,
            height: _cellSize * 3 + 88,
            child: PuzzleBoard(controller: controller),
          ),
        ),
      ),
    ),
  );
}

/// マス (row, col) の中心の画面座標。
Offset _cellCenter(WidgetTester tester, int row, int col) {
  final origin = tester.getTopLeft(find.byType(PuzzleBoard));
  return origin +
      Offset(
        _boardInset + col * _cellSize + _cellSize / 2,
        _boardInset + row * _cellSize + _cellSize / 2,
      );
}

void main() {
  // v3_001: (1,0)の7 と (1,1)の3（左辺に −）。7−3=4 で合体する。
  testWidgets('スワイプでその向きへ動かせる', (tester) async {
    final c = GameController(_level('v3_001'));
    await _pumpBoard(tester, c);

    await tester.dragFrom(_cellCenter(tester, 1, 0), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(c.tiles.length, 1, reason: '合体して 1 枚になるはず');
    expect(c.tiles.single.value, 4, reason: '7 − 3 = 4');
    expect(c.moveCount, 1);
  });

  testWidgets('短すぎるなぞりは手にならない', (tester) async {
    final c = GameController(_level('v3_001'));
    await _pumpBoard(tester, c);

    // しきい値（マスの 35%）に満たない移動量。
    await tester.dragFrom(_cellCenter(tester, 1, 0), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(c.moveCount, 0, reason: '誤操作とみなして無視されるはず');
    expect(c.tiles.length, 2);
  });

  testWidgets('タップで選び、行き先をタップして動かせる', (tester) async {
    final c = GameController(_level('v3_001'));
    await _pumpBoard(tester, c);

    await tester.tapAt(_cellCenter(tester, 1, 0));
    await tester.pumpAndSettle();
    expect(c.selectedTileId, isNotNull, reason: 'タップで選択されるはず');

    await tester.tapAt(_cellCenter(tester, 1, 1));
    await tester.pumpAndSettle();

    expect(c.tiles.length, 1, reason: '行き先をタップして合体するはず');
    expect(c.tiles.single.value, 4);
  });

  testWidgets('動かせない向きへのスワイプは手を消費しない', (tester) async {
    final c = GameController(_level('v3_001'));
    await _pumpBoard(tester, c);

    // 上下は壁。
    await tester.dragFrom(_cellCenter(tester, 1, 0), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(c.moveCount, 0);
    expect(c.tiles.length, 2);
  });
}
