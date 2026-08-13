import 'package:flutter/material.dart';

/// デザイントークン ― 「オブシディアン」方向性。
/// 黒曜石のような艶のある暗いブロックに、面取りの角だけネオンの
/// リムライトが走る。演算子・床の種類は色相のファミリーで意味を持たせる
/// （寒色=氷/加減算寄り、紫=辺を変える床、琥珀=値を変える床）。
class AppColors {
  AppColors._();

  // ---- 地 ----
  static const ground = Color(0xFF0B0A0D);
  static const groundTop = Color(0xFF1B1720); // 盤面などの上方向グラデーション
  static const surface = Color(0xFF15131A); // カード・ダイアログ
  static const rule = Color(0xFF2A2732); // 罫線・薄い境界

  // ---- 文字 ----
  static const textPrimary = Color(0xFFF1EEE8);
  static const textMuted = Color(0xFF8C8798);

  // ---- タイル本体 ----
  static const tileTop = Color(0xFF242030);
  static const tileBottom = Color(0xFF131117);
  static const tileFixed = Color(0xFF3A3742);

  // ---- 壁（面取りブロック） ----
  static const wallBody = Color(0xFF1A1820);
  static const wallHighlight = Color(0xFF433F52);
  static const wallShadow = Color(0xFF050408);
  static const wallRim = Color(0xFF5FF0FF);

  // ---- アクセントの色ファミリー（床の種類・演算子の両方で使う） ----
  static const cyan = Color(0xFF5FF0FF); // 氷 / "+"
  static const violet = Color(0xFFBE8CFF); // 回転・入替 / "÷"
  static const amber = Color(0xFFFFC24D); // √・! / "×"
  static const magenta = Color(0xFFFF6FD8); // "−"

  static const gold = Color(0xFFFFD166); // 選択中・出口・クリア（＝行動できる合図）
  static const goldDeep = Color(0xFF2A1F04); // 金地に乗せる文字色

  static const warn = Color(0xFFFF5C5C); // 警告・手数オーバー
}

class AppTextStyles {
  AppTextStyles._();

  /// タイルの数字・演算子。等幅で揃える。
  static const tile = TextStyle(
    fontFamily: 'SFMono-Regular',
    fontFamilyFallback: [
      'Menlo',
      'Consolas',
      'Courier New',
      'monospace',
    ],
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 見出し。宝飾品のような艶のある暗い盤面に、上品なセリフ体を合わせる。
  static const display = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: [
      'Hiragino Mincho ProN',
      'Times New Roman',
      'serif',
    ],
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.4,
  );

  static const body = TextStyle(color: AppColors.textPrimary, height: 1.6);
  static const caption = TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      primary: AppColors.gold,
      secondary: AppColors.violet,
      surface: AppColors.surface,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.ground,
    fontFamily: 'Georgia',
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['Hiragino Mincho ProN', 'serif'],
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.goldDeep,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.rule, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.rule, thickness: 1),
  );
}
