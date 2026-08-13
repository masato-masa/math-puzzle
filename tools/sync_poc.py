"""検証済み levels.json を POC(HTML) と Flutter アセットへ同期する。

レベルデータの正は assets/levels/levels.json（build_levels.py が生成）。
HTML は file:// で開くため fetch できないので、マーカーの間に直接埋め込む。
"""

import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEVELS_JSON = os.path.join(ROOT, "assets", "levels", "levels.json")
POC_HTML = os.path.join(ROOT, "number-puzzle-poc.html")
FLUTTER_ASSET = os.path.join(ROOT, "number_puzzle", "assets", "levels", "levels.json")
DESKTOP_COPY = os.path.join(os.path.expanduser("~"), "OneDrive", "デスクトップ", "数式パズル.html")

BEGIN = "/* LEVELS:BEGIN */"
END = "/* LEVELS:END */"


def main():
    with open(LEVELS_JSON, encoding="utf-8") as f:
        data = json.load(f)
    levels = data["levels"]

    js = "const LEVELS = " + json.dumps(levels, ensure_ascii=False, indent=2) + ";"

    with open(POC_HTML, encoding="utf-8") as f:
        html = f.read()
    i = html.index(BEGIN) + len(BEGIN)
    j = html.index(END)
    html = html[:i] + "\n" + js + "\n" + html[j:]
    with open(POC_HTML, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"POC に {len(levels)} レベルを埋め込みました: {POC_HTML}")

    if os.path.isdir(os.path.dirname(FLUTTER_ASSET)):
        shutil.copyfile(LEVELS_JSON, FLUTTER_ASSET)
        print(f"Flutter アセットへコピー: {FLUTTER_ASSET}")

    if os.path.isdir(os.path.dirname(DESKTOP_COPY)):
        shutil.copyfile(POC_HTML, DESKTOP_COPY)
        print(f"デスクトップへコピー: {DESKTOP_COPY}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
