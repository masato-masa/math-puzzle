#!/bin/bash
# 開発は C:\dev\number_puzzle（ASCIIパス）で行っているため、
# 完成物をユーザーのデスクトップ配下（このフォルダ）へ書き戻す。
# ビルド生成物（.dart_tool, build, ios/Pods 等）は同期しない。
set -e
SRC="/c/dev/number_puzzle"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rsync -a --delete \
  --exclude '.dart_tool/' \
  --exclude 'build/' \
  --exclude '.gradle/' \
  --exclude 'android/.gradle/' \
  --exclude 'ios/Pods/' \
  --exclude 'ios/.symlinks/' \
  --exclude '.flutter-plugins' \
  --exclude '.flutter-plugins-dependencies' \
  --exclude '*.iml' \
  --exclude '.idea/' \
  --exclude 'README.md' \
  --exclude 'sync_to_dev.sh' \
  --exclude 'sync_from_dev.sh' \
  "$SRC/" "$DST/" 2>/dev/null || {
    # rsync が無い環境向けのフォールバック（雑だが十分）
    cp -r "$SRC/lib" "$DST/"
    cp -r "$SRC/test" "$DST/"
    cp -r "$SRC/assets" "$DST/"
    cp -r "$SRC/android" "$DST/"
    cp -r "$SRC/ios" "$DST/"
    cp -r "$SRC/web" "$DST/"
    cp "$SRC/pubspec.yaml" "$DST/"
    cp "$SRC/pubspec.lock" "$DST/" 2>/dev/null || true
    cp "$SRC/analysis_options.yaml" "$DST/" 2>/dev/null || true
  }
# README.md と同期スクリプト自体はこのフォルダ（日本語パス側）を正として保持する
echo "synced from $SRC to $DST"
