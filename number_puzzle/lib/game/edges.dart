import 'direction.dart';
import 'operators.dart';

/// タイルの 4 辺に付いた演算子。null はその辺に演算子が無いことを表す。
/// 内部表現は Direction.index（up=0, right=1, down=2, left=3）で揃える。
class Edges {
  final List<String?> _values;

  Edges(List<String?> values)
      : assert(values.length == 4),
        _values = List.unmodifiable(values);

  factory Edges.empty() => Edges(List<String?>.filled(4, null));

  factory Edges.fromMap(Map<String, dynamic>? map) {
    final v = List<String?>.filled(4, null);
    if (map != null) {
      for (final d in kAllDirections) {
        final op = map[d.name];
        if (op != null) v[d.index] = op as String;
      }
    }
    return Edges(v);
  }

  String? operator [](Direction d) => _values[d.index];

  bool get isEmpty => _values.every((v) => v == null);

  Edges withCleared(Direction d) {
    final v = List<String?>.from(_values);
    v[d.index] = null;
    return Edges(v);
  }

  /// (up, right, down, left) -> (left, up, right, down)
  Edges rotatedCw() => Edges([_values[3], _values[0], _values[1], _values[2]]);

  Edges swapped() =>
      Edges(_values.map((op) => Operators.swapPair(op)).toList());

  Map<String, String> toMap() {
    final m = <String, String>{};
    for (final d in kAllDirections) {
      final op = _values[d.index];
      if (op != null) m[d.name] = op;
    }
    return m;
  }

  @override
  String toString() => 'Edges(${toMap()})';
}
