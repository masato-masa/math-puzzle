// flutter_tester.exe を使わず、素の Dart VM でソルバーの最短手順を再生する
// 検証スクリプト（flutter test が使えない環境向けのフォールバック）。
//
//   dart run tool/replay_solutions.dart
//
import 'dart:convert';
import 'dart:io';

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

  var allOk = true;
  for (final level in course.levels) {
    final solution = solutionsJson[level.levelId] as Map<String, dynamic>;
    final actions = solution['actions'] as List;
    final expectedPar = solution['par'] as int;

    final controller = GameController(level);
    String? failReason;

    if (level.limit != expectedPar) {
      failReason = 'limit(${level.limit}) != par($expectedPar)';
    }

    for (final raw in actions) {
      if (failReason != null) break;
      final action = raw as Map<String, dynamic>;
      MoveEvent event;
      if (action['type'] == 'move') {
        final row = action['row'] as int;
        final col = action['col'] as int;
        final dir = DirectionX.fromName(action['dir'] as String)!;
        final tile = controller.tileAt(row, col);
        if (tile == null) {
          failReason = '($row,$col) にタイルが無い';
          break;
        }
        event = controller.attemptMove(tile.id, dir);
      } else {
        final index = action['index'] as int;
        final result = controller.attemptExit(level.exits[index]);
        if (result == null) {
          failReason = '出口 $index で出せない: ${controller.message}';
          break;
        }
        event = result;
      }
      if (event.kind == MoveEventKind.blocked) {
        failReason = '手順が拒否された: ${controller.message}';
      }
    }

    if (failReason == null && !controller.isCleared) {
      failReason = 'クリアになっていない（残り${controller.tiles.length}タイル）';
    }
    if (failReason == null && controller.moveCount != level.limit) {
      failReason = '手数不一致: ${controller.moveCount} != ${level.limit}';
    }

    if (failReason != null) {
      allOk = false;
      stdout.writeln('[NG] ${level.levelId}: $failReason');
    } else {
      stdout.writeln('[OK] ${level.levelId}: ${controller.moveCount}/${level.limit} 手でクリア');
    }
  }

  stdout.writeln(allOk ? '\n全レベル OK' : '\n失敗あり');
  exit(allOk ? 0 : 1);
}
