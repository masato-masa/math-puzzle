// レベル選択に出す「そのステージの仕掛け」表示の検証。
//
// 表示が実際のレベル内容とズレると、プレイヤーに嘘を伝えることになる。
// 床・出口の定義から正しく導けているかを確かめる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/floor.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/widgets/gimmick_chips.dart';

Course _course() {
  final json = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Course.fromJson((json['courses'] as List).first as Map<String, dynamic>);
}

/// 個別の性質（複数出口・範囲出口・床の重複）は、実レベルの内容に
/// 左右されない固定フィクスチャで検証する。生成のたびに内容が変わる
/// レベルを名指しすると、そのIDが入れ替わった瞬間にテストが壊れる
/// （board_gesture_test.dart 等と同じ理由）。
Level _fixture({
  List<FloorTile> floors = const [],
  List<ExitSpec> exits = const [],
}) =>
    Level(
      levelId: 'fixture',
      title: 'fixture',
      hint: '',
      tutorial: false,
      rows: 3,
      cols: 3,
      tiles: const [],
      walls: const [],
      floors: floors,
      exits: exits,
      par: 1,
      limit: 1,
    );

void main() {
  final course = _course();

  test('床の種類がそのまま仕掛けとして出る', () {
    expect(
      gimmicksOf(_fixture(floors: const [FloorTile(row: 0, col: 0, kind: FloorKind.ice)])),
      [LevelGimmick.ice],
    );
    expect(
      gimmicksOf(_fixture(floors: const [FloorTile(row: 0, col: 0, kind: FloorKind.sqrt, uses: 1)])),
      [LevelGimmick.sqrt],
    );
    expect(
      gimmicksOf(_fixture(floors: const [FloorTile(row: 0, col: 0, kind: FloorKind.fact, uses: 1)])),
      [LevelGimmick.fact],
    );
  });

  test('仕掛けの無いステージは何も出ない', () {
    expect(gimmicksOf(_fixture()), isEmpty);
  });

  test('出口が2つ以上なら複数出口として出る', () {
    final level = _fixture(exits: const [
      ExitSpec(row: 0, col: 0, direction: ExitDirection.up, value: 1),
      ExitSpec(row: 0, col: 2, direction: ExitDirection.up, value: 2),
    ]);
    expect(gimmicksOf(level), contains(LevelGimmick.multiExit));
  });

  test('範囲で受け付ける出口は範囲出口として出る', () {
    final level = _fixture(exits: const [
      ExitSpec(row: 0, col: 0, direction: ExitDirection.up, minValue: 1, maxValue: 3),
    ]);
    expect(gimmicksOf(level), contains(LevelGimmick.rangeExit));
  });

  test('同じ種類の床が複数枚あっても 1 つにまとめる', () {
    final level = _fixture(floors: const [
      FloorTile(row: 0, col: 0, kind: FloorKind.ice),
      FloorTile(row: 0, col: 1, kind: FloorKind.ice),
      FloorTile(row: 0, col: 2, kind: FloorKind.ice),
    ]);
    expect(gimmicksOf(level).where((g) => g == LevelGimmick.ice).length, 1);
  });

  test('全レベルで、出た仕掛けは実際にそのレベルへ入っている', () {
    for (final level in course.levels) {
      final gimmicks = gimmicksOf(level).toSet();
      final floorKinds = level.floors.map((f) => f.kind).toSet();

      for (final g in gimmicks) {
        switch (g) {
          case LevelGimmick.ice:
            expect(floorKinds, contains(FloorKind.ice), reason: level.levelId);
          case LevelGimmick.rotate:
            expect(floorKinds, contains(FloorKind.rotate), reason: level.levelId);
          case LevelGimmick.swap:
            expect(floorKinds, contains(FloorKind.swap), reason: level.levelId);
          case LevelGimmick.sqrt:
            expect(floorKinds, contains(FloorKind.sqrt), reason: level.levelId);
          case LevelGimmick.fact:
            expect(floorKinds, contains(FloorKind.fact), reason: level.levelId);
          case LevelGimmick.multiExit:
            expect(level.exits.length, greaterThan(1), reason: level.levelId);
          case LevelGimmick.rangeExit:
            expect(level.exits.any((e) => e.minValue != null), isTrue,
                reason: level.levelId);
        }
      }

      // 逆に、床があるのに出ていないものが無いことも確かめる。
      for (final kind in floorKinds) {
        final expected = switch (kind) {
          FloorKind.ice => LevelGimmick.ice,
          FloorKind.rotate => LevelGimmick.rotate,
          FloorKind.swap => LevelGimmick.swap,
          FloorKind.sqrt => LevelGimmick.sqrt,
          FloorKind.fact => LevelGimmick.fact,
        };
        expect(gimmicks, contains(expected),
            reason: '${level.levelId} の $kind が表示から漏れている');
      }
    }
  });
}
