"""手筋の型から盤を作り、検証に通ったものだけ書き出す。

    python tools/gen_from_template.py --template sqrt_grow_shrink --want 5

v3_generate.py（ランダム生成）との違いは、解き筋を先に決めていること。
床は解の骨格に含まれるので、出来上がった盤では必ずその床を通る。
"""

import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_solver import analyze  # noqa: E402
from v3_templates import TEMPLATES  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def acceptable(rep, min_meaningful=4, min_aha=3, tutorial=False):
    """検証結果を見て採用するか決める。落ちた理由を文字列で返す。"""
    if not rep.get("solvable"):
        return "解けない"
    if rep["errors"]:
        return "判定NG:" + rep["errors"][0][:34]
    if rep.get("regions", 1) != 1:
        return "盤が分かれている"
    if rep.get("walk_ratio", 1.0) > 0.45:
        return f"歩き率{rep.get('walk_ratio')}"
    if (rep.get("meaningful_moves") or 0) < min_meaningful:
        return f"中身{rep.get('meaningful_moves')}"
    if not tutorial and rep.get("aha_forks", 0) < min_aha:
        return f"アハ{rep.get('aha_forks')}"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True, choices=sorted(TEMPLATES))
    ap.add_argument("--rows", type=int, default=4)
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--tries", type=int, default=400)
    ap.add_argument("--want", type=int, default=5)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--min-aha", type=int, default=3)
    ap.add_argument("--min-meaningful", type=int, default=4)
    ap.add_argument("--tutorial", action="store_true")
    args = ap.parse_args()

    build = TEMPLATES[args.template]
    rng = random.Random(args.seed)
    found, rejected = [], {}

    def drop(reason):
        rejected[reason] = rejected.get(reason, 0) + 1

    for _ in range(args.tries):
        try:
            board = build(rng, args.rows, args.cols)
        except Exception as e:
            drop(f"組み立て例外:{type(e).__name__}")
            continue
        if board is None:
            drop("組み立てできない")
            continue
        level = board.to_level("gen", "生成", "", tutorial=args.tutorial)
        if len(level["tiles"]) < 2:
            drop("タイルが少なすぎる")
            continue
        try:
            rep = analyze(json.loads(json.dumps(level)))
        except Exception as e:
            drop(f"検証例外:{type(e).__name__}")
            continue
        reason = acceptable(rep, args.min_meaningful, args.min_aha, args.tutorial)
        if reason:
            drop(reason)
            continue

        level["_report"] = {k: rep.get(k) for k in
                            ("par", "walk_ratio", "density", "aha_forks",
                             "meaningful_moves", "states")}
        found.append(level)
        r = level["_report"]
        print(f"[{len(found)}/{args.want}] par={r['par']} 歩き={r['walk_ratio']} "
              f"中身={r['meaningful_moves']} アハ={r['aha_forks']}", flush=True)
        if len(found) >= args.want:
            break

    path = os.path.join(HERE, f"generated_{args.template}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"template": args.template, "levels": found}, f,
                  ensure_ascii=False, indent=2)
    print(f"\n{len(found)} 件: {path}")
    for reason, n in sorted(rejected.items(), key=lambda kv: -kv[1])[:10]:
        print(f"  {n:>5}  {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
