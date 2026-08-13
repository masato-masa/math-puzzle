import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/floor.dart';
import 'package:number_puzzle/game/game_rules.dart';

Edges e(Map<String, String> m) => Edges.fromMap(m);

void main() {
  group('collide', () {
    test('片方だけに演算子があれば成立する（大きい方から引く）', () {
      final r = collide(
        moverValue: 9,
        moverEdges: Edges.empty(),
        targetValue: 4,
        targetEdges: e({'left': '−'}),
        direction: Direction.right,
      );
      expect(r, isNotNull);
      expect(r!.value, 5);
    });

    test('逆向き（小さい方から引く）は不成立', () {
      final r = collide(
        moverValue: 4,
        moverEdges: e({'right': '−'}),
        targetValue: 9,
        targetEdges: Edges.empty(),
        direction: Direction.right,
      );
      expect(r, isNull);
    });

    test('ちょうど 0 は許容する', () {
      final r = collide(
        moverValue: 5,
        moverEdges: Edges.empty(),
        targetValue: 5,
        targetEdges: e({'left': '−'}),
        direction: Direction.right,
      );
      expect(r!.value, 0);
    });

    test('両方に演算子があると不成立', () {
      final r = collide(
        moverValue: 7,
        moverEdges: e({'right': '+'}),
        targetValue: 3,
        targetEdges: e({'left': '−'}),
        direction: Direction.right,
      );
      expect(r, isNull);
    });

    test('どちらにも演算子が無いと不成立', () {
      final r = collide(
        moverValue: 7,
        moverEdges: Edges.empty(),
        targetValue: 3,
        targetEdges: Edges.empty(),
        direction: Direction.right,
      );
      expect(r, isNull);
    });

    test('割り切れない割り算は不成立', () {
      final r = collide(
        moverValue: 7,
        moverEdges: Edges.empty(),
        targetValue: 2,
        targetEdges: e({'left': '÷'}),
        direction: Direction.right,
      );
      expect(r, isNull);
    });

    test('残るのは target の使わなかった辺だけ', () {
      final r = collide(
        moverValue: 7,
        moverEdges: e({'up': '×'}), // 使われない mover 側の辺
        targetValue: 3,
        targetEdges: e({'left': '−', 'down': '×'}), // down は使われない target 側の辺
        direction: Direction.right,
      );
      expect(r!.value, 4);
      expect(r.edges[Direction.left], isNull); // 使った辺は消える
      expect(r.edges[Direction.down], '×'); // 使わなかった辺は残る
      expect(r.edges[Direction.up], isNull); // mover の辺は最初から関係ない
    });

    test('8 を ÷4 にぶつけると 8÷4 になる（ぶつけた側が左辺）', () {
      final r = collide(
        moverValue: 8,
        moverEdges: Edges.empty(),
        targetValue: 4,
        targetEdges: e({'left': '÷'}),
        direction: Direction.right,
      );
      expect(r!.value, 2);
    });
  });

  group('floor effects', () {
    test('sqrt: 平方数ならその平方根になる', () {
      final r = applyFloorLanding(
        kind: FloorKind.sqrt,
        value: 36,
        edges: Edges.empty(),
        usesLeft: 1,
      );
      expect(r.rejected, isFalse);
      expect(r.value, 6);
      expect(r.spend, isTrue);
    });

    test('sqrt: 平方数でなければ拒否される', () {
      final r = applyFloorLanding(
        kind: FloorKind.sqrt,
        value: 37,
        edges: Edges.empty(),
        usesLeft: 1,
      );
      expect(r.rejected, isTrue);
    });

    test('fact: 0〜8 なら階乗になる', () {
      final r = applyFloorLanding(
        kind: FloorKind.fact,
        value: 4,
        edges: Edges.empty(),
        usesLeft: 1,
      );
      expect(r.value, 24);
    });

    test('fact: 範囲外は拒否される', () {
      final r = applyFloorLanding(
        kind: FloorKind.fact,
        value: 9,
        edges: Edges.empty(),
        usesLeft: 1,
      );
      expect(r.rejected, isTrue);
    });

    test('rotate: 時計回りで up→right, right→down に移る', () {
      final edges = e({'up': '+', 'right': '×'});
      final r = applyFloorLanding(
        kind: FloorKind.rotate,
        value: 5,
        edges: edges,
        usesLeft: 1,
      );
      expect(r.edges[Direction.right], '+');
      expect(r.edges[Direction.down], '×');
      expect(r.edges[Direction.up], isNull);
      expect(r.edges[Direction.left], isNull);
    });

    test('swap: + <-> −, × <-> ÷', () {
      final edges = e({'up': '+', 'right': '×', 'down': '−', 'left': '÷'});
      final r = applyFloorLanding(
        kind: FloorKind.swap,
        value: 5,
        edges: edges,
        usesLeft: 1,
      );
      expect(r.edges[Direction.up], '−');
      expect(r.edges[Direction.right], '÷');
      expect(r.edges[Direction.down], '+');
      expect(r.edges[Direction.left], '×');
    });

    test('残り回数 0 の床は素通りする（ただの床になる）', () {
      final r = applyFloorLanding(
        kind: FloorKind.rotate,
        value: 5,
        edges: e({'up': '+'}),
        usesLeft: 0,
      );
      expect(r.spend, isFalse);
      expect(r.edges[Direction.up], '+'); // 回転しない
    });

    test('ice は値も辺も変えない', () {
      final edges = e({'up': '+'});
      final r = applyFloorLanding(
        kind: FloorKind.ice,
        value: 5,
        edges: edges,
        usesLeft: null,
      );
      expect(r.value, 5);
      expect(r.edges[Direction.up], '+');
    });
  });
}
