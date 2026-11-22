#!/usr/bin/env bash
# gh-pages へ web 版を公開する。master には一切コミットしない。
#
# 失敗経路: どこかで失敗したら set -e で即止まる。公開用の worktree が作れなかったら
# （以前は cd に失敗したまま後ろの git add -A / commit / push がメインのリポジトリで走り、
#  ビルドの生成物が master に載ってしまった）その場で終了する。
# 使い方: bash tools/deploy_web.sh "コミットメッセージの説明"
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO/number_puzzle"
# Windows の git が読める形（C:/...）の絶対パスにする。/c/... のままだと C:\c\... という別の場所に作られる
WT="$(cygpath -m "$REPO/..")/_math-puzzle-gh.tmp"
MSG="${1:-update}"

export PATH="$PATH:/c/src/flutter/bin"
export TEMP="C:\src\flutter_tmp"
export TMP="C:\src\flutter_tmp"
mkdir -p /c/src/flutter_tmp

cd "$APP"
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /math-puzzle/
test -f build/web/index.html || { echo "ビルドが無い。中止"; exit 1; }

cd "$REPO"
git fetch -q origin gh-pages
git worktree prune
git branch -D ghp-tmp 2>/dev/null || true
git worktree add -B ghp-tmp "$WT" origin/gh-pages
# 作れていなければ、ここで止まる（以降は worktree の中だけを触る）
test -d "$WT/.git" || test -f "$WT/.git" || { echo "worktree が作れなかった。中止"; exit 1; }
cleanup() { cd "$REPO"; git worktree remove --force "$WT" 2>/dev/null || true; git branch -D ghp-tmp -q 2>/dev/null || true; rm -rf "$APP/build"; }
trap cleanup EXIT

cd "$WT"
test "$(git rev-parse --abbrev-ref HEAD)" = "ghp-tmp" || { echo "worktree のブランチが違う。中止"; exit 1; }
git rm -rq --ignore-unmatch .
cp -r "$APP/build/web/." .
touch .nojekyll
git add -A
git commit -q -m "deploy $(date -u +%FT%TZ) $MSG"
git push origin HEAD:gh-pages
echo "gh-pages へ反映しました"
