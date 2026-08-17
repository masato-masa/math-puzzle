"""型で作った盤だけを集めた「お試しコース」を書き出す。

    python tools/make_trial_course.py

方針が合っているかを確かめるためのもの。生成済みの
generated_<型名>.json から拾って、そのままアプリで遊べる形にする。
本編（main_course.json）は触らない。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_solver import analyze, shortest_actions  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
APP = os.path.join(ROOT, "number_puzzle")

# 出す順番と、その面で気づいてほしいこと（タイトル・ヒントに使う）
PICKS = [
    ("ice_field", "全面氷", "止まりたい場所に止まれない"),
    ("sqrt_grow_shrink", "大きくしてから縮める", "√に入れるには平方数が要る"),
    ("fact_small_to_big", "小さくしてから増やす", "! は 0〜8 しか受け付けない"),
    ("swap_wrong_op", "演算子を変える", "そのままでは届かない"),
    ("rotate_make_face", "当てる面を作る", "向きが噛み合わない"),
    ("edge_inheritance", "どちらを動かすか", "残る演算子が変わる"),
]


def main():
    levels, solutions = [], {}
    n = 0
    for template, title, hint in PICKS:
        path = os.path.join(HERE, f"generated_{template}.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            pool = json.load(f)["levels"]
        for lv in pool:
            n += 1
            level_id = f"trial_{n:03d}"
            out = {k: v for k, v in lv.items() if not k.startswith("_")}
            out["levelId"] = level_id
            out["title"] = title
            out["hint"] = hint

            rep = analyze(json.loads(json.dumps(out)))
            if not rep.get("solvable") or rep["errors"]:
                print(f"除外 {template}: {rep.get('errors')}")
                n -= 1
                continue
            out["par"] = rep["par"]
            out["limit"] = rep["limit"]

            actions = shortest_actions(json.loads(json.dumps(out)))
            if not actions:
                n -= 1
                continue
            out["hintMove"] = actions[0]
            solutions[level_id] = {"par": rep["par"], "actions": actions}
            levels.append(out)
            r = lv.get("_report", {})
            print(f"{level_id}  {title}  par={rep['par']} "
                  f"歩き={r.get('walk_ratio')} 中身={r.get('meaningful_moves')} "
                  f"アハ={r.get('aha_forks')}")

    course = {"courses": [{"courseId": "trial", "title": "お試し（型で作成）",
                           "levels": levels}]}
    out_path = os.path.join(APP, "assets", "levels", "main_course.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(course, f, ensure_ascii=False, indent=2)
    print(f"\n書き出し: {out_path}（{len(levels)} 面）")

    fixture = os.path.join(APP, "test", "fixtures", "solutions_v3.json")
    with open(fixture, "w", encoding="utf-8") as f:
        json.dump(solutions, f, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
