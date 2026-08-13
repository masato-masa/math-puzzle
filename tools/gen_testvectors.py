"""JS(POC) と Dart(本実装) のルールを突き合わせるためのテストベクタを生成する。

Python 実装（tools/puzzle_rules.py）を正解とみなし、
入力と期待値の組を JSON で出力する。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from puzzle_rules import try_merge, can_exit  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

MERGE_CASES = [
    ([8], ["÷", 4]),          # 基本の結合 -> 2
    (["÷", 4], [8]),          # 逆向きは数字どうしで不可
    ([3], ["+"]),             # 未完成の式になる
    ([3, "+"], [5]),          # 完成して 8
    ([5], ["+"]),
    ([5, "+"], [3]),
    ([7], ["÷", 2]),          # 割り切れない -> 不可
    ([4], ["+"]),
    (["+"], ["×"]),           # 演算子どうし -> 不可
    ([4], [5]),               # 数字どうし -> 不可
    (["√"], [36]),            # 平方根 -> 6
    (["√"], [37]),            # 整数にならない -> 不可
    ([6], ["+", 4]),
    ([4], ["!"]),             # 階乗 -> 24
    ([4, "!"], ["÷", 6]),     # 24 ÷ 6 -> 4
    (["!"], [5]),             # 後置なのに前 -> 不可
    ([3], ["^", 3]),          # 累乗 -> 27
    ([27], ["−", 7]),
    ([2], ["×", 3]),
    ([2, "×"], [3]),
    ([9], ["×", 3]),
    ([27], ["−", 5]),
    ([9], ["−", 5]),
    ([10], ["−"]),
    ([10, "−"], [2]),
    ([8], ["÷", 2]),
    ([96], ["÷"]),
    ([96, "÷"], [4]),
    ([24], ["+"]),
    ([24, "+"], [24]),
    ([6], ["×"]),
    ([6, "×"], [7]),
    ([12], ["÷"]),
    ([12, "÷"], [4]),
    ([2], ["^", 10]),         # 指数が大きすぎる -> 不可
    ([100], ["×", 2000]),     # 上限超え -> 不可
]

EXIT_CASES = [
    ([2], {"value": 2}),
    ([3], {"value": 2}),
    ([2, "×"], {"value": 2}),
    ([22], {"minValue": 20, "maxValue": 25}),
    ([27], {"minValue": 20, "maxValue": 25}),
    ([20], {"minValue": 20, "maxValue": 25}),
    ([25], {"minValue": 20, "maxValue": 25}),
    ([4], {}),
]


def main():
    merges = []
    for mover, target in MERGE_CASES:
        result = try_merge(mover, target)
        merges.append({"mover": mover, "target": target, "expected": result})

    exits = []
    for tokens, ex in EXIT_CASES:
        exits.append({"tokens": tokens, "exit": ex, "expected": can_exit(tokens, ex)})

    out = {"merges": merges, "exits": exits}
    path = os.path.join(ROOT, "tools", "testvectors.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"{len(merges)} 件の結合ケース / {len(exits)} 件の出口ケースを出力: {path}")


if __name__ == "__main__":
    main()
