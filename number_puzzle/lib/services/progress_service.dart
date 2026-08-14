import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LevelProgress {
  final bool cleared;
  final int bestMoves;

  /// ヒント・アンドゥを一度も使わずにクリアしたことがあるか。
  /// 全レベル手数の余裕がゼロ（limit == par）という設計上、
  /// 「手数の効率」では差がつかない（最短手順以外はそもそもクリアできない）。
  /// 差がつくのはここだけなので、効率バッジの代わりにこれを実績として見せる。
  final bool everPerfect;

  const LevelProgress({
    required this.cleared,
    required this.bestMoves,
    this.everPerfect = false,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        cleared: json['cleared'] as bool,
        bestMoves: json['bestMoves'] as int,
        everPerfect: json['everPerfect'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'cleared': cleared, 'bestMoves': bestMoves, 'everPerfect': everPerfect};
}

/// レベルごとのクリア状況を保存する。final-spec.html の「保存」節に準拠:
/// レベル ID → {cleared, bestMoves, everPerfect} のみを持つ軽量なキー・バリューデータ。
///
/// ストレージが使えない環境（プライベートモード相当）でも進行は継続できるよう、
/// 失敗は握りつぶして呼び出し側には影響させない。
class ProgressService {
  static const _key = 'number_puzzle_progress_v1';

  Future<Map<String, LevelProgress>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map(
        (k, v) => MapEntry(k, LevelProgress.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> recordClear(String levelId, int moves, {bool perfect = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await loadAll();
      final prev = all[levelId];
      final best = prev == null ? moves : (moves < prev.bestMoves ? moves : prev.bestMoves);
      all[levelId] = LevelProgress(
        cleared: true,
        bestMoves: best,
        everPerfect: perfect || (prev?.everPerfect ?? false),
      );
      final json = all.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_key, jsonEncode(json));
    } catch (_) {
      // 保存に失敗してもゲーム進行は継続する
    }
  }
}
