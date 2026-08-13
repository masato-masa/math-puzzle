#!/bin/bash
# Windows のバッチスクリプト（flutter.bat 内部）が非ASCIIパスを正しく
# 扱えない問題があるため、実際のビルド/テストは C:\dev\number_puzzle
# （ASCIIのみのパス）で行う。このスクリプトは、ここ（ユーザーの
# デスクトップ配下、日本語パス）で編集したソースをそちらへ同期する。
set -e
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="/c/dev/number_puzzle"

cp -r "$SRC/lib/." "$DST/lib/"
cp -r "$SRC/assets/." "$DST/assets/"
cp -r "$SRC/test/." "$DST/test/"
cp "$SRC/pubspec.yaml" "$DST/pubspec.yaml" 2>/dev/null || true
echo "synced to $DST"
