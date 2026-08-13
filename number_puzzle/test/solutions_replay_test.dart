// ソルバー（tools/v3_solver.py）が算出した最短手順を、この Dart 実装の
// GameController で実際に再生し、全レベルが「制限手数ちょうど」で
// クリアになることを確認する。ロジック移植の正しさを保証する最重要テスト。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/course.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/move_event.dart';

void main() {
  final courseJson = jsonDecode(
    File('assets/levels/main_course.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final course = Course.fromJson(
    (courseJson['courses'] as List).first as Map<String, dynamic>,
  );

  final solutionsJson = jsonDecode(
    File('test/fixtures/solutions_v3.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final level in course.levels) {
    test('${level.levelId}: 最短手順を再生すると制限手数ちょうどでクリアになる', () {
      final solution = solutionsJson[level.levelId] as Map<String, dynamic>;
      final actions = solution['actions'] as List;
      final expectedPar = solution['par'] as int;
      expect(level.limit, expectedPar, reason: 'レベルJSONの limit がソルバーの par と一致しているか');

      final controller = GameController(level);

      for (final raw in actions) {
        final action = raw as Map<String, dynamic>;
        MoveEvent event;
        if (action['type'] == 'move') {
          final row = action['row'] as int;
          final col = action['col'] as int;
          final dir = DirectionX.fromName(action['dir'] as String)!;
          final tile = controller.tileAt(row, col);
          expect(tile, isNotNull, reason: '($row,$col) にタイルがあるはず');
          event = controller.attemptMove(tile!.id, dir);
        } else {
          final index = action['index'] as int;
          final result = controller.attemptExit(level.exits[index]);
          expect(result, isNotNull, reason: '出口 $index で出せるはず');
          event = result!;
        }
        expect(
          event.kind,
          isNot(MoveEventKind.blocked),
          reason: '${level.levelId} の手順が拒否された: ${controller.message}',
        );
      }

      expect(controller.isCleared, isTrue, reason: '${level.levelId} がクリアになっていない');
      expect(controller.moveCount, level.limit, reason: '手数が制限とちょうど一致するはず');
      expect(controller.tiles, isEmpty);
    });
  }
}
