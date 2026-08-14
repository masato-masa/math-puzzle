// 移動先プレビュー（GameController.previewMove）の検証。
//
// プレビューは「実際に動かしたらどうなるか」を盤面に触れずに返す。
// 表示と実挙動がズレると誤情報を出すことになるので、
//   1. 盤面を変えないこと
//   2. 実際に動かした結果と一致すること
// の 2 点を確かめる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/game/move_event.dart';

Course _loadCourse() {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
}

Level _level(Course course, String levelId) =>
    course.levels.firstWhere((l) => l.levelId == levelId);

void main() {
  final course = _loadCourse();

  test('合体できる向きは、結果の値つきで merged が返る', () {
    // v3_001: (1,0)の7 を (1,1)の3（左辺に −）へ当てると 7−3=4。
    final c = GameController(_level(course, 'v3_001'));
    final tile = c.tileAt(1, 0)!;

    final res = c.previewMove(tile.id, Direction.right);

    expect(res.kind, MoveEventKind.merged);
    expect(res.value, 4, reason: '7 − 3 = 4 になるはず');
    expect(res.toRow, 1);
    expect(res.toCol, 1);
    expect(res.isMerge, isTrue);
  });

  test('床で値が変わる移動は、変化後の値が返る', () {
    // v3_011: 16 が √ のマスに乗ると 4 になる。
    final c = GameController(_level(course, 'v3_011'));
    final tile = c.tileAt(1, 0)!;

    final res = c.previewMove(tile.id, Direction.right);

    expect(res.kind, MoveEventKind.moved);
    expect(res.value, 4, reason: '√16 = 4 になるはず');
    expect(res.toCol, 1);
  });

  test('動かせない向きは理由つきで blocked が返る', () {
    final c = GameController(_level(course, 'v3_001'));
    final tile = c.tileAt(1, 0)!;

    // 上下は壁、左は盤の外。
    for (final d in [Direction.up, Direction.down, Direction.left]) {
      final res = c.previewMove(tile.id, d);
      expect(res.isBlocked, isTrue, reason: '$d には動けないはず');
      expect(res.reason, isNotNull, reason: '$d の理由が入っているはず');
    }
  });

  test('プレビューは盤面を一切変えない', () {
    final c = GameController(_level(course, 'v3_001'));
    final tile = c.tileAt(1, 0)!;
    final beforeRow = tile.row, beforeCol = tile.col, beforeValue = tile.value;
    final beforeTiles = c.tiles.length;

    for (final d in kAllDirections) {
      c.previewMove(tile.id, d);
    }

    expect(c.moveCount, 0, reason: '手数が増えてはいけない');
    expect(c.tiles.length, beforeTiles, reason: 'タイルが消えてはいけない');
    expect(tile.row, beforeRow);
    expect(tile.col, beforeCol);
    expect(tile.value, beforeValue);
    expect(c.canUndo, isFalse, reason: '履歴が積まれてはいけない');
  });

  test('プレビューの結果は、実際に動かした結果と一致する', () {
    // 全レベルの全タイル・全方向について、プレビューと実挙動を突き合わせる。
    for (final level in course.levels) {
      for (final startTile in GameController(level).tiles) {
        for (final d in kAllDirections) {
          final c = GameController(level);
          final preview = c.previewMove(startTile.id, d);
          final event = c.attemptMove(startTile.id, d);

          expect(event.kind, preview.kind,
              reason: '${level.levelId} の ${startTile.id} を $d: 種別が食い違う');
          expect(event.toRow, preview.toRow,
              reason: '${level.levelId} の ${startTile.id} を $d: 行き先(行)が食い違う');
          expect(event.toCol, preview.toCol,
              reason: '${level.levelId} の ${startTile.id} を $d: 行き先(列)が食い違う');

          if (!preview.isBlocked) {
            // 成立したなら、その位置のタイルはプレビューが予告した値になっている。
            final landed = c.tileAt(preview.toRow, preview.toCol);
            expect(landed?.value, preview.value,
                reason: '${level.levelId} の ${startTile.id} を $d: 結果の値が食い違う');
          }
        }
      }
    }
  });
}
