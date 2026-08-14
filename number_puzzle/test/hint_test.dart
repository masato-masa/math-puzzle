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
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';

Course _course() {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
}

/// 実レベルは生成のたびに内容が変わるので、ヒント固有の挙動は固定
/// フィクスチャで検証する（board_gesture_test.dart と同じ理由）。
/// (1,0)の7 を (1,1)の3 へ当てて 4 を作り、(1,2)から出る。
Level _fixture() => Level(
      levelId: 'fixture',
      title: 'fixture',
      hint: '',
      tutorial: true,
      rows: 3,
      cols: 3,
      tiles: [
        TileSpec(id: 'a', row: 1, col: 0, value: 7, edges: Edges.fromMap(null)),
        TileSpec(id: 'b', row: 1, col: 1, value: 3, edges: Edges.fromMap({'left': '−'})),
      ],
      walls: const [
        WallCell(0, 0), WallCell(0, 1), WallCell(0, 2),
        WallCell(2, 0), WallCell(2, 1), WallCell(2, 2),
      ],
      floors: const [],
      exits: const [ExitSpec(row: 1, col: 2, direction: ExitDirection.right, value: 4)],
      par: 3,
      limit: 3,
      hintMove: const HintMove(row: 1, col: 0, direction: Direction.right),
    );

void main() {
  final course = _course();

  test('全レベルに1手目のヒントが埋め込まれている', () {
    // ヒント無しのレベルがあると、そのレベルだけボタンが出ない不整合になる。
    for (final level in course.levels) {
      expect(level.hintMove, isNotNull, reason: '${level.levelId} にヒントが無い');
    }
  });

  test('ヒントを見ると、その一手目のタイルと向きが選択される', () {
    final level = _fixture();
    final c = GameController(level);
    final hint = level.hintMove!;

    c.peekHint();

    expect(c.selectedTileId, isNotNull);
    expect(c.hintDirection, hint.direction);
    expect(c.hintUsed, isTrue);
  });

  test('手を動かした後にヒントを見ても何も起きない（1手目専用）', () {
    final level = _fixture();
    final c = GameController(level);
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    final before = c.hintUsed;

    c.peekHint();

    expect(c.hintUsed, before, reason: '1手動かした後はヒントが効かないはず');
  });

  test('何も使わずクリアすると isPerfectClear が true', () {
    final level = _fixture();
    final c = GameController(level);
    final tile = c.tileAt(1, 0)!;
    c.attemptMove(tile.id, Direction.right);
    c.attemptMove(c.tiles.single.id, Direction.right);
    c.attemptExit(level.exits.first);

    expect(c.isCleared, isTrue);
    expect(c.isPerfectClear, isTrue);
  });

  test('ヒントを使ってクリアすると isPerfectClear が false', () {
    final level = _fixture();
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
    final level = _fixture();
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
    final level = _fixture();
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
