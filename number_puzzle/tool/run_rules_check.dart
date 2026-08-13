// game_rules_test.dart の内容を、flutter_tester を使わず素の Dart VM で
// 検証するための簡易ランナー（flutter test がこの環境で使えないため）。
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/floor.dart';
import 'package:number_puzzle/game/game_rules.dart';

int _ok = 0;
int _ng = 0;

void check(String name, bool Function() body) {
  try {
    if (body()) {
      _ok++;
    } else {
      _ng++;
      print('[NG] $name');
    }
  } catch (e) {
    _ng++;
    print('[NG] $name (exception: $e)');
  }
}

Edges e(Map<String, String> m) => Edges.fromMap(m);

void main() {
  check('片方だけに演算子があれば成立する（大きい方から引く）', () {
    final r = collide(
      moverValue: 9,
      moverEdges: Edges.empty(),
      targetValue: 4,
      targetEdges: e({'left': '−'}),
      direction: Direction.right,
    );
    return r != null && r.value == 5;
  });

  check('逆向き（小さい方から引く）は不成立', () {
    final r = collide(
      moverValue: 4,
      moverEdges: e({'right': '−'}),
      targetValue: 9,
      targetEdges: Edges.empty(),
      direction: Direction.right,
    );
    return r == null;
  });

  check('ちょうど0は許容する', () {
    final r = collide(
      moverValue: 5,
      moverEdges: Edges.empty(),
      targetValue: 5,
      targetEdges: e({'left': '−'}),
      direction: Direction.right,
    );
    return r != null && r.value == 0;
  });

  check('両方に演算子があると不成立', () {
    final r = collide(
      moverValue: 7,
      moverEdges: e({'right': '+'}),
      targetValue: 3,
      targetEdges: e({'left': '−'}),
      direction: Direction.right,
    );
    return r == null;
  });

  check('どちらにも演算子が無いと不成立', () {
    final r = collide(
      moverValue: 7,
      moverEdges: Edges.empty(),
      targetValue: 3,
      targetEdges: Edges.empty(),
      direction: Direction.right,
    );
    return r == null;
  });

  check('割り切れない割り算は不成立', () {
    final r = collide(
      moverValue: 7,
      moverEdges: Edges.empty(),
      targetValue: 2,
      targetEdges: e({'left': '÷'}),
      direction: Direction.right,
    );
    return r == null;
  });

  check('残るのはtargetの使わなかった辺だけ', () {
    final r = collide(
      moverValue: 7,
      moverEdges: e({'up': '×'}),
      targetValue: 3,
      targetEdges: e({'left': '−', 'down': '×'}),
      direction: Direction.right,
    );
    return r != null &&
        r.value == 4 &&
        r.edges[Direction.left] == null &&
        r.edges[Direction.down] == '×' &&
        r.edges[Direction.up] == null;
  });

  check('8を÷4にぶつけると8÷4になる', () {
    final r = collide(
      moverValue: 8,
      moverEdges: Edges.empty(),
      targetValue: 4,
      targetEdges: e({'left': '÷'}),
      direction: Direction.right,
    );
    return r != null && r.value == 2;
  });

  check('sqrt: 平方数ならその平方根になる', () {
    final r = applyFloorLanding(
        kind: FloorKind.sqrt, value: 36, edges: Edges.empty(), usesLeft: 1);
    return !r.rejected && r.value == 6 && r.spend;
  });

  check('sqrt: 平方数でなければ拒否される', () {
    final r = applyFloorLanding(
        kind: FloorKind.sqrt, value: 37, edges: Edges.empty(), usesLeft: 1);
    return r.rejected;
  });

  check('fact: 0〜8なら階乗になる', () {
    final r = applyFloorLanding(
        kind: FloorKind.fact, value: 4, edges: Edges.empty(), usesLeft: 1);
    return r.value == 24;
  });

  check('fact: 範囲外は拒否される', () {
    final r = applyFloorLanding(
        kind: FloorKind.fact, value: 9, edges: Edges.empty(), usesLeft: 1);
    return r.rejected;
  });

  check('rotate: 時計回りで up→right, right→down に移る', () {
    final edges = e({'up': '+', 'right': '×'});
    final r = applyFloorLanding(
        kind: FloorKind.rotate, value: 5, edges: edges, usesLeft: 1);
    return r.edges[Direction.right] == '+' &&
        r.edges[Direction.down] == '×' &&
        r.edges[Direction.up] == null &&
        r.edges[Direction.left] == null;
  });

  check('swap: + <-> −, × <-> ÷', () {
    final edges = e({'up': '+', 'right': '×', 'down': '−', 'left': '÷'});
    final r = applyFloorLanding(
        kind: FloorKind.swap, value: 5, edges: edges, usesLeft: 1);
    return r.edges[Direction.up] == '−' &&
        r.edges[Direction.right] == '÷' &&
        r.edges[Direction.down] == '+' &&
        r.edges[Direction.left] == '×';
  });

  check('残り回数0の床は素通りする', () {
    final r = applyFloorLanding(
        kind: FloorKind.rotate, value: 5, edges: e({'up': '+'}), usesLeft: 0);
    return !r.spend && r.edges[Direction.up] == '+';
  });

  check('iceは値も辺も変えない', () {
    final edges = e({'up': '+'});
    final r = applyFloorLanding(
        kind: FloorKind.ice, value: 5, edges: edges, usesLeft: null);
    return r.value == 5 && r.edges[Direction.up] == '+';
  });

  print('\n$_ok 件成功 / $_ng 件失敗');
  if (_ng > 0) {
    // ignore: avoid_print
    print('失敗あり');
  }
}
