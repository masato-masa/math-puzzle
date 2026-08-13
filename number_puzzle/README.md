# 数式パズル（Flutter 本番実装）

`docs/final-spec.html` の仕様に基づく本番実装。ルールエンジンは
`tools/v3_solver.py`（Python）で検証したものと 1:1 対応させてあり、
`tool/replay_solutions.dart` で全レベルの最短手順を実際にこの Dart 実装で
再生し、Python 側の par/limit と完全に一致することを確認済み。

## 開発環境についての重要な注意

このプロジェクトは Windows 上で開発しているが、**Flutter の内部バッチ
スクリプトが日本語ユーザー名や全角スペースを含むパスを正しく扱えない
不具合がある**（`将斗` ユーザーのホーム配下、`デスクトップ` を含むパス等）。
そのため：

- Flutter SDK 本体は `C:\dev\flutter`（ASCII のみのパス）に置く
- `flutter` コマンドの実行（build / test / run）は
  `C:\dev\number_puzzle`（このフォルダの ASCII コピー）で行う
- ここ（デスクトップ配下、日本語パス）はソースの置き場・編集場所として使い、
  `sync_to_dev.sh` で `C:\dev\number_puzzle` に反映してからコマンドを実行する
- 完成物を作業配下へ書き戻すときは `sync_from_dev.sh` を使う

```bash
# 編集後、ビルド/テストの前に必ず実行
bash sync_to_dev.sh

# C:\dev\number_puzzle 側でコマンドを実行
cd /c/dev/number_puzzle
```

## この環境固有のもう一つの制約: `flutter test` が使えない

このマシンでは `flutter_tester.exe`（`flutter test` が使う headless
エンジン）が起動直後にクラッシュする（トリビアルな `1+1==2` のテストすら
失敗する）。原因は Windows 環境固有の問題で、コードの不具合ではない
（`flutter_tester.exe --help` 単体は正常に動く一方、実際にテストを
実行しようとすると `STATUS_STACK_BUFFER_OVERRUN` で落ちる）。

この制約を踏まえ、**ゲームロジック層（`lib/game/`）は package:flutter に
一切依存しない純粋な Dart** にしてある（`dart:ui` が使えない素の Dart VM
でも動く）。検証は `flutter test` の代わりに、素の Dart VM で直接実行する：

```bash
# ルール（結合判定・床効果）の単体チェック
dart run tool/run_rules_check.dart

# 全レベルの最短手順再生（Python ソルバーとの整合性の最終確認）
dart run tool/replay_solutions.dart
```

`test/game_rules_test.dart` と `test/solutions_replay_test.dart` は
（`flutter_tester` が正常な環境向けに）標準的な `flutter_test` 形式でも
用意してある。上記スクリプトはそれと同じ内容を Flutter エンジンを介さずに
実行する代替手段。他の環境（macOS 等）で `flutter test` が正常に動くなら、
そちらを使ってよい。

## ビルド・実行

```bash
cd /c/dev/number_puzzle
flutter pub get
flutter analyze          # 0 issues であること
flutter run -d chrome    # ブラウザで動作確認（Windows では実機/シミュレータ不可）
```

Chrome での実機能検証は済んでいる（レベル選択→パズル画面遷移、タイル移動・
氷スライド・結合計算・回転/√床の消費・Undo・出口・クリア/次のレベルへの
一連の流れを実際のブラウザで確認済み）。

## iOS ビルドについて

iOS 版のビルド・実機/シミュレータ実行・App Store 申請は **macOS + Xcode が
必須**（Apple の制約）。このプロジェクトは `flutter create --platforms=ios`
で iOS 用のプロジェクトファイル一式を生成済みだが、実際のビルドは Mac 上で
行う必要がある。

```bash
# Mac 上で
cd number_puzzle
flutter pub get
flutter build ios          # または flutter run -d <iOS実機/シミュレータ>
open ios/Runner.xcworkspace  # 署名設定・申請は Xcode から
```

## 音源について

`assets/audio/*.wav` は `tools/gen_audio.py`（リポジトリのプロジェクトルート
側）が正弦波合成で生成したプレースホルダー。ライセンスのある実際の楽曲・
効果音が用意でき次第、同じファイル名で差し替えるだけでよい
（`lib/services/sound_service.dart` はファイルパスしか見ていない）。

| ファイル | 用途 |
|---|---|
| `bgm_loop.wav` | 常時再生する BGM（ループ） |
| `sfx_move.wav` | 通常の移動 |
| `sfx_slide.wav` | 氷で滑ったとき |
| `sfx_merge.wav` | 衝突して計算が成立したとき |
| `sfx_exit.wav` | 出口から出したとき |
| `sfx_blocked.wav` | 手が成立しなかったとき |
| `sfx_undo.wav` | 「戻す」 |
| `sfx_win.wav` | クリア |
| `sfx_fail.wav` | 手数オーバー |

## マネタイズについて

`lib/services/monetization.dart` に `AdService` / `PurchaseService` の
no-op 実装のみ置いてある。広告・課金 SDK は未導入（意図的にスコープ外）。
将来 SDK を導入する際は、この 2 つのインターフェースを実装したクラスを
追加し、`lib/main.dart` の生成箇所を差し替えるだけでよい。

## レベル・コースの追加

`lib/game/level_repository.dart` の `kCourseFiles` にファイル名を足し、
`assets/levels/` に新しいコース JSON を置くだけでよい（コード変更不要）。
レベルデータは手作りではなく `tools/v3_levels.py` で検証・生成すること
（クリア可能性・最短手数・解法が一意であること・床が本当に必要かを
機械的にチェックしている）。
