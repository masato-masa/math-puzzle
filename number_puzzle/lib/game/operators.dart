/// 二項演算子のレジストリ。
///
/// 新しい演算子を追加するときは [Operators.register] を呼ぶだけでよい
/// （例: MOD 演算子を追加するなら `Operators.register('%', (a, b) => ...)`）。
/// ルールエンジンの他の部分（衝突判定・辺の描画）はこのレジストリを見るだけで、
/// 個別の演算子名をハードコードしない。
typedef BinaryApply = int? Function(int a, int b);

/// マイナスは扱わない（3.3 節参照）。同じ演算子でも当てる向きで A-B / B-A を
/// 選べてしまうため、引いて負になる向きは不成立にすることで
/// 「大きい方から当てる」という制約に転化している。
const int kMaxAbsValue = 100000;

class Operators {
  Operators._();

  static final Map<String, BinaryApply> _registry = {
    '+': (a, b) {
      final r = a + b;
      return r > kMaxAbsValue ? null : r;
    },
    '−': (a, b) {
      if (a < b) return null; // 負になる向きには当てられない
      final r = a - b;
      return r > kMaxAbsValue ? null : r;
    },
    '×': (a, b) {
      final r = a * b;
      return r > kMaxAbsValue ? null : r;
    },
    '÷': (a, b) {
      if (b == 0 || a % b != 0) return null; // 割り切れないなら不成立
      return a ~/ b;
    },
  };

  /// swap 床が入れ替える対。新しい演算子を追加してもここに登録しなければ
  /// swap 床の対象にはならない（登録は任意）。
  static final Map<String, String> _swapPairs = {
    '+': '−',
    '−': '+',
    '×': '÷',
    '÷': '×',
  };

  static void register(String symbol, BinaryApply apply, {String? swapWith}) {
    _registry[symbol] = apply;
    if (swapWith != null) {
      _swapPairs[symbol] = swapWith;
      _swapPairs[swapWith] = symbol;
    }
  }

  static bool isOperator(String? symbol) =>
      symbol != null && _registry.containsKey(symbol);

  static int? apply(String symbol, int a, int b) {
    final fn = _registry[symbol];
    return fn?.call(a, b);
  }

  static String? swapPair(String? symbol) {
    if (symbol == null) return null;
    return _swapPairs[symbol] ?? symbol;
  }
}
