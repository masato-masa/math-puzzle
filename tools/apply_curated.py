"""curate.py が出した定義を v3_levels.py の該当レベルへ差し替える。

    python tools/apply_curated.py _curated_a.txt _curated_b.txt

curate.py の出力は v3_levels.py にそのまま貼れる形になっているが、
28 面を手で貼り替えると貼り位置や括弧の対応を間違えやすい。
levelId をキーに、既存の定義ブロックを丸ごと置き換える。

既存の定義ブロックは
    {
        "levelId": "v3_00X",
        ...
    },
という形で、行頭 4 スペースの "{" から、同じ字下げの "}," までを 1 件とみなす。
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = os.path.join(HERE, "v3_levels.py")


def parse_blocks(text):
    """curate.py の出力から levelId -> 定義ブロック文字列 を作る。"""
    blocks = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].strip() == "{":
            start = i
            depth = 0
            while i < len(lines):
                depth += lines[i].count("{") + lines[i].count("[")
                depth -= lines[i].count("}") + lines[i].count("]")
                if depth == 0 and i > start:
                    break
                i += 1
            block = lines[start:i + 1]
            body = "\n".join(block)
            m = re.search(r'"levelId":\s*"([^"]+)"', body)
            if m:
                # 直後にコメント行（# par=...）があれば取り込む
                tail = i + 1
                extra = []
                while tail < len(lines) and lines[tail].strip().startswith("#"):
                    extra.append(lines[tail])
                    tail += 1
                blocks[m.group(1)] = "\n".join(block + extra)
                i = tail
                continue
        i += 1
    return blocks


def replace_in_target(src, level_id, new_block):
    """v3_levels.py 内の該当レベル定義を new_block で置き換える。"""
    lines = src.splitlines()
    # levelId の行を探し、そこから前後に広げて 1 件の範囲を決める
    idx = None
    for n, line in enumerate(lines):
        if re.search(r'"levelId":\s*"%s"' % re.escape(level_id), line):
            idx = n
            break
    if idx is None:
        return None

    # 上へ: 直前の行頭4スペースの "{" まで（その手前のコメント行も含める）。
    # ただしブロック区切りの飾り（"====" を含む見出しコメント）は
    # レベル定義ではなく構成の目印なので、巻き込まないで残す
    # （巻き込むと差し替えのたびに見出しが消え、ブロックの境目が
    #   分からなくなる）。
    start = idx
    while start > 0 and lines[start].strip() != "{":
        start -= 1
    while (start > 0
           and lines[start - 1].strip().startswith("#")
           and "=====" not in lines[start - 1]):
        start -= 1

    # 下へ: 括弧の対応が閉じる位置まで
    depth = 0
    end = start
    for n in range(start, len(lines)):
        depth += lines[n].count("{") + lines[n].count("[")
        depth -= lines[n].count("}") + lines[n].count("]")
        if depth == 0 and n > start:
            end = n
            break

    return "\n".join(lines[:start] + new_block.splitlines() + lines[end + 1:])


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    blocks = {}
    for path in sys.argv[1:]:
        full = path if os.path.isabs(path) else os.path.join(HERE, path)
        with open(full, encoding="utf-8") as f:
            blocks.update(parse_blocks(f.read()))

    with open(TARGET, encoding="utf-8") as f:
        src = f.read()

    applied, missing = [], []
    for level_id, block in sorted(blocks.items()):
        out = replace_in_target(src, level_id, block)
        if out is None:
            missing.append(level_id)
        else:
            src = out
            applied.append(level_id)

    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(src if src.endswith("\n") else src + "\n")

    print(f"差し替え {len(applied)} 件: {', '.join(applied)}")
    if missing:
        print(f"見つからなかった: {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
