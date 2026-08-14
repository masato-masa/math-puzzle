"""基準を満たす盤を自動探索する。

    python tools/v3_generate.py --spec tutorial_ice --tries 3000 --want 20

手で作った盤は「広いだけで手数が伸びる」ものになりやすく、50 面を
その基準で作り直すのは手に負えない。判定はすでに v3_solver 側に
書いてあるので、大量に作って通ったものだけ拾う方が早いし質も揃う。

出口の値をあらかじめ決めるとまず解けないので、次の順で作る:
  1. タイル・壁・床を置く
  2. 出口を「どんな値でも通す」状態で置き、実際にクリアできる筋を探す
  3. その筋で実際に出ていった値を、出口の受け付け値として焼き付ける
こうすると「解ける盤」であることが作り方から保証される。

そのうえで v3_solver.analyze に通し、
  - 解が 1 通りか
  - 歩いているだけの手が多くないか
  - 壁で盤が分かれていないか
  - 見分けのつかない分かれ道（アハ）があるか
などを見て、通ったものだけを候補として書き出す。
"""

import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_rules import DIRS  # noqa: E402
from v3_solver import analyze, prepare, initial_state, is_goal, \
    successors_with_actions, open_regions  # noqa: E402
from collections import deque  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "generated_v3.json")

OPS = ["+", "−", "×", "÷"]
# 盤に置く数字。大きすぎると掛け算で爆発して詰みだらけになるので抑える。
VALUES = [1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 15, 16, 18, 20, 24]


class Spec:
    """どんな盤を作りたいかの指定。"""

    def __init__(self, name, rows, cols, tiles, floors=(), walls=0,
                 exits=2, tutorial=False, par=(8, 20), min_aha=3):
        self.name = name
        self.rows, self.cols = rows, cols
        self.tiles = tiles
        self.floors = list(floors)      # 置きたい床の種類（uses=1 で置く）
        self.walls = walls
        self.exits = exits
        self.tutorial = tutorial
        self.par = par
        self.min_aha = min_aha


def _free_cells(rows, cols, taken):
    return [(r, c) for r in range(rows) for c in range(cols) if (r, c) not in taken]


def _border_cells(rows, cols):
    """出口を置ける場所（縁のマスと、そこから出る向き）。"""
    out = []
    for c in range(cols):
        out.append((0, c, "up"))
        out.append((rows - 1, c, "down"))
    for r in range(rows):
        out.append((r, 0, "left"))
        out.append((r, cols - 1, "right"))
    return out


def build_candidate(rng, spec):
    """タイル・壁・床・出口（値なし）を置いた盤を 1 つ作る。"""
    rows, cols = spec.rows, spec.cols
    taken = set()

    walls = []
    for _ in range(spec.walls):
        free = _free_cells(rows, cols, taken)
        if not free:
            break
        cell = rng.choice(free)
        taken.add(cell)
        walls.append({"row": cell[0], "col": cell[1]})

    floors = []
    for kind in spec.floors:
        free = _free_cells(rows, cols, taken)
        if not free:
            return None
        cell = rng.choice(free)
        taken.add(cell)
        f = {"row": cell[0], "col": cell[1], "type": kind}
        if kind != "ice":
            f["uses"] = 1
        floors.append(f)

    tiles = []
    for i in range(spec.tiles):
        free = _free_cells(rows, cols, taken)
        if not free:
            return None
        cell = rng.choice(free)
        taken.add(cell)
        t = {"id": chr(ord("a") + i), "row": cell[0], "col": cell[1],
             "value": rng.choice(VALUES)}
        # 辺の演算子。1 枚あたり 0〜2 個。全部に付けると当てられる面が
        # 無くなって詰みやすいので、付けない枚も混ぜる。
        n_edges = rng.choices([0, 1, 2], weights=[25, 55, 20])[0]
        if n_edges:
            faces = rng.sample(DIRS, n_edges)
            t["edges"] = {f: rng.choice(OPS) for f in faces}
        tiles.append(t)

    # 出口は「どんな値でも通す」状態で置く（値はあとで焼き付ける）。
    spots = [b for b in _border_cells(rows, cols)
             if (b[0], b[1]) not in {(w["row"], w["col"]) for w in walls}]
    if len(spots) < spec.exits:
        return None
    chosen = rng.sample(spots, spec.exits)
    exits = [{"row": r, "col": c, "direction": d} for (r, c, d) in chosen]

    return {"levelId": "gen", "title": "生成", "hint": "",
            "rows": rows, "cols": cols,
            "tiles": tiles, "walls": walls, "floors": floors, "exits": exits}


def solve_open_exits(level):
    """出口が何でも通す状態で、クリアできる筋を 1 つ探して
    「どの出口から、いくつが出ていったか」を返す。"""
    lv = json.loads(json.dumps(level))
    prepare(lv)
    start = initial_state(lv)
    parent = {start: None}
    q = deque([start])
    goal = None
    while q:
        s = q.popleft()
        if is_goal(s):
            goal = s
            break
        if len(parent) > 60000:      # 大きすぎる盤は捨てる
            return None
        for ns, action in successors_with_actions(s, lv):
            if ns not in parent:
                parent[ns] = (s, action)
                q.append(ns)
    if goal is None:
        return None

    # 出口を通った値を拾い直す
    chain = []
    cur = goal
    while parent[cur] is not None:
        prev, action = parent[cur]
        chain.append((prev, action))
        cur = prev
    chain.reverse()

    out = {}
    for state, action in chain:
        if action["type"] != "exit":
            continue
        ex = lv["exits"][action["index"]]
        cell = (ex["row"], ex["col"])
        for (r, c, v, _e, _f) in state[0]:
            if (r, c) == cell:
                out.setdefault(action["index"], []).append(v)
    return out


def finalize(level, exit_values):
    """出口に、実際に出ていった値を焼き付ける。

    同じ出口から複数の値が出る場合は範囲で受ける（そうしないと
    その出口を 1 度しか使えなくなる）。
    """
    lv = json.loads(json.dumps(level))
    keep = []
    for i, ex in enumerate(lv["exits"]):
        vals = exit_values.get(i)
        if not vals:
            continue                 # 使われなかった出口は消す
        ex = dict(ex)
        if len(set(vals)) == 1:
            ex["value"] = vals[0]
        else:
            ex["minValue"], ex["maxValue"] = min(vals), max(vals)
        keep.append(ex)
    lv["exits"] = keep
    return lv if keep else None


def acceptable(rep, spec):
    """判定結果を見て、候補として拾うかどうか決める。
    通らなかったときは理由を返す（どこで落ちているか調整するため）。"""
    if not rep.get("solvable"):
        return "解けない"
    if rep["errors"]:
        return "判定NG:" + rep["errors"][0][:24]
    par = rep["par"]
    if not (spec.par[0] <= par <= spec.par[1]):
        return f"par={par}が範囲外"
    if rep.get("regions", 1) != 1:
        return "盤が分かれている"
    if rep.get("walk_ratio", 1.0) > 0.45:
        return f"歩き率{rep.get('walk_ratio')}"
    if rep.get("density", 0) < 0.3:
        return f"密度{rep.get('density')}"
    if not spec.tutorial and rep.get("aha_forks", 0) < spec.min_aha:
        return f"アハ{rep.get('aha_forks')}"
    return None


SPECS = {
    # 土台（床なし）。小さく詰めた盤で、当てる順と向きだけで悩ませる。
    "base": Spec("base", 4, 4, tiles=4, walls=1, exits=2, par=(8, 16)),
    "base_small": Spec("base_small", 3, 4, tiles=4, walls=0, exits=2, par=(8, 14)),
    # 各ギミック。チュートリアルは短くてよいが、床は必ず要るようにする。
    "ice": Spec("ice", 4, 4, tiles=4, floors=["ice", "ice"], walls=1, exits=2),
    "sqrt": Spec("sqrt", 4, 4, tiles=4, floors=["sqrt"], walls=1, exits=2),
    "fact": Spec("fact", 4, 4, tiles=4, floors=["fact"], walls=1, exits=2),
    "swap": Spec("swap", 4, 4, tiles=4, floors=["swap"], walls=1, exits=2),
    "rotate": Spec("rotate", 4, 4, tiles=4, floors=["rotate"], walls=1, exits=2),
    # 総仕上げ。床を複数種、タイルも出口も多め。
    "mix2": Spec("mix2", 4, 5, tiles=5, floors=["ice", "sqrt"], walls=2, exits=3,
                 par=(10, 22), min_aha=5),
    "mix3": Spec("mix3", 5, 5, tiles=5, floors=["ice", "swap", "rotate"],
                 walls=2, exits=3, par=(12, 24), min_aha=5),
    "mix_fact": Spec("mix_fact", 4, 5, tiles=5, floors=["fact", "swap"],
                     walls=2, exits=3, par=(10, 22), min_aha=5),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True, choices=sorted(SPECS))
    ap.add_argument("--tries", type=int, default=2000)
    ap.add_argument("--want", type=int, default=10)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    spec = SPECS[args.spec]
    rng = random.Random(args.seed)
    found = []
    tried = 0
    rejected = {}

    def drop(reason):
        rejected[reason] = rejected.get(reason, 0) + 1

    for i in range(args.tries):
        tried += 1
        cand = build_candidate(rng, spec)
        if cand is None:
            drop("盤が作れない")
            continue
        # 壁で分かれた盤は、この時点で捨てる（解く前に分かる）
        lv = json.loads(json.dumps(cand))
        prepare(lv)
        if len([r for r in open_regions(lv) if len(r) > 1]) > 1:
            drop("盤が分かれている")
            continue

        exit_values = solve_open_exits(cand)
        if not exit_values:
            drop("クリアできる筋が無い")
            continue
        final = finalize(cand, exit_values)
        if final is None:
            drop("出口が使われない")
            continue

        try:
            rep = analyze(json.loads(json.dumps(final)))
        except Exception as e:
            drop(f"例外:{type(e).__name__}")
            continue
        reason = acceptable(rep, spec)
        if reason:
            drop(reason)
            continue

        final["_report"] = {k: rep.get(k) for k in
                            ("par", "walk_ratio", "density", "aha_forks", "states")}
        found.append(final)
        print(f"[{len(found)}/{args.want}] 試行{tried}: par={rep['par']} "
              f"歩き={rep.get('walk_ratio')} 密度={rep.get('density')} "
              f"アハ={rep.get('aha_forks')}", flush=True)
        if len(found) >= args.want:
            break

    path = args.out or os.path.join(HERE, f"generated_{args.spec}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"spec": args.spec, "tried": tried, "levels": found},
                  f, ensure_ascii=False, indent=2)
    print(f"\n{len(found)} 件を書き出し（試行 {tried} 回）: {path}")
    print("落ちた理由の内訳:")
    for reason, n in sorted(rejected.items(), key=lambda kv: -kv[1])[:12]:
        print(f"  {n:>5}  {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
