"""数式パズル v3 ソルバー / 検証器

状態 = (タイルの集合, 床の残り回数)
  タイル = (row, col, value, edges, fixed)

1 手の定義:
  - 移動（氷の上では止まるまで滑るので、滑った分もまとめて 1 手）
  - 衝突して計算
  - 出口から出す
クリア条件: 盤上のタイルが全て無くなること。
"""

from collections import deque
from itertools import count

from v3_rules import (
    DIRS, DIR_DELTA, DIR_INDEX, OPPOSITE, collide, apply_unary,
    rotate_edges_cw, swap_edges, can_exit, exit_is_on_border, edges_from_dict,
    EDGE_FLOORS,
)

STATE_LIMIT = 400000


def board_size(level):
    """盤は N×M。size しか無い旧形式は正方形として扱う。"""
    if "rows" in level and "cols" in level:
        return level["rows"], level["cols"]
    return level["size"], level["size"]


def prepare(level):
    """レベル定義から探索用の索引を作る"""
    level["_rows"], level["_cols"] = board_size(level)
    level["_walls"] = {(w["row"], w["col"]) for w in level["walls"]}
    floors = {}
    limited = []
    for f in level.get("floors", []):
        cell = (f["row"], f["col"])
        floors[cell] = f
        if f["type"] != "ice" and f.get("uses") is not None:
            limited.append(cell)
    level["_floors"] = floors
    level["_limited"] = sorted(limited)          # 残り回数を状態に持つマス
    return level


def initial_state(level):
    tiles = tuple(sorted(
        (t["row"], t["col"], t["value"], edges_from_dict(t.get("edges")),
         bool(t.get("fixed", False)))
        for t in level["tiles"]
    ))
    charges = tuple(level["_floors"][c]["uses"] for c in level["_limited"])
    return (tiles, charges)


def is_goal(state):
    return len(state[0]) == 0


def _charge_left(level, charges, cell):
    if cell not in level["_limited"]:
        return None                     # 回数制限なし
    return charges[level["_limited"].index(cell)]


def _spend_charge(level, charges, cell):
    if cell not in level["_limited"]:
        return charges
    i = level["_limited"].index(cell)
    lst = list(charges)
    lst[i] -= 1
    return tuple(lst)


def _land(level, value, edges, cell, charges):
    """マスに止まったときの床効果。戻り値 (value, edges, charges) / 入れないなら None"""
    floor = level["_floors"].get(cell)
    if floor is None or floor["type"] == "ice":
        return value, edges, charges
    left = _charge_left(level, charges, cell)
    if left is not None and left <= 0:
        return value, edges, charges     # 使い切ったマスはただの床
    kind = floor["type"]
    if kind in EDGE_FLOORS:
        new_edges = rotate_edges_cw(edges) if kind == "rotate" else swap_edges(edges)
        return value, new_edges, _spend_charge(level, charges, cell)
    new_value = apply_unary(kind, value)
    if new_value is None:
        return None                      # √ マスには平方数しか入れない、など
    return new_value, edges, _spend_charge(level, charges, cell)


def _slide(level, start, direction, occupied, mover_cell=None):
    """start から direction へ、止まるところまで進んだ先を返す。

    戻り値 (止まったマス, ぶつかった相手のマス or None)。
    相手のマスが返るのは「他のタイルに行く手を塞がれて止まった」ときだけで、
    ただ 1 マス進んで止まった場合は None。これを区別しないと、
    動いた先のさらに隣にいるタイルと同じ手で衝突できてしまう。

    氷の上では止まらない。mover_cell のマスは空きとして扱う（押した本人が退く分）。
    """
    rows, cols = level["_rows"], level["_cols"]
    walls = level["_walls"]
    floors = level["_floors"]
    dr, dc = DIR_DELTA[direction]
    cur_r, cur_c = start
    while True:
        nr, nc = cur_r + dr, cur_c + dc
        if not (0 <= nr < rows and 0 <= nc < cols) or (nr, nc) in walls:
            return (cur_r, cur_c), None
        if (nr, nc) in occupied and (nr, nc) != mover_cell:
            return (cur_r, cur_c), (nr, nc)
        cur_r, cur_c = nr, nc
        floor = floors.get((cur_r, cur_c))
        if floor is not None and floor["type"] == "ice":
            continue                      # 氷の上では止まらない
        return (cur_r, cur_c), None


def _transitions(state, level, allowed_dirs=None):
    """遷移を 1 か所で作る。yield (next_state, kind, key, action)

    kind: "move" | "merge" | "exit"
    """
    tiles, charges = state
    rows, cols = level["_rows"], level["_cols"]
    walls = level["_walls"]
    floors = level["_floors"]
    occupied = {(t[0], t[1]): t for t in tiles}

    for tile in tiles:
        r, c, value, edges, fixed = tile
        if fixed:
            continue
        for direction in DIRS:
            if allowed_dirs is not None and direction not in allowed_dirs:
                continue
            action = {"type": "move", "row": r, "col": c, "dir": direction}
            dr, dc = DIR_DELTA[direction]

            stop, hit_cell = _slide(level, (r, c), direction, occupied)
            blocker = occupied.get(hit_cell) if hit_cell else None
            nr, nc = hit_cell if hit_cell else (None, None)

            # --- ぶつかった相手と計算できるか ---
            if blocker is not None:
                result = collide(value, edges, blocker[2], blocker[3], direction)
                if result is not None:
                    new_value, new_edges = result
                    rest = [t for t in tiles
                            if not (t[0] == r and t[1] == c)
                            and not (t[0] == nr and t[1] == nc)]
                    rest.append((nr, nc, new_value, new_edges, blocker[4]))
                    key = ("calc", min(value, blocker[2]), max(value, blocker[2]),
                           new_value)
                    yield (tuple(sorted(rest)), charges), "merge", key, action
                    continue

            # --- ただ動く ---
            if stop == (r, c):
                continue                 # 1 マスも動けないので手にならない
            landed = _land(level, value, edges, stop, charges)
            if landed is None:
                continue                 # その床には入れない
            new_value, new_edges, new_charges = landed
            rest = [t for t in tiles if not (t[0] == r and t[1] == c)]
            rest.append((stop[0], stop[1], new_value, new_edges, fixed))
            floor = floors.get(stop)
            key = None
            if floor is not None and floor["type"] not in ("ice",) and new_value != value:
                key = ("floor", floor["type"], value, new_value)
            yield (tuple(sorted(rest)), new_charges), "move", key, action

    for idx, ex in enumerate(level["exits"]):
        cell = (ex["row"], ex["col"])
        if cell not in occupied:
            continue
        tile = occupied[cell]
        if not can_exit(tile[2], ex):
            continue
        rest = [t for t in tiles if not (t[0] == cell[0] and t[1] == cell[1])]
        yield ((tuple(sorted(rest)), charges), "exit", ("exit", idx, tile[2]),
               {"type": "exit", "index": idx})


def neighbors(state, level, allowed_dirs=None):
    for ns, kind, key, _action in _transitions(state, level, allowed_dirs):
        yield ns, kind, key


def explore(level, max_depth=None):
    prepare(level)
    start = initial_state(level)
    dist = {start: 0}
    adj = {}
    q = deque([start])
    truncated = False
    while q:
        s = q.popleft()
        if len(dist) > STATE_LIMIT:
            truncated = True
            break
        if max_depth is not None and dist[s] >= max_depth:
            adj[s] = []
            continue
        edges = list(neighbors(s, level))
        adj[s] = edges
        for (ns, _kind, _key) in edges:
            if ns not in dist:
                dist[ns] = dist[s] + 1
                q.append(ns)
    return start, dist, adj, truncated


def goal_distance(dist, adj):
    rev = {}
    for s, edges in adj.items():
        for (ns, _k, _key) in edges:
            rev.setdefault(ns, []).append(s)
    dgoal = {}
    q = deque()
    for s in dist:
        if is_goal(s):
            dgoal[s] = 0
            q.append(s)
    while q:
        s = q.popleft()
        for p in rev.get(s, ()):
            if p not in dgoal:
                dgoal[p] = dgoal[s] + 1
                q.append(p)
    return dgoal


def enumerate_routes(start, adj, dgoal, limit_moves, max_routes=20000):
    """解法 = どの値をどの出口から出したかの多重集合"""
    routes = set()
    overflow = False
    seen_paths = count()

    def dfs(state, used, events):
        nonlocal overflow
        if overflow or next(seen_paths) > max_routes * 20:
            overflow = True
            return
        if is_goal(state):
            routes.add(tuple(sorted(repr(e) for e in events if e[0] == "exit")))
            if len(routes) > max_routes:
                overflow = True
            return
        if used >= limit_moves:
            return
        for (ns, _kind, key) in adj.get(state, ()):
            d = dgoal.get(ns)
            if d is None or used + 1 + d > limit_moves:
                continue
            dfs(ns, used + 1, events + ([key] if key else []))

    if start in dgoal:
        dfs(start, 0, [])
    return routes, overflow


def solvable_within(level, limit):
    """limit 手以内にクリアできるか（手数制限つきの判定）"""
    import copy as _copy
    lv = prepare(_copy.deepcopy({k: v for k, v in level.items()
                                 if not k.startswith("_")}))
    start = initial_state(lv)
    dist = {start: 0}
    q = deque([start])
    while q:
        s = q.popleft()
        if is_goal(s):
            return True
        if dist[s] >= limit or len(dist) > STATE_LIMIT:
            continue
        for (ns, _k, _key) in neighbors(s, lv):
            if ns not in dist:
                dist[ns] = dist[s] + 1
                q.append(ns)
    return False


def floor_necessity(level, limit):
    """床を 1 枚ずつ取り除いても解けてしまわないかを調べる。

    取り除いても limit 手以内に解けるなら、その床は飾りでしかない。
    """
    result = []
    floors = level.get("floors", [])
    for i, f in enumerate(floors):
        trimmed = {k: v for k, v in level.items() if not k.startswith("_")}
        trimmed["floors"] = [g for j, g in enumerate(floors) if j != i]
        needed = not solvable_within(trimmed, limit)
        result.append({"floor": f, "needed": needed})
    return result


def solvable_with_dirs(level, allowed_dirs):
    prepare(level)
    start = initial_state(level)
    seen = {start}
    q = deque([start])
    while q:
        s = q.popleft()
        if is_goal(s):
            return True
        if len(seen) > 60000:
            return False
        for (ns, _k, _key) in neighbors(s, level, allowed_dirs=allowed_dirs):
            if ns not in seen:
                seen.add(ns)
                q.append(ns)
    return False


def cells_used(start, adj, dgoal, par):
    used = set()
    seen = set()

    def dfs(state, moves):
        if (state, moves) in seen:
            return
        seen.add((state, moves))
        for t in state[0]:
            used.add((t[0], t[1]))
        if is_goal(state):
            return
        for (ns, _k, _key) in adj.get(state, ()):
            d = dgoal.get(ns)
            if d is None or moves + 1 + d > par:
                continue
            dfs(ns, moves + 1)

    if start in dgoal:
        dfs(start, 0)
    return used


def difficulty(level, dist, adj, dgoal, par):
    on_path = [s for s in dist
               if s in dgoal and dist[s] + dgoal[s] == par and not is_goal(s)]
    forced = wrong = traps = 0
    for s in on_path:
        edges = adj.get(s, [])
        if len(edges) <= 1:
            forced += 1
        for (ns, _k, _key) in edges:
            d = dgoal.get(ns)
            if d is None:
                traps += 1
                wrong += 1
            elif dist[s] + 1 + d > par:
                wrong += 1

    values = set()
    for s in dist:
        for t in s[0]:
            values.add(t[2])
    accepted = {v for v in values if any(can_exit(v, ex) for ex in level["exits"])}

    single = [d for d in DIRS if solvable_with_dirs(level, {d})]
    n = max(1, len(on_path))
    return {
        "path_states": len(on_path),
        "forced_ratio": round(forced / n, 2),
        "wrong_per_step": round(wrong / n, 2),
        "trap_edges": traps,
        "decoy_values": sorted(values - accepted),
        "monotone_single": single,
    }


def analyze(level):
    report = {"levelId": level["levelId"], "title": level.get("title", ""),
              "errors": [], "warnings": []}
    prepare(level)
    rows, cols = level["_rows"], level["_cols"]

    for ex in level["exits"]:
        if not exit_is_on_border(ex, rows, cols):
            report["errors"].append(f"出口 {ex} が盤の縁にない")
        if (ex["row"], ex["col"]) in level["_walls"]:
            report["errors"].append(f"出口 {ex} が壁の上にある")
    for t in level["tiles"]:
        if (t["row"], t["col"]) in level["_walls"]:
            report["errors"].append(f"タイル {t['id']} が壁の上にある")

    start = dist = adj = dgoal = None
    par = None
    for bound in (6, 8, 10, 12, 14, 16, 20):
        start, dist, adj, truncated = explore(level, max_depth=bound)
        dgoal = goal_distance(dist, adj)
        if start in dgoal:
            par = dgoal[start]
            break
        if truncated:
            break
    if par is None:
        report["solvable"] = False
        report["errors"].append("クリア不能")
        report["states"] = len(dist) if dist else 0
        return report

    report["solvable"] = True
    report["par"] = par

    # 手数制限。既定は par ちょうど（slack で緩められる）。
    # 制限が par だと遠回りが即失敗になるので、床や地形を使わないと間に合わない。
    limit = level.get("limit")
    if limit is None:
        limit = par + level.get("slack", 0)
    report["limit"] = limit
    if limit < par:
        report["errors"].append(f"手数制限 {limit} が最短 {par} 手より少ない")

    # 床が本当に必要か（1 枚ずつ抜いても制限内で解けるなら、その床は飾り）
    necessity = floor_necessity(level, limit)
    report["floors"] = necessity
    useless = [n["floor"] for n in necessity if not n["needed"]]
    if useless:
        report["warnings"].append(
            "無くても解ける床: " + ", ".join(f"{f['type']}({f['row']},{f['col']})"
                                             for f in useless))

    start, dist, adj, truncated = explore(level, max_depth=par + 3)
    dgoal = goal_distance(dist, adj)
    report["states"] = len(dist)
    if truncated:
        report["warnings"].append("状態数が上限を超えたため一部の指標が近似値")

    routes, overflow = enumerate_routes(start, adj, dgoal, par)
    report["routes"] = len(routes)
    if overflow:
        report["warnings"].append("解法の列挙が上限に達した")
    if len(routes) > 1:
        report["errors"].append(f"最短手数での解法が {len(routes)} 通りある")

    diff = difficulty(level, dist, adj, dgoal, par)
    report["difficulty"] = diff
    if not level.get("tutorial"):
        if diff["monotone_single"]:
            report["errors"].append(f"{diff['monotone_single']} に動かすだけで解けてしまう")
        if par < 8:
            report["errors"].append(f"最短 {par} 手では短すぎる")
        if diff["forced_ratio"] > 0.45:
            report["errors"].append(f"一本道になっている（{diff['forced_ratio']}）")
        if diff["wrong_per_step"] < 2.0:
            report["errors"].append(f"迷いどころが少ない（{diff['wrong_per_step']}）")
        if len(diff["decoy_values"]) < 2:
            report["errors"].append(f"ひっかけが少ない（{diff['decoy_values']}）")

    # 床マスは壁と同じく意図して置いた内容物なので「使っているマス」として数える
    used = cells_used(start, adj, dgoal, par) | set(level["_floors"])
    unused_rows = [r for r in range(rows)
                   if not any((r, c) in used for c in range(cols))
                   and not all((r, c) in level["_walls"] for c in range(cols))]
    unused_cols = [c for c in range(cols)
                   if not any((r, c) in used for r in range(rows))
                   and not all((r, c) in level["_walls"] for r in range(rows))]
    if unused_rows:
        report["errors"].append(f"使われない行がある: {unused_rows}")
    if unused_cols:
        report["errors"].append(f"使われない列がある: {unused_cols}")
    report["never_used"] = [(r, c) for r in range(rows) for c in range(cols)
                            if (r, c) not in used and (r, c) not in level["_walls"]]
    return report


def successors_with_actions(state, level):
    for ns, _kind, _key, action in _transitions(state, level):
        yield ns, action


def shortest_actions(level):
    """最短手順を具体的な操作列にする（POC で再生して検証するため）"""
    prepare(level)
    start = initial_state(level)
    parent = {start: None}
    q = deque([start])
    goal = None
    while q:
        s = q.popleft()
        if is_goal(s):
            goal = s
            break
        for ns, action in successors_with_actions(s, level):
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
