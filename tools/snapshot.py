"""現在のソースを bk/<版名> へ退避する。

    python tools/snapshot.py v1
    python tools/snapshot.py v2 --note "UI改善: 移動先ハイライト"

git のタグ／コミットで履歴は追えるが、それとは別に
「その版のソース一式」をフォルダとして残しておくためのもの
（過去版を直接開いて見比べたい、という用途）。

ビルド生成物は含めない。bk/<版名>/SNAPSHOT.txt に、
いつ・どのコミットの状態かを書き残す。
"""

import os
import shutil
import subprocess
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BK = os.path.join(ROOT, "bk")

# 退避する対象（これ以外は入れない）
INCLUDE = ["number_puzzle", "tools", "assets", "docs", ".claude", ".gitignore"]

# 除外するディレクトリ名／ファイル名
SKIP_DIRS = {
    "build", ".dart_tool", "__pycache__", ".gradle", "ephemeral",
    "Pods", ".symlinks", ".idea", "bk",
}
SKIP_SUFFIX = (".pyc", ".iml")


def _ignore(dirpath, names):
    dropped = []
    for n in names:
        if n in SKIP_DIRS or n.endswith(SKIP_SUFFIX):
            dropped.append(n)
        elif n.startswith("_") and n.endswith(".txt"):
            dropped.append(n)          # 検証スクリプトの使い捨て出力
    return set(dropped)


def git(*args):
    # Windows の既定コードページ(cp932)だと日本語のコミットメッセージを
    # 読めずに落ちるので、必ず utf-8 として受け取る。
    try:
        out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                             check=True).stdout
        return out.decode("utf-8", errors="replace").strip()
    except Exception:
        return "(git 情報なし)"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    name = sys.argv[1]
    note = ""
    if "--note" in sys.argv:
        note = sys.argv[sys.argv.index("--note") + 1]

    dest = os.path.join(BK, name)
    if os.path.exists(dest):
        print(f"すでに存在します: {dest}")
        return 1

    os.makedirs(dest, exist_ok=True)
    for item in INCLUDE:
        src = os.path.join(ROOT, item)
        if not os.path.exists(src):
            continue
        target = os.path.join(dest, item)
        if os.path.isdir(src):
            shutil.copytree(src, target, ignore=_ignore)
        else:
            shutil.copy2(src, target)

    files = sum(len(f) for _, _, f in os.walk(dest))
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(os.path.join(dest, "SNAPSHOT.txt"), "w", encoding="utf-8") as f:
        f.write(f"版名: {name}\n")
        f.write(f"保存日時: {stamp}\n")
        f.write(f"コミット: {git('rev-parse', 'HEAD')}\n")
        f.write(f"コミット内容: {git('log', '-1', '--pretty=%s')}\n")
        if note:
            f.write(f"メモ: {note}\n")

    print(f"退避しました: {dest}（{files} ファイル）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
