/// コアルール（純粋関数）。tools/v3_rules.py と 1:1 対応させてある。
///
/// UI にもゲーム状態にも依存しない。ここだけを見れば「数式パズルとは何か」が
/// 完結して分かるようにしてあり、ユニットテスト（test/game_rules_test.dart）も
/// この層だけを対象にしている。
library;

import 'direction.dart';
import 'edges.dart';
import 'floor.dart';
import 'operators.dart';

const int kMaxFactorialInput = 8;

/// 炎タイルの目印。盤の数字は 0 以上なので、負の値なら炎だと分かる。
/// tools/v3_rules.py の FIRE と同じ値。
const int kFireValue = -1;

bool isFire(int value) => value == kFireValue;

/// 炎タイルがぶつかったときに燃やせるか。
///
/// 炎は数字を 1 枚燃やして消し、燃やした炎自身も消える。
/// 「どのタイルを諦めるか」を 1 回だけ選べる資源になる。
/// 出せない数を作ってしまっても炎で始末できる代わりに、
/// 向ける先を間違えると本当に必要な数を失う。
///
/// 炎どうしはぶつけられない（どちらが残るか決められないため）。
bool canBurn(int moverValue, int targetValue) =>
    isFire(moverValue) && !isFire(targetValue);

int _factorial(int n) {
  var r = 1;
  for (var i = 2; i <= n; i++) {
    r *= i;
  }
  return r;
}

int _isqrtFloor(int n) {
  if (n == 0) return 0;
  var x = n, y = (x + 1) ~/ 2;
  while (y < x) {
    x = y;
    y = (x + n ~/ x) ~/ 2;
  }
  return x;
}

int? _isqrtExact(int n) {
  if (n < 0) return null;
  final r = _isqrtFloor(n);
  return r * r == n ? r : null;
}

/// 3.3 節: 衝突判定。mover が先・target が後という順序を厳守する。
///
/// 接触するのは mover の進行方向の辺と、target のその逆向きの辺。
/// 片方だけに演算子があるときだけ成立し、成立した場合に残るのは
/// 「target の、使わなかった辺」だけ（mover 側の辺は全て消える）。
class CollideResult {
  final int value;
  final Edges edges;

  /// 実際に使われた演算子（+/−/×/÷）。演算子ごとに違う効果音を
  /// 鳴らし分けるのに使う（判定そのものには影響しない）。
  final String op;
  const CollideResult(this.value, this.edges, this.op);
}

CollideResult? collide({
  required int moverValue,
  required Edges moverEdges,
  required int targetValue,
  required Edges targetEdges,
  required Direction direction,
}) {
  // 炎は計算に加わらない（燃やすだけ）。
  if (isFire(moverValue) || isFire(targetValue)) return null;

  final mEdge = moverEdges[direction];
  final tEdge = targetEdges[direction.opposite];
  final mHas = Operators.isOperator(mEdge);
  final tHas = Operators.isOperator(tEdge);
  if (mHas == tHas) return null; // 両方にある／どちらにも無い → 不成立

  final op = mHas ? mEdge! : tEdge!;
  final value = Operators.apply(op, moverValue, targetValue);
  if (value == null) return null;

  final edges = targetEdges.withCleared(direction.opposite);
  return CollideResult(value, edges, op);
}

/// 床に止まったときの効果。
///
/// [rejected] が true のときはその床に入れない（例: 平方数でない値が
/// √ マスに来た）。呼び出し側はこの手自体を無効化し、[value]/[edges] は
/// 使わない（元の値をそのまま入れてあるだけ）。
/// [spend] は残り回数を 1 消費するべきかどうか。
class FloorLandResult {
  final int value;
  final Edges edges;
  final bool spend;
  final bool rejected;

  const FloorLandResult({
    required this.value,
    required this.edges,
    this.spend = false,
    this.rejected = false,
  });
}

/// 床の効果を適用する。[usesLeft] は「回数制限のある床」の残り回数
/// （制限が無ければ null）。使い切った床（0 以下）はただの床として扱う。
FloorLandResult applyFloorLanding({
  required FloorKind? kind,
  required int value,
  required Edges edges,
  required int? usesLeft,
}) {
  if (kind == null || kind == FloorKind.ice) {
    return FloorLandResult(value: value, edges: edges);
  }
  if (usesLeft != null && usesLeft <= 0) {
    return FloorLandResult(value: value, edges: edges); // 使い切ったマスはただの床
  }
  switch (kind) {
    case FloorKind.rotate:
      return FloorLandResult(value: value, edges: edges.rotatedCw(), spend: true);
    case FloorKind.swap:
      return FloorLandResult(value: value, edges: edges.swapped(), spend: true);
    case FloorKind.sqrt:
      final r = _isqrtExact(value);
      if (r == null) return FloorLandResult(value: value, edges: edges, rejected: true);
      return FloorLandResult(value: r, edges: edges, spend: true);
    case FloorKind.fact:
      if (value < 0 || value > kMaxFactorialInput) {
        return FloorLandResult(value: value, edges: edges, rejected: true);
      }
      return FloorLandResult(value: _factorial(value), edges: edges, spend: true);
    case FloorKind.ice:
      return FloorLandResult(value: value, edges: edges);
  }
}
