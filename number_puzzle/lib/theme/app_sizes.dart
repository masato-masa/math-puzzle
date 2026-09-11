/// 全ゲーム共通のクロームの寸法。
///
/// 色は共通化しない（このゲームだけ黒地にネオンのリムライトで、これが盤面の
/// 読みやすさそのものなので、クリーム地に載せると盤が読めなくなる）。
/// 揃えるのは**形と配置**だけ ―
/// C:\claude\shared-ui\tokens.css の寸法をそのまま写している。
class AppSizes {
  AppSizes._();

  /// 指のタップに必要な最小の当たり判定。
  static const hit = 44.0;

  /// 丸アイコンボタンの見た目の大きさ。当たり判定は [hit] まで広げる。
  static const iconButton = 36.0;

  /// フッターのツール行の丸ボタン。
  static const toolButton = 60.0;

  /// ヘッダー 2 段目の固定高。中身が空でもこの高さを取り、
  /// 盤面の縦位置が画面によってずれないようにする。
  static const statusBar = 30.0;

  /// ツール行のボタン同士の間隔。
  static const toolGap = 24.0;

  static const cardRadius = 16.0;
  static const sheetRadius = 22.0;
}
