"""検証済み levels_v3.json を v3 の POC に埋め込み、デスクトップへ配る。"""

import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEVELS_JSON = os.path.join(ROOT, "assets", "levels", "levels_v3.json")
POC_HTML = os.path.join(ROOT, "number-puzzle-v3.html")
DESKTOP_COPY = os.path.join(os.path.expanduser("~"), "OneDrive", "デスクトップ",
                            "数式パズル_v3.html")

BEGIN = "/* LEVELS:BEGIN */"
END = "/* LEVELS:END */"


def main():
    with open(LEVELS_JSON, encoding="utf-8") as f:
        levels = json.load(f)["levels"]

    js = "const LEVELS = " + json.dumps(levels, ensure_ascii=False, indent=2) + ";"
    with open(POC_HTML, encoding="utf-8") as f:
        html = f.read()
    i = html.index(BEGIN) + len(BEGIN)
    j = html.index(END)
    html = html[:i] + "\n" + js + "\n" + html[j:]
    with open(POC_HTML, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"v3 POC に {len(levels)} レベルを埋め込みました")

    if os.path.isdir(os.path.dirname(DESKTOP_COPY)):
        shutil.copyfile(POC_HTML, DESKTOP_COPY)
        print(f"デスクトップへコピー: {DESKTOP_COPY}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
