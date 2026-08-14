#!/usr/bin/env bash
# Web 版をビルドする。開発中はこのスクリプト経由で作ること。
#
# --pwa-strategy=none が要点。既定のビルドは Service Worker を出力し、
# アプリを丸ごとブラウザにキャッシュする。本番配信では有用だが、
# 開発中は「直したのに古い画面が出続ける」という厄介な症状になり、
# しかも直っていないのかキャッシュなのか見分けがつかない。
#
# 以前これで、BGM を消して 50 面に増やしたあとも古い画面が出続け、
# 実装が動いていないように見える事故が起きた。
#
# 出力先を毎回消してから作るのは、削除したアセット（例: bgm_loop.wav）が
# 前回のビルド結果として残り続けるのを防ぐため。
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../number_puzzle" && pwd)"
cd "$APP_DIR"

export PATH="$PATH:/c/src/flutter/bin"
# OneDrive 配下の一時ディレクトリだと Dart の isolate 生成に失敗するので逃がす。
export TEMP="C:\\src\\flutter_tmp"
export TMP="C:\\src\\flutter_tmp"
mkdir -p /c/src/flutter_tmp

rm -rf build/web
flutter build web --release --pwa-strategy=none "$@"

echo
echo "配信されるアセット:"
find build/web/assets/assets -type f | sed "s|build/web/assets/assets/|  |"
