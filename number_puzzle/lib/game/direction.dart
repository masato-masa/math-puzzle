/// 移動方向。辺の並び順（up, right, down, left）は全ての辺表現の基準になる。
enum Direction { up, right, down, left }

const List<Direction> kAllDirections = [
  Direction.up,
  Direction.right,
  Direction.down,
  Direction.left,
];

extension DirectionX on Direction {
  /// (dRow, dCol)
  (int, int) get delta => switch (this) {
        Direction.up => (-1, 0),
        Direction.right => (0, 1),
        Direction.down => (1, 0),
        Direction.left => (0, -1),
      };

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.right => Direction.left,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
      };

  static Direction? fromName(String name) {
    for (final d in kAllDirections) {
      if (d.name == name) return d;
    }
    return null;
  }
}
