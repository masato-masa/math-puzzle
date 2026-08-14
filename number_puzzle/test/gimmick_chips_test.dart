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

Level _level(Course c, String id) => c.levels.firstWhere((l) => l.levelId == id);

void main() {
  final course = _course();

  test('床の種類がそのまま仕掛けとして出る', () {
    // v3_006 は氷だけのステージ。
    expect(gimmicksOf(_level(course, 'v3_006')), [LevelGimmick.ice]);
    // v3_011 は平方根だけ。
    expect(gimmicksOf(_level(course, 'v3_011')), [LevelGimmick.sqrt]);
    // v3_016 は階乗だけ。
    expect(gimmicksOf(_level(course, 'v3_016')), [LevelGimmick.fact]);
  });

  test('仕掛けの無いステージは何も出ない', () {
    expect(gimmicksOf(_level(course, 'v3_001')), isEmpty);
  });

  test('出口が2つ以上なら複数出口として出る', () {
    expect(gimmicksOf(_level(course, 'v3_031')), contains(LevelGimmick.multiExit));
  });

  test('範囲で受け付ける出口は範囲出口として出る', () {
    expect(gimmicksOf(_level(course, 'v3_036')), contains(LevelGimmick.rangeExit));
  });

  test('同じ種類の床が複数枚あっても 1 つにまとめる', () {
    // v3_008 は氷を 6 枚使っているが、表示は「氷」1 つ。
    final level = _level(course, 'v3_008');
    final iceCount = level.floors.where((f) => f.kind == FloorKind.ice).length;
    expect(iceCount, greaterThan(1), reason: '氷が複数枚ある前提のテスト');
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
