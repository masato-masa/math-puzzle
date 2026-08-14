// ヒント機能とノーヒント・ノーアンドゥ実績の検証。
//
// 全レベル手数の余裕がゼロ（limit == par）という設計上、手数効率では
// 差がつかない。差がつくのはヒント・アンドゥを使ったかどうかだけなので、
// ここが壊れると実績表示が常に不正確になる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';

Course _course() {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
}

Level _level(Course c, String id) => c.levels.firstWhere((l) => l.levelId == id);

void main() {
  final course = _course();

  test('全レベルに1手目のヒントが埋め込まれている', () {
    // ヒント無しのレベルがあると、そのレベルだけボタンが出ない不整合になる。
    for (final level in course.levels) {
      expect(level.hintMove, isNotNull, reason: '${level.levelId} にヒントが無い');
    }
  });

  test('ヒントを見ると、その一手目のタイルと向きが選択される', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    final hint = level.hintMove!;

    c.peekHint();

    expect(c.selectedTileId, isNotNull);
    expect(c.hintDirection, hint.direction);
    expect(c.hintUsed, isTrue);
  });

  test('手を動かした後にヒントを見ても何も起きない（1手目専用）', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    final before = c.hintUsed;

    c.peekHint();

    expect(c.hintUsed, before, reason: '1手動かした後はヒントが効かないはず');
  });

  test('何も使わずクリアすると isPerfectClear が true', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    c.attemptMove(c.tiles.single.id, Direction.right);
    c.attemptExit(level.exits.first);

    expect(c.isCleared, isTrue);
    expect(c.isPerfectClear, isTrue);
  });

  test('ヒントを使ってクリアすると isPerfectClear が false', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    c.peekHint();
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    c.attemptMove(c.tiles.single.id, Direction.right);
    c.attemptExit(level.exits.first);

    expect(c.isCleared, isTrue);
    expect(c.isPerfectClear, isFalse);
  });

  test('アンドゥを使ってクリアすると isPerfectClear が false', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    c.undo();
    c.attemptMove(tile.id, Direction.right);
    c.attemptMove(c.tiles.single.id, Direction.right);
    c.attemptExit(level.exits.first);

    expect(c.isCleared, isTrue);
    expect(c.isPerfectClear, isFalse);
  });

  test('restart するとヒント・アンドゥ使用の記録がリセットされる', () {
    final level = _level(course, 'v3_001');
    final c = GameController(level);
    c.peekHint();
    expect(c.hintUsed, isTrue);

    c.restart();

    expect(c.hintUsed, isFalse);
    expect(c.undoUsed, isFalse);
    expect(c.hintDirection, isNull);
  });

  test('ヒントの一手目は、その方向のプレビューがブロックされない', () {
    // ヒント埋め込みと実際のルールがズレていないかの安全確認。
    for (final level in course.levels) {
      final c = GameController(level);
      final hint = level.hintMove!;
      final tileId = c.tileAt(hint.row!, hint.col!)?.id;
      expect(tileId, isNotNull, reason: '${level.levelId}: ヒントの位置にタイルが無い');
      final res = c.previewMove(tileId!, hint.direction!);
      expect(res.isBlocked, isFalse,
          reason: '${level.levelId}: ヒントの一手目が実際には動かせない');
    }
  });
}
