"""指定したレベルだけ検証し、既存の levels_v3.json へ統合する。

    python tools/merge_levels.py v3_038 v3_039 v3_040

v3_levels.py に --only を付けると、その面「だけ」を書き出してしまい
既存の出力を失う。数面だけ差し替えたいときのために、
検証して合格したものを既存の一覧へ混ぜ込む。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_levels import LEVELS  # noqa: E402
from v3_solver import analyze, shortest_actions  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEVELS_JSON = os.path.join(ROOT, "assets", "levels", "levels_v3.json")
SOLUTIONS_JSON = os.path.join(HERE, "solutions_v3.json")


def main():
    targets = set(sys.argv[1:])
    if not targets:
        print(__doc__)
        return 1

    with open(LEVELS_JSON, encoding="utf-8") as f:
        existing = json.load(f)["levels"]
    with open(SOLUTIONS_JSON, encoding="utf-8") as f:
        solutions = json.load(f)

    by_id = {lv["levelId"]: lv for lv in existing}
    added, failed = [], []

    for cand in LEVELS:
        if cand["levelId"] not in targets:
            continue
        work = json.loads(json.dumps(cand))
        rep = analyze(work)
        if not rep.get("solvable") or rep["errors"]:
            failed.append((cand["levelId"], rep.get("errors")))
            continue
        out = {k: v for k, v in cand.items() if not k.startswith("_")}
        out["par"] = rep["par"]
        out["limit"] = rep["limit"]
        acts = shortest_actions(json.loads(json.dumps(out)))
        if not acts:
            failed.append((cand["levelId"], ["手順が出せない"]))
            continue
        by_id[out["levelId"]] = out
        solutions[out["levelId"]] = {"par": rep["par"], "actions": acts}
        added.append((out["levelId"], rep["par"]))

    merged = [by_id[k] for k in sorted(by_id)]
    with open(LEVELS_JSON, "w", encoding="utf-8") as f:
        json.dump({"levels": merged}, f, ensure_ascii=False, indent=2)
    with open(SOLUTIONS_JSON, "w", encoding="utf-8") as f:
        json.dump(solutions, f, ensure_ascii=False, indent=2)

    for level_id, par in added:
        print(f"追加 {level_id} (par {par})")
    for level_id, errs in failed:
        print(f"不合格 {level_id}: {errs}")
    print(f"\n合計 {len(merged)} 面")
    return 0


if __name__ == "__main__":
    sys.exit(main())
