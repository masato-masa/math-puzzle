import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LevelProgress {
  final bool cleared;
  final int bestMoves;
  const LevelProgress({required this.cleared, required this.bestMoves});

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        cleared: json['cleared'] as bool,
        bestMoves: json['bestMoves'] as int,
      );

  Map<String, dynamic> toJson() => {'cleared': cleared, 'bestMoves': bestMoves};
}

/// レベルごとのクリア状況を保存する。final-spec.html の「保存」節に準拠:
/// レベル ID → {cleared, bestMoves} のみを持つ軽量なキー・バリューデータ。
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

  Future<void> recordClear(String levelId, int moves) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await loadAll();
      final prev = all[levelId];
      final best = prev == null ? moves : (moves < prev.bestMoves ? moves : prev.bestMoves);
      all[levelId] = LevelProgress(cleared: true, bestMoves: best);
      final json = all.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_key, jsonEncode(json));
    } catch (_) {
      // 保存に失敗してもゲーム進行は継続する
    }
  }
}
