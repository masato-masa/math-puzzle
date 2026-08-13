"""数式パズル ソルバー / レベル検証器

盤面状態を全探索して以下を厳密に求める:
  - 本当にクリアできるか
  - 最短手数（= 出題する par。これ以下でクリアできることが保証される）
  - クリアルート（数学的な解法）が何通りあるか
  - 詰み（クリア不能状態に落ちること）が起こり得るか
  - 一度も使われないマスがあるか（＝盤面が無駄に大きい）

手数の数え方: 「移動」「結合」「出口から出す」をそれぞれ 1 手として数える。
クリア条件: 数字を含むタイルが盤上から全て無くなること（演算子タイルは残ってよい）。
"""

from collections import deque
from itertools import count

from puzzle_rules import (  # noqa: F401
    try_merge, can_exit, has_number, is_num, exit_is_on_border,
)

DIRS = [(-1, 0, "up"), (1, 0, "down"), (0, -1, "left"), (0, 1, "right")]

STATE_LIMIT = 400000


def make_state(pieces):
    """pieces: [(row, col, tokens_tuple, fixed, slide)] -> 正規化した状態"""
    return tuple(sorted(pieces))


def initial_state(level):
    return make_state([
        (p["row"], p["col"], tuple(p["tokens"]),
         bool(p.get("fixed", False)), bool(p.get("slide", False)))
        for p in level["pieces"]
    ])


def is_goal(state):
    return all(not has_number(tokens) for (_r, _c, tokens, _f, _s) in state)


def neighbors(state, level, allowed_dirs=None):
    """次の状態を列挙する。

    yield (next_state, kind, key)
      kind: "move" | "merge" | "exit"
      key : クリアルート（解法）の同一性判定に使う識別子。move は None。

    allowed_dirs を渡すと「その向きにしか動かせない」制限つきで探索する
    （"右に動かすだけで解けてしまう" ような単調な解の検出に使う）。
    """
    size = level["size"]
    walls = level["_wallset"]
    occupied = {(r, c): (tokens, fixed, slide)
                for (r, c, tokens, fixed, slide) in state}

    def merge_key(mover_tokens, target_tokens, merged):
        # 解法の同一性は「最終的に計算された式」で判定する。
        # 24÷4 を [24,÷]→[4] と [÷,4]←[24] のどちらで組んでも同じ解法。
        # 9×3 と 3×9 のような可換な並べ替えも同じ解法として数える。
        if len(merged) == 1 and is_num(merged[0]):
            raw = tuple(mover_tokens) + tuple(target_tokens)
            nums = tuple(sorted(t for t in raw if is_num(t)))
            ops = tuple(sorted(t for t in raw if not is_num(t)))
            return ("eval", nums, ops, merged[0])
        return None                       # 途中まで組んだだけの手は解法を分けない

    for (r, c, tokens, fixed, slide) in state:
        if fixed:
            continue                      # 単体では動かせないタイル
        for dr, dc, _name in DIRS:
            if allowed_dirs is not None and _name not in allowed_dirs:
                continue

            if slide:
                # 滑るタイル: 壁・盤の縁・結合できないタイルに当たるまで一気に進む
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
                        yield (make_state(rest), "merge",
                               merge_key(tokens, t_tokens, merged))
                        continue
                if (cr, cc) != (r, c):
                    rest = [p for p in state if not (p[0] == r and p[1] == c)]
                    rest.append((cr, cc, tokens, fixed, slide))
                    yield make_state(rest), "move", None
                continue

            nr, nc = r + dr, c + dc
            if not (0 <= nr < size and 0 <= nc < size):
                continue
            if (nr, nc) in walls:
                continue
            if (nr, nc) not in occupied:
                rest = [p for p in state if not (p[0] == r and p[1] == c)]
                rest.append((nr, nc, tokens, fixed, slide))
                yield make_state(rest), "move", None
            else:
                t_tokens, t_fixed, t_slide = occupied[(nr, nc)]
                merged = try_merge(tokens, t_tokens)
                if merged is None:
                    continue
                rest = [p for p in state
                        if not (p[0] == r and p[1] == c) and not (p[0] == nr and p[1] == nc)]
                rest.append((nr, nc, tuple(merged), t_fixed, t_slide))
                yield (make_state(rest), "merge",
                       merge_key(tokens, t_tokens, merged))

    for idx, ex in enumerate(level["exits"]):
        cell = (ex["row"], ex["col"])
        if cell not in occupied:
            continue
        tokens, _fixed, _slide = occupied[cell]
        if not can_exit(list(tokens), ex):
            continue
        rest = [p for p in state if not (p[0] == cell[0] and p[1] == cell[1])]
        key = ("exit", idx, tokens[0])
        yield make_state(rest), "exit", key


def explore(level, max_depth=None):
    """状態を展開し、隣接リストと開始点からの距離を返す。

    max_depth を与えると、その手数までの範囲だけを完全に展開する。
    最短手数 par 以下の局面はすべて含まれるので、par と最適解の解析は厳密なまま
    状態爆発を避けられる。
    """
    level["_wallset"] = {(w["row"], w["col"]) for w in level["walls"]}
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
            adj[s] = []                    # ここから先は探索しない
            continue
        edges = list(neighbors(s, level))
        adj[s] = edges
        for (ns, kind, key) in edges:
            if ns not in dist:
                dist[ns] = dist[s] + 1
                q.append(ns)
    return start, dist, adj, truncated


def goal_distance(dist, adj):
    """各状態からゴールまでの最短手数（逆向き BFS）"""
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


def enumerate_routes(start, adj, dist, dgoal, limit_moves, max_routes=20000):
    """limit_moves 手以内の全解について「解法（クリアルート）」を集める。

    解法 = 「どの値をどの出口から出したか」の多重集合。
    同じ式を組む順序の違い（√36 を先に 6 にするか、6 のまま抱えて最後に計算するか）は
    同じ解法として数える。作れるが出せない値の多さ（ひっかけ）は別途 difficulty で測る。
    """
    routes = set()
    overflow = False
    visited_paths = count()

    def dfs(state, used, events):
        nonlocal overflow
        if overflow:
            return
        if next(visited_paths) > max_routes * 20:
            overflow = True
            return
        if is_goal(state):
            exits = tuple(sorted(repr(e) for e in events if e[0] == "exit"))
            routes.add(exits)
            if len(routes) > max_routes:
                overflow = True
            return
        if used >= limit_moves:
            return
        for (ns, _kind, key) in adj.get(state, ()):
            d = dgoal.get(ns)
            if d is None:
                continue
            if used + 1 + d > limit_moves:
                continue
            dfs(ns, used + 1, events + ([key] if key else []))

    if start in dgoal:
        dfs(start, 0, [])
    return routes, overflow


def cells_used_on_optimal(start, adj, dgoal, min_moves):
    """最短手順のどれかで一度でもタイルが乗るマス"""
    used = set()
    seen = set()

    def dfs(state, used_moves):
        if (state, used_moves) in seen:
            return
        seen.add((state, used_moves))
        for (r, c, _t, _f, _s) in state:
            used.add((r, c))
        if is_goal(state):
            return
        for (ns, _kind, _key) in adj.get(state, ()):
            d = dgoal.get(ns)
            if d is None:
                continue
            if used_moves + 1 + d > min_moves:
                continue
            dfs(ns, used_moves + 1)

    if start in dgoal:
        dfs(start, 0)
    return used


def analyze(level, route_slack=2):
    """レベルを完全解析する。"""
    report = {
        "levelId": level["levelId"],
        "title": level.get("title", ""),
        "size": level["size"],
        "errors": [],
        "warnings": [],
    }

    size = level["size"]
    wallset = {(w["row"], w["col"]) for w in level["walls"]}

    # --- 静的チェック ---
    for ex in level["exits"]:
        if not exit_is_on_border(ex, size):
            report["errors"].append(
                f"出口 {ex} が盤の縁にないためマーカーがマス内に埋まる")
        if (ex["row"], ex["col"]) in wallset:
            report["errors"].append(f"出口 {ex} が壁の上にある")
    for p in level["pieces"]:
        if (p["row"], p["col"]) in wallset:
            report["errors"].append(f"タイル {p['id']} が壁の上にある")
        if not (0 <= p["row"] < size and 0 <= p["col"] < size):
            report["errors"].append(f"タイル {p['id']} が盤外にある")
    seen_cells = set()
    for p in level["pieces"]:
        cell = (p["row"], p["col"])
        if cell in seen_cells:
            report["errors"].append(f"{cell} にタイルが重複配置されている")
        seen_cells.add(cell)

    # --- 探索（深さを少しずつ伸ばして par を厳密に求める） ---
    start = dist = adj = dgoal = None
    min_moves = None
    truncated = False
    for bound in (6, 8, 10, 12, 14, 16, 18, 22):
        start, dist, adj, truncated = explore(level, max_depth=bound)
        dgoal = goal_distance(dist, adj)
        if start in dgoal:
            min_moves = dgoal[start]
            break
        if truncated:
            break

    report["states"] = len(dist) if dist else 0
    if min_moves is None:
        report["solvable"] = False
        report["errors"].append(
            "クリア不能" + ("（探索打ち切り）" if truncated else ""))
        return report
    report["solvable"] = True
    report["par"] = min_moves

    # 悪手・詰みの判定には少し先まで見る必要があるので par+3 手まで展開し直す
    start, dist, adj, truncated = explore(level, max_depth=min_moves + 3)
    dgoal = goal_distance(dist, adj)
    report["states"] = len(dist)
    if truncated:
        report["warnings"].append("状態数が上限を超えたため一部の指標が近似値")

    routes_min, of1 = enumerate_routes(start, adj, dist, dgoal, min_moves)
    routes_slack, of2 = enumerate_routes(start, adj, dist, dgoal, min_moves + route_slack)
    report["routes_optimal"] = len(routes_min)
    report["routes_within_slack"] = len(routes_slack)
    if of1 or of2:
        report["warnings"].append("解法の列挙が上限に達した（実際はもっと多い）")

    # --- 取り返しのつかない手が存在するか（結合は不可逆） ---
    dead = sum(1 for s in dist if s not in dgoal)
    report["dead_states"] = dead
    report["has_trap"] = dead > 0

    # --- 難易度指標 ---
    diff = difficulty(level, dist, adj, dgoal, min_moves)
    report["difficulty"] = diff
    if not level.get("tutorial"):
        if diff["monotone_single"]:
            report["errors"].append(
                f"{diff['monotone_single']} に動かすだけで解けてしまう")
        if min_moves < 8:
            report["errors"].append(f"最短 {min_moves} 手では短すぎる（8手以上にする）")
        if diff["forced_ratio"] > 0.45:
            report["errors"].append(
                f"選択の余地がない局面が多い（{diff['forced_ratio']}）＝一本道になっている")
        if diff["wrong_per_step"] < 2.0:
            report["errors"].append(
                f"迷いどころが少ない（1局面あたりの外れ手 {diff['wrong_per_step']}）")
        if len(diff["decoy_values"]) < 2:
            report["errors"].append(
                f"ひっかけの数が少ない（作れるのに出せない値 {diff['decoy_values']}）")
        if diff["trap_edges"] < 2:
            report["errors"].append(f"詰み手が少ない（{diff['trap_edges']}）")

    # --- 盤面サイズの無駄チェック ---
    used_cells = cells_used_on_optimal(start, adj, dgoal, min_moves)
    report["used_cells"] = len(used_cells)
    unused_rows = [r for r in range(size)
                   if not any((r, c) in used_cells for c in range(size))
                   and not all((r, c) in wallset for c in range(size))]
    unused_cols = [c for c in range(size)
                   if not any((r, c) in used_cells for r in range(size))
                   and not all((r, c) in wallset for r in range(size))]
    if unused_rows:
        report["errors"].append(f"どの最短手順でも使われない行がある: {unused_rows}")
    if unused_cols:
        report["errors"].append(f"どの最短手順でも使われない列がある: {unused_cols}")

    never_used = [(r, c) for r in range(size) for c in range(size)
                  if (r, c) not in used_cells and (r, c) not in wallset]
    report["never_used_cells"] = never_used

    if len(routes_min) > 1:
        report["errors"].append(
            f"最短手数での解法が {len(routes_min)} 通りある（1通りに絞る）")
    if len(routes_slack) > 4:
        report["warnings"].append(
            f"遠回りも含めた解法が多い（{len(routes_slack)}通り）")

    return report


def solvable_with_dirs(level, allowed_dirs):
    """限られた向きにしか動かせない条件でもクリアできてしまうか。"""
    level["_wallset"] = {(w["row"], w["col"]) for w in level["walls"]}
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


def difficulty(level, dist, adj, dgoal, par):
    """難しさを測る指標を出す。

    forced_ratio   … 合法手が1つしかない（＝選ぶ余地がない）局面の割合。高いほど作業ゲー。
    wrong_per_step … 最短手順上の各局面で「指せるが最短から外れる手」の平均数。
    trap_edges     … 指すとクリア不能に落ちる手の数。多いほど先読みが要る。
    decoy_values   … 作れるが「どの出口も受け付けない」数の種類。ひっかけの多さ。
    monotone_dirs  … その向きの移動だけでも解けてしまう向きの組み合わせ。
    """
    on_path = [s for s in dist
               if s in dgoal and dist[s] + dgoal[s] == par and not is_goal(s)]

    forced = 0
    wrong_total = 0
    trap_edges = 0
    for s in on_path:
        edges = adj.get(s, [])
        if len(edges) <= 1:
            forced += 1
        for (ns, _kind, _key) in edges:
            d = dgoal.get(ns)
            if d is None:
                trap_edges += 1
                wrong_total += 1
            elif dist[s] + 1 + d > par:
                wrong_total += 1

    # 作れてしまう数のうち、どの出口も受け付けないもの（＝ひっかけ）
    made_values = set()
    for s in dist:
        for (_r, _c, tokens, _f, _s) in s:
            if len(tokens) == 1 and is_num(tokens[0]):
                made_values.add(tokens[0])
    accepted = {v for v in made_values
                if any(can_exit([v], ex) for ex in level["exits"])}
    decoys = sorted(made_values - accepted)

    single_dirs = [d for d in ("up", "down", "left", "right")
                   if solvable_with_dirs(level, {d})]
    pair_dirs = []
    if not single_dirs:
        for a, b in (("right", "down"), ("right", "up"),
                     ("left", "down"), ("left", "up")):
            if solvable_with_dirs(level, {a, b}):
                pair_dirs.append(f"{a}+{b}")

    n = max(1, len(on_path))
    return {
        "path_states": len(on_path),
        "forced_ratio": round(forced / n, 2),
        "wrong_per_step": round(wrong_total / n, 2),
        "trap_edges": trap_edges,
        "decoy_values": decoys,
        "monotone_single": single_dirs,
        "monotone_pair": pair_dirs,
    }


def wall_candidates(level, start, adj, dgoal, min_moves):
    """最短手順で一度も使われないマス = 置いても意図した解を壊さない壁の候補"""
    size = level["size"]
    used = cells_used_on_optimal(start, adj, dgoal, min_moves)
    wallset = {(w["row"], w["col"]) for w in level["walls"]}
    exits = {(e["row"], e["col"]) for e in level["exits"]}
    return [(r, c) for r in range(size) for c in range(size)
            if (r, c) not in used and (r, c) not in wallset and (r, c) not in exits]
