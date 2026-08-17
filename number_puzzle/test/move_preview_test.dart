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
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/floor.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/game/move_event.dart';

Course _loadCourse() {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
}

/// 実レベルは生成のたびに内容が変わるので、個別の具体例は固定
/// フィクスチャで検証する（board_gesture_test.dart と同じ理由）。
/// (1,0)の7 と (1,1)の3（左辺に −）。7−3=4 で合体、上下は壁。
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
    );

/// 床で値が変わる例。16 が √ のマスに乗ると 4 になる。
Level _sqrtFixture() => Level(
      levelId: 'fixture_sqrt',
      title: 'fixture',
      hint: '',
      tutorial: true,
      rows: 1,
      cols: 2,
      tiles: [
        TileSpec(id: 'a', row: 0, col: 0, value: 16, edges: Edges.fromMap(null)),
      ],
      walls: const [],
      floors: const [FloorTile(row: 0, col: 1, kind: FloorKind.sqrt, uses: 1)],
      exits: const [],
      par: 1,
      limit: 1,
    );

void main() {
  final course = _loadCourse();

  test('合体できる向きは、結果の値つきで merged が返る', () {
    final c = GameController(_fixture());
    final tile = c.tileAt(1, 0)!;

    final res = c.previewMove(tile.id, Direction.right);

    expect(res.kind, MoveEventKind.merged);
    expect(res.value, 4, reason: '7 − 3 = 4 になるはず');
    expect(res.toRow, 1);
    expect(res.toCol, 1);
    expect(res.isMerge, isTrue);
  });

  test('床で値が変わる移動は、変化後の値が返る', () {
    final c = GameController(_sqrtFixture());
    final tile = c.tileAt(0, 0)!;

    final res = c.previewMove(tile.id, Direction.right);

    expect(res.kind, MoveEventKind.moved);
    expect(res.value, 4, reason: '√16 = 4 になるはず');
    expect(res.toCol, 1);
  });

  test('動かせない向きは理由つきで blocked が返る', () {
    final c = GameController(_fixture());
    final tile = c.tileAt(1, 0)!;

    // 上下は壁、左は盤の外。
    for (final d in [Direction.up, Direction.down, Direction.left]) {
      final res = c.previewMove(tile.id, d);
      expect(res.isBlocked, isTrue, reason: '$d には動けないはず');
      expect(res.reason, isNotNull, reason: '$d の理由が入っているはず');
    }
  });

  test('プレビューは盤面を一切変えない', () {
    final c = GameController(_fixture());
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

  test('合体したら、できあがったタイルが選択状態になる', () {
    final c = GameController(_fixture());
    final mover = c.tileAt(1, 0)!;
    final target = c.tileAt(1, 1)!;
    c.selectTile(mover.id);

    c.attemptMove(mover.id, Direction.right);

    expect(c.selectedTileId, target.id, reason: '合体後のタイルが選ばれているはず');
    expect(c.tileById(c.selectedTileId!), isNotNull,
        reason: '選択中の id が実在するタイルを指しているはず');
    expect(c.tileById(c.selectedTileId!)!.value, 4);
  });

  test('動かしただけなら、そのタイルの選択は続く', () {
    final c = GameController(_sqrtFixture());
    final tile = c.tileAt(0, 0)!;
    c.selectTile(tile.id);

    c.attemptMove(tile.id, Direction.right);

    expect(c.selectedTileId, tile.id);
  });

  test('選んでいないタイルが合体しても、選択は横取りされない', () {
    final c = GameController(_fixture());
    final mover = c.tileAt(1, 0)!;
    c.selectTile(null);

    c.attemptMove(mover.id, Direction.right);

    expect(c.selectedTileId, isNull, reason: '選んでいなかったなら選択は空のまま');
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

          if (preview.kind == MoveEventKind.burned) {
            // 炎は相手を燃やして自分も消えるので、その位置には何も残らない。
            expect(c.tileAt(preview.toRow, preview.toCol), isNull,
                reason: '${level.levelId} の ${startTile.id} を $d: '
                    '燃やした跡にタイルが残っている');
          } else if (!preview.isBlocked) {
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
