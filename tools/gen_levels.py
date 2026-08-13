"""難しいレベルをランダム生成して、検証に通ったものだけを残す。

手順:
  1. 盤・タイルをランダムに配置する
  2. 「どの縁マスからでも好きな数字を出せる」仮の出口で解いてみる
     → 解けなければ捨てる（クリア可能性をここで担保する）
  3. その解で実際に使われた出口だけを本物の出口として固定する
     （同じマスから違う値を2回出す解なら、その範囲をレンジ出口にする）
  4. 難易度指標で足切りする（短すぎる / 一本道 / ひっかけが無い ものを捨てる）
  5. 残った候補に、簡単な別解だけを潰す壁を足す

使い方:
    python tools/gen_levels.py --tries 4000 --out tools/generated.json
"""

import argparse
import json
import os
import random
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import solver  # noqa: E402
from solver import (  # noqa: E402
    initial_state, is_goal, neighbors, explore, goal_distance, difficulty,
    analyze, cells_used_on_optimal,
)

NUMBERS = [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 16, 18, 20, 24, 36, 48]
BIN_OPS = ["+", "−", "×", "÷"]
RARE_OPS = ["^", "√", "!"]


def border_dirs(r, c, size):
    d = []
    if r == 0:
        d.append("up")
    if r == size - 1:
        d.append("down")
    if c == 0:
        d.append("left")
    if c == size - 1:
        d.append("right")
    return d


def open_exits(size):
    """全ての縁マスに「なんでも出せる出口」を置いた仮の出口リスト"""
    exits = []
    for r in range(size):
        for c in range(size):
            ds = border_dirs(r, c, size)
            if ds:
                exits.append({"row": r, "col": c, "direction": ds[0]})
    return exits


def pick_far_exits(rng, level, count):
    """タイルから遠い縁マスを出口候補にする（近いと数手で終わってしまう）"""
    size = level["size"]
    wallset = {(w["row"], w["col"]) for w in level["walls"]}
    cands = []
    for r in range(size):
        for c in range(size):
            ds = border_dirs(r, c, size)
            if not ds or (r, c) in wallset:
                continue
            d = min(abs(r - p["row"]) + abs(c - p["col"]) for p in level["pieces"])
            cands.append((d, r, c, ds[0]))
    if not cands:
        return []
    cands.sort(reverse=True)
    top = cands[:max(count, len(cands) // 2)]
    rng.shuffle(top)
    return [{"row": r, "col": c, "direction": d} for (_dist, r, c, d) in top[:count]]


def solve_open(level, limit=400000):
    """仮の出口で解いて、実際に使った出口イベントを返す。"""
    level["_wallset"] = {(w["row"], w["col"]) for w in level["walls"]}
    start = initial_state(level)
    parent = {start: None}
    q = deque([start])
    goal = None
    while q:
        s = q.popleft()
        if is_goal(s):
            goal = s
            break
        if len(parent) > limit:
            return None
        for (ns, kind, key) in neighbors(s, level):
            if ns not in parent:
                parent[ns] = (s, kind, key)
                q.append(ns)
    if goal is None:
        return None

    events = []
    cur = goal
    while parent[cur] is not None:
        prev, kind, key = parent[cur]
        if kind == "exit":
            events.append(key)          # ("exit", exit_index, value)
        cur = prev
    events.reverse()
    return events


def build_exits_from_events(level, events):
    """使われた出口だけを本物の出口にする。同じマスで複数の値ならレンジにする。"""
    used = {}
    for (_tag, idx, value) in events:
        ex = level["exits"][idx]
        cell = (ex["row"], ex["col"], ex["direction"])
        used.setdefault(cell, []).append(value)
    if not used or len(used) > 3:
        return None
    exits = []
    for (r, c, d), values in used.items():
        e = {"row": r, "col": c, "direction": d}
        if len(set(values)) == 1:
            e["value"] = values[0]
        else:
            e["minValue"], e["maxValue"] = min(values), max(values)
        exits.append(e)
    return exits


def random_level(rng, idx):
    size = 4
    cells = [(r, c) for r in range(size) for c in range(size)]
    rng.shuffle(cells)

    # 全状態を厳密に検証できる規模に収める（駒を増やすと状態爆発する）
    n_num = rng.choice([3, 3, 4])
    n_op = rng.choice([2, 2, 3])
    use_rare = rng.random() < 0.25
    use_fixed = rng.random() < 0.35

    pieces = []
    pool = iter(cells)
    for i in range(n_num):
        r, c = next(pool)
        pieces.append({"id": f"n{i}", "row": r, "col": c,
                       "tokens": [rng.choice(NUMBERS)]})
    for i in range(n_op):
        r, c = next(pool)
        op = rng.choice(RARE_OPS) if (use_rare and i == 0) else rng.choice(BIN_OPS)
        pieces.append({"id": f"o{i}", "row": r, "col": c, "tokens": [op]})
    if use_fixed and pieces:
        rng.choice(pieces)["fixed"] = True

    walls = []
    for _ in range(rng.choice([2, 3, 3, 4])):   # 壁は状態空間も選択肢も絞る
        r, c = next(pool, (None, None))
        if r is not None:
            walls.append({"row": r, "col": c})

    level = {
        "levelId": f"gen_{idx:04d}",
        "title": "生成",
        "size": size,
        "pieces": pieces,
        "walls": walls,
        "exits": [],
    }
    level["exits"] = pick_far_exits(rng, level, rng.choice([1, 1, 2]))
    return level


def quick_metrics(level):
    """本検証の前に安く足切りするための指標"""
    level["_wallset"] = {(w["row"], w["col"]) for w in level["walls"]}
    start, dist, adj, truncated = explore(level)
    if truncated:
        return None
    dgoal = goal_distance(dist, adj)
    if start not in dgoal:
        return None
    par = dgoal[start]
    diff = difficulty(level, dist, adj, dgoal, par)
    return par, diff, len(dist)


def passes(par, diff):
    if par < 8:
        return False
    if diff["monotone_single"]:
        return False
    if diff["forced_ratio"] > 0.45:
        return False
    if diff["wrong_per_step"] < 2.0:
        return False
    if len(diff["decoy_values"]) < 2:
        return False
    if diff["trap_edges"] < 2:
        return False
    return True


def score(par, diff, states):
    """難しさの総合点（大きいほど難しい）"""
    return (par * 2
            + diff["wrong_per_step"] * 3
            + min(diff["trap_edges"], 40) * 0.5
            + len(diff["decoy_values"]) * 1.5
            - diff["forced_ratio"] * 10)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tries", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=20260813)
    ap.add_argument("--keep", type=int, default=40)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "generated.json"))
    args = ap.parse_args()

    solver.STATE_LIMIT = 400000
    rng = random.Random(args.seed)

    found = []
    for i in range(args.tries):
        cand = random_level(rng, i)
        if not cand["exits"]:
            continue
        events = solve_open(cand)          # 値の制限なしで一度解く
        if not events:
            continue
        exits = build_exits_from_events(cand, events)
        if not exits:
            continue
        cand["exits"] = exits              # 実際に出た値で出口を固定する
        m = quick_metrics(cand)
        if m is None:
            continue
        par, diff, states = m
        if not passes(par, diff):
            continue
        rep = analyze(cand)
        if rep["errors"] or not rep.get("solvable"):
            continue
        cand["par"] = rep["par"]
        cand["_score"] = round(score(rep["par"], rep["difficulty"], states), 2)
        cand["_difficulty"] = rep["difficulty"]
        cand["_states"] = states
        found.append(cand)
        print(f"[{i}] 合格 par={rep['par']} score={cand['_score']} "
              f"外れ手={rep['difficulty']['wrong_per_step']} "
              f"詰み手={rep['difficulty']['trap_edges']} "
              f"ひっかけ={len(rep['difficulty']['decoy_values'])}", flush=True)
        if len(found) >= args.keep:
            break

    found.sort(key=lambda c: c["_score"])
    # 探索中に付けた内部データ（集合）は JSON にできないので落とす
    dumped = [{k: v for k, v in c.items() if k != "_wallset"} for c in found]
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(dumped, f, ensure_ascii=False, indent=2)
    print(f"\n{len(found)} 件を {args.out} に書き出しました（{args.tries} 回試行）")


if __name__ == "__main__":
    main()
