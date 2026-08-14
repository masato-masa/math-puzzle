// 炎タイルの検証。
//
// 炎は「どのタイルを諦めるか」を 1 回だけ選べる資源。
// ソルバー(tools/v3_rules.py)と同じ振る舞いになっていないと、
// 生成したレベルの手順がアプリ側で再生できなくなる。
import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/game_rules.dart';
import 'package:number_puzzle/game/models.dart';
import 'package:number_puzzle/game/move_event.dart';

/// 1×N の盤に好きなタイルを並べたレベルを作る。
Level _row(List<TileSpec> tiles, {int cols = 4, List<ExitSpec> exits = const []}) {
  return Level(
    levelId: 'test',
    title: 'test',
    hint: '',
    tutorial: false,
    rows: 1,
    cols: cols,
    tiles: tiles,
    walls: const [],
    floors: const [],
    exits: exits,
    par: 99,
    limit: 99,
  );
}

TileSpec _num(String id, int col, int value, {Map<String, String>? edges}) =>
    TileSpec(
      id: id,
      row: 0,
      col: col,
      value: value,
      edges: Edges.fromMap(edges),
    );

TileSpec _fire(String id, int col) => TileSpec(
      id: id,
      row: 0,
      col: col,
      value: kFireValue,
      edges: Edges.fromMap(null),
    );

void main() {
  test('炎は数字を燃やし、両方とも盤から消える', () {
    final c = GameController(_row([_num('a', 0, 7), _fire('f', 1)]));

    final event = c.attemptMove('f', Direction.left);

    expect(event.kind, MoveEventKind.burned);
    expect(c.tiles, isEmpty, reason: '燃やした側も燃やされた側も消えるはず');
    expect(c.moveCount, 1);
  });

  test('炎どうしはぶつけられない', () {
    final c = GameController(_row([_fire('f1', 0), _fire('f2', 1)]));

    final event = c.attemptMove('f2', Direction.left);

    expect(event.kind, MoveEventKind.blocked);
    expect(c.tiles.length, 2);
    expect(c.moveCount, 0);
  });

  test('数字を炎にぶつけても燃えない（燃やせるのは炎から当てたときだけ）', () {
    // 数字 7 を炎へ当てにいく。炎は計算相手にならないので不成立。
    final c = GameController(_row([_num('a', 0, 7), _fire('f', 1)]));

    final event = c.attemptMove('a', Direction.right);

    expect(event.kind, MoveEventKind.blocked);
    expect(c.tiles.length, 2);
  });

  test('炎は計算に加わらない（演算子があっても合体しない）', () {
    final result = collide(
      moverValue: kFireValue,
      moverEdges: Edges.fromMap({'right': '+'}),
      targetValue: 3,
      targetEdges: Edges.fromMap(null),
      direction: Direction.right,
    );
    expect(result, isNull);
  });

  test('炎は出口から出られない', () {
    const exit = ExitSpec(row: 0, col: 3, direction: ExitDirection.right);
    expect(exit.accepts(kFireValue), isFalse);
  });

  test('燃やす向きの判定はソルバーと同じ', () {
    expect(canBurn(kFireValue, 5), isTrue);
    expect(canBurn(5, kFireValue), isFalse, reason: '数字から炎へは当てられない');
    expect(canBurn(kFireValue, kFireValue), isFalse, reason: '炎どうしは不可');
    expect(canBurn(5, 3), isFalse);
  });

  test('炎で最後のタイルが消えればクリアになる', () {
    final c = GameController(_row([_num('a', 0, 7), _fire('f', 1)]));

    c.attemptMove('f', Direction.left);

    expect(c.isCleared, isTrue, reason: '盤が空になればクリア');
  });
}
