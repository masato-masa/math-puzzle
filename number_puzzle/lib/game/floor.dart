/// 床（マス）の種類。
///
/// ice のみ回数無制限。それ以外は Level 側で uses（残り回数）を指定する。
/// 新しい床の種類を足す場合は、この enum に追加した上で
/// `game_rules.dart` の applyFloorEffect の switch にケースを足す
/// （switch を exhaustive にしているのは、新種を追加したときに
/// 対応漏れがあればコンパイルエラーで気付けるようにするため）。
enum FloorKind { ice, rotate, swap, sqrt, fact }

extension FloorKindX on FloorKind {
  static FloorKind? fromName(String name) {
    for (final k in FloorKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }

  /// 値ではなく辺に作用する床か
  bool get actsOnEdges => this == FloorKind.rotate || this == FloorKind.swap;
}

class FloorTile {
  final int row;
  final int col;
  final FloorKind kind;
  final int? uses; // null = 無制限（ice は常にこれ）

  const FloorTile({
    required this.row,
    required this.col,
    required this.kind,
    this.uses,
  });

  factory FloorTile.fromJson(Map<String, dynamic> json) {
    final kind = FloorKindX.fromName(json['type'] as String);
    if (kind == null) {
      throw FormatException('未知の床タイプ: ${json['type']}');
    }
    return FloorTile(
      row: json['row'] as int,
      col: json['col'] as int,
      kind: kind,
      uses: kind == FloorKind.ice ? null : json['uses'] as int?,
    );
  }
}
