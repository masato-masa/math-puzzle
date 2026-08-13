"""各レベルの最短手順を具体的な操作列として書き出す。

出力した手順を POC(JS) / 本実装(Dart) でそのまま再生し、
「par 手ちょうどでクリアできる」ことを実機ルール側でも確認するために使う。
"""

import json
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from puzzle_rules import try_merge, can_exit  # noqa: E402
from solver import initial_state, is_goal, make_state, DIRS, explore, goal_distance  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def successors(state, level):
    """(次状態, 操作) を列挙する。操作は POC 側でそのまま再生できる形にする。"""
    size = level["size"]
    walls = level["_wallset"]
    occupied = {(r, c): (tokens, fixed, slide)
                for (r, c, tokens, fixed, slide) in state}

    for (r, c, tokens, fixed, slide) in state:
        if fixed:
            continue
        for dr, dc, name in DIRS:
            action = {"type": "move", "row": r, "col": c, "dir": name}

            if slide:
                cr, cc = r, c
                hit = None
                while True:
                    nr, nc = cr + dr, cc + dc
                    if not (0 <= nr < size and 0 <= nc < size) or (nr, nc) in walls:
                        break
                    if (nr, nc) in occupied:
                        hit = (nr, nc)
                        break
                    cr, cc = nr, nc
                if hit is not None:
                    t_tokens, t_fixed, t_slide = occupied[hit]
                    merged = try_merge(tokens, t_tokens)
                    if merged is not None:
                        rest = [p for p in state
                                if not (p[0] == r and p[1] == c)
                                and not (p[0] == hit[0] and p[1] == hit[1])]
                        rest.append((hit[0], hit[1], tuple(merged), t_fixed, t_slide))
                        yield make_state(rest), action
                        continue
                if (cr, cc) != (r, c):
                    rest = [p for p in state if not (p[0] == r and p[1] == c)]
                    rest.append((cr, cc, tokens, fixed, slide))
                    yield make_state(rest), action
                continue

            nr, nc = r + dr, c + dc
            if not (0 <= nr < size and 0 <= nc < size) or (nr, nc) in walls:
                continue
            if (nr, nc) not in occupied:
                rest = [p for p in state if not (p[0] == r and p[1] == c)]
                rest.append((nr, nc, tokens, fixed, slide))
                yield make_state(rest), action
            else:
                t_tokens, t_fixed, t_slide = occupied[(nr, nc)]
                merged = try_merge(tokens, t_tokens)
                if merged is None:
                    continue
                rest = [p for p in state
                        if not (p[0] == r and p[1] == c) and not (p[0] == nr and p[1] == nc)]
                rest.append((nr, nc, tuple(merged), t_fixed, t_slide))
                yield make_state(rest), action

    for idx, ex in enumerate(level["exits"]):
        cell = (ex["row"], ex["col"])
        if cell not in occupied:
            continue
        tokens, _fixed, _slide = occupied[cell]
        if not can_exit(list(tokens), ex):
            continue
        rest = [p for p in state if not (p[0] == cell[0] and p[1] == cell[1])]
        yield make_state(rest), {"type": "exit", "index": idx}


def shortest_actions(level):
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
        for ns, action in successors(s, level):
            if ns not in parent:
                parent[ns] = (s, action)
                q.append(ns)
    if goal is None:
        return None
    actions = []
    cur = goal
    while parent[cur] is not None:
        prev, action = parent[cur]
        actions.append(action)
        cur = prev
    actions.reverse()
    return actions


def main():
    with open(os.path.join(ROOT, "assets", "levels", "levels.json"), encoding="utf-8") as f:
        levels = json.load(f)["levels"]

    out = {}
    for lv in levels:
        actions = shortest_actions(lv)
        if actions is None:
            print(f"{lv['levelId']}: 解が見つからない")
            continue
        ok = len(actions) == lv["par"]
        out[lv["levelId"]] = {"par": lv["par"], "actions": actions}
        print(f"{lv['levelId']}: {len(actions)} 手 (par {lv['par']}) {'OK' if ok else '不一致'}")

    path = os.path.join(HERE, "solutions.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"書き出し: {path}")


if __name__ == "__main__":
    main()
