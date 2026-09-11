import 'package:shared_preferences/shared_preferences.dart';

/// 設定。今は音の入切だけ。
///
/// 4 つのゲームで同じ扱いにしてある（設定シートの中に音の入切だけを置き、
/// 次に開いたときも残す）。ストレージが使えない環境でも遊べるように、
/// 失敗は握りつぶして既定値（鳴らす）で続ける。
class SettingsService {
  static const _sfxKey = 'number_puzzle_sfx_enabled';

  bool _sfxEnabled = true;

  bool get sfxEnabled => _sfxEnabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sfxEnabled = prefs.getBool(_sfxKey) ?? true;
    } catch (_) {
      _sfxEnabled = true;
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sfxKey, value);
    } catch (_) {
      // 保存できなくても、その場の入切は効いている
    }
  }
}
