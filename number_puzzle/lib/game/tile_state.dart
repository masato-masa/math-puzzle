import 'edges.dart';

/// 盤面上の 1 タイルの可変状態（レベル定義の TileSpec とは別物）。
/// GameController がこれを直接書き換え、Undo 用にスナップショットを取る。
class TileState {
  final String id;
  int row;
  int col;
  int value;
  Edges edges;
  final bool fixed;

  TileState({
    required this.id,
    required this.row,
    required this.col,
    required this.value,
    required this.edges,
    required this.fixed,
  });

  TileState clone() => TileState(
        id: id,
        row: row,
        col: col,
        value: value,
        edges: edges,
        fixed: fixed,
      );
}
