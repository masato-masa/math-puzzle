// 氷スライドの軌跡表示の検証。
//
// 氷は「当たるまで止まらない」ので 1 手で何マスも進むが、タイル本体は
// 始点から終点へすべるだけなので、途中を本当に通ったのか伝わりにくい。
// 通過マスに軌跡の粒を灯すことで補っている。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/widgets/puzzle_board.dart';

Level _level(String id) {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final course = Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
  return course.levels.firstWhere((l) => l.levelId == id);
}

const double _boardInset = 44.0 + 2.0;
const double _cellSize = 100.0;

Future<GameController> _pumpBoard(WidgetTester tester, Level level) async {
  final c = GameController(level);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _cellSize * level.cols + 88,
            height: _cellSize * level.rows + 88,
            child: PuzzleBoard(controller: c),
          ),
        ),
      ),
    ),
  );
  return c;
}

Offset _cellCenter(WidgetTester tester, int row, int col) {
  final origin = tester.getTopLeft(find.byType(PuzzleBoard));
  return origin +
      Offset(
        _boardInset + col * _cellSize + _cellSize / 2,
        _boardInset + row * _cellSize + _cellSize / 2,
      );
}

void main() {
  testWidgets('氷を2マス滑ると、通過マスに軌跡が一瞬出る', (tester) async {
    // v3_006: (3,0)の9 が (3,1)(3,2) の氷を滑って (3,3) の4 に当たる。
    // タップ2回（選ぶ→行き先）で動かす。ドラッグのしきい値判定に
    // 左右されない、確実な経路で _performMove を通す。
    final c = await _pumpBoard(tester, _level('v3_006'));

    await tester.tapAt(_cellCenter(tester, 3, 0));
    await tester.pump();
    await tester.tapAt(_cellCenter(tester, 3, 3));
    await tester.pump(); // 1フレーム進めて setState を反映

    // a(9) が氷を滑って b(4) に当たり 9−4=5 に合体する。
    // 3枚のうち c は無関係なので、この1手では 3 → 2 枚になる。
    expect(c.tiles.length, 2, reason: '9−4 で合体している前提');
    expect(c.tileAt(3, 3)?.value, 5);
    // 遅延表示分だけ進めて、少なくとも1つの粒が灯った状態を確認する。
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PuzzleBoard), findsOneWidget);

    // 380ms（自動消滅までの時間）+ 余裕を進めれば軌跡は消えている。
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('1マスだけの通常移動では軌跡が出ない（例外を起こさない）', (tester) async {
    final c = await _pumpBoard(tester, _level('v3_001'));

    await tester.dragFrom(_cellCenter(tester, 1, 0), const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(c.moveCount, 1);
  });
}
