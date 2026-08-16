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
# 出口に出す値の種。約数が多い数を混ぜておくと、逆再生で
# 掛け算・割り算に割りやすく、筋の種類が増える。
EXIT_SEED_VALUES = [4, 5, 6, 6, 8, 8, 9, 10, 12, 12, 15, 16, 18, 20, 24]


class Spec:
    """どんな盤を作りたいかの指定。

    「中身のある手」は概ね (タイル枚数 + 床が効いた回数) になる。
    非チュートリアルの下限が 5 回なので、床の無いブロックでは
    タイルを 5 枚以上置かないと通らない。
    """

    def __init__(self, name, rows, cols, tiles, floors=(), walls=0,
                 exits=2, tutorial=False, par=(6, 22), min_aha=3,
                 fire=0, fixed=0, all_ice=False, widen_exits=0):
        self.name = name
        self.rows, self.cols = rows, cols
        self.tiles = tiles
        self.floors = list(floors)      # 置きたい床の種類（uses=1 で置く）
        self.walls = walls
        self.exits = exits
        self.tutorial = tutorial
        self.par = par
        self.min_aha = min_aha
        self.fire = fire                # 炎タイルの枚数
        self.fixed = fixed              # 動かせないタイルの枚数
        self.all_ice = all_ice          # 盤全体を氷にする
        # 出口の受け付け値を、ぴったりの値から前後に広げる幅。
        # 逆再生では 1 つの出口に 1 枚しか種を置かないので、
        # 放っておくと出口は必ず単一値になり「範囲出口」の面が作れない。
        # 広げた結果ほかの値でも通れてしまうなら、別解が増えて
        # analyze 側の「解法が複数ある」で落ちるので、安全に試せる。
        self.widen_exits = widen_exits


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
    if spec.all_ice:
        # 全面氷。どこにも止まれないので、止めたい場所に何を置くかが
        # そのまま問題になる。壁とタイルだけが「止まる理由」になる。
        wallset = {(w["row"], w["col"]) for w in walls}
        for r in range(rows):
            for c in range(cols):
                if (r, c) not in wallset:
                    floors.append({"row": r, "col": c, "type": "ice"})
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
    n_total = spec.tiles + spec.fire
    fire_slots = set(rng.sample(range(n_total), spec.fire)) if spec.fire else set()
    fixed_slots = set()
    if spec.fixed:
        movable = [i for i in range(n_total) if i not in fire_slots]
        fixed_slots = set(rng.sample(movable, min(spec.fixed, len(movable))))
    for i in range(n_total):
        free = _free_cells(rows, cols, taken)
        if not free:
            return None
        cell = rng.choice(free)
        taken.add(cell)
        t = {"id": chr(ord("a") + i), "row": cell[0], "col": cell[1]}
        if i in fire_slots:
            t["fire"] = True
            t["value"] = 0            # 炎は値を使わないが、形をそろえるため置く
            tiles.append(t)
            continue
        t["value"] = rng.choice(VALUES)
        if i in fixed_slots:
            # 動かせないタイル。「これを動かせれば簡単なのに」という
            # 詰まり方を作るための駒。
            t["fixed"] = True
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

    out = {"levelId": "gen", "title": "生成", "hint": "",
           "rows": rows, "cols": cols,
           "tiles": tiles, "walls": walls, "floors": floors, "exits": exits}
    if spec.tutorial:
        out["tutorial"] = True
    return out


def build_by_rewind(rng, spec, walls, floors):
    """クリアした状態から巻き戻して盤を組み立てる。

    前向きにランダムに置くと、全タイルを合体させて出口へ運べる盤には
    まずならない（試したところ 200 回中 191 回がクリア不能だった）。
    そこで「空になった盤」から逆にたどる:

      出口の巻き戻し … 出口のマスにタイルを 1 枚戻す
      合体の巻き戻し … タイル 1 枚を、計算前の 2 枚に割る
      移動の巻き戻し … タイルを、そこへ来る前のマスへ戻す

    こうして作った盤は、逆にたどれば必ずクリアできる。
    氷の滑りはここでは考えていない（1 マスずつ動く前提で組む）ので、
    出来上がりは最後に本物の判定へ通して確かめる。
    """
    rows, cols = spec.rows, spec.cols
    wallset = {(w["row"], w["col"]) for w in walls}

    # 出口の位置だけ先に決める（値はあとで焼き付ける）
    spots = [b for b in _border_cells(rows, cols) if (b[0], b[1]) not in wallset]
    if len(spots) < spec.exits:
        return None
    exits = [{"row": r, "col": c, "direction": d}
             for (r, c, d) in rng.sample(spots, spec.exits)]

    # 盤の上のタイル: cell -> [value, edges(dict), fixed, fire]
    board = {}

    def empty(cell):
        return (cell not in board and cell not in wallset
                and 0 <= cell[0] < rows and 0 <= cell[1] < cols)

    # 1) まず各出口から 1 枚ずつ戻す（＝最後にそこから出ていったタイル）
    for ex in exits:
        cell = (ex["row"], ex["col"])
        if not empty(cell):
            continue
        # 出口に出す値。ここを起点に逆再生で割っていくので、
        # 割りしろのある手ごろな数から始める。
        board[cell] = [rng.choice(EXIT_SEED_VALUES), {}, False, False]
    if not board:
        return None

    target_tiles = spec.tiles + spec.fire
    guard = 0
    while len(board) < target_tiles and guard < 400:
        guard += 1
        cell = rng.choice(list(board))
        value, edges, _fixed, fire = board[cell]
        if fire:
            continue

        if rng.random() < 0.65:
            # --- 合体の巻き戻し: value を作れる 2 数に割る ---
            split = _split_value(rng, value)
            if split is None:
                continue
            op, a, b = split                      # a op b == value
            # ぶつけた側(a)が来られる隣のマスを選ぶ
            dirs = list(DIRS)
            rng.shuffle(dirs)
            placed = False
            for d in dirs:
                dr, dc = {"up": (1, 0), "right": (0, -1),
                          "down": (-1, 0), "left": (0, 1)}[d]
                src = (cell[0] + dr, cell[1] + dc)
                if not empty(src):
                    continue
                # 演算子は「ぶつけられた側の、接触面」に置く形にする
                # （こうすると合体後に mover 側の辺が消える規則と噛み合う）
                new_edges = dict(edges)
                new_edges[OPPOSITE_NAME[d]] = op
                board[cell] = [b, new_edges, False, False]
                board[src] = [a, {}, False, False]
                placed = True
                break
            if not placed:
                continue
        else:
            # --- 移動の巻き戻し: 1 マス手前へ戻す ---
            dirs = list(DIRS)
            rng.shuffle(dirs)
            for d in dirs:
                dr, dc = {"up": (1, 0), "right": (0, -1),
                          "down": (-1, 0), "left": (0, 1)}[d]
                src = (cell[0] + dr, cell[1] + dc)
                if empty(src):
                    board[src] = board.pop(cell)
                    break

    if len(board) < 2:
        return None

    # 炎タイルを混ぜる（数字を 1 枚、炎に置き換える）
    cells = list(board)
    rng.shuffle(cells)
    for i in range(min(spec.fire, max(0, len(cells) - 2))):
        board[cells[i]] = [0, {}, False, True]
    # 動かせないタイル
    for i in range(spec.fire, min(spec.fire + spec.fixed, len(cells))):
        if not board[cells[i]][3]:
            board[cells[i]][2] = True

    tiles = []
    for i, (cell, (value, edges, fixed, fire)) in enumerate(sorted(board.items())):
        t = {"id": chr(ord("a") + i), "row": cell[0], "col": cell[1]}
        if fire:
            t["fire"] = True
            t["value"] = 0
        else:
            t["value"] = value
            if edges:
                t["edges"] = edges
            if fixed:
                t["fixed"] = True
        tiles.append(t)

    out = {"levelId": "gen", "title": "生成", "hint": "",
           "rows": rows, "cols": cols,
           "tiles": tiles, "walls": walls, "floors": floors, "exits": exits}
    if spec.tutorial:
        out["tutorial"] = True
    return out


# 巻き戻すときは「進んだ向きの逆」に置くので、名前の対応表を持っておく
OPPOSITE_NAME = {"up": "down", "down": "up", "left": "right", "right": "left"}


# 盤に出したい数の上限。大きい数や半端な数が並ぶと、
# 暗算しづらいだけで難しさは増えないので抑える。
MAX_TILE_VALUE = 24


def _split_value(rng, value):
    """value になる (演算子, a, b) を 1 つ選ぶ。a op b == value。

    出てくる数が小さく収まるように候補を絞る。逆再生を繰り返すと
    数はどんどん大きくなりがちで、放っておくと 32 と 29 を引き算する
    ような、計算が面倒なだけの盤になる。
    """
    if value < 0 or value > MAX_TILE_VALUE:
        return None
    cands = []
    # 足し算: 1+1 のような極端な偏りは避け、両方 1 以上
    for a in range(1, value):
        b = value - a
        if 1 <= b <= MAX_TILE_VALUE:
            cands.append(("+", a, b))
    # 引き算: 引かれる数が大きくなりすぎないように
    for b in range(1, 13):
        a = value + b
        if a <= MAX_TILE_VALUE:
            cands.append(("−", a, b))
    # 掛け算: 九九の範囲に収める
    for b in range(2, 10):
        if value % b == 0 and 1 <= value // b <= 12:
            cands.append(("×", value // b, b))
    # 割り算: 割られる数が大きくなりすぎないように
    for b in range(2, 10):
        a = value * b
        if a <= MAX_TILE_VALUE:
            cands.append(("÷", a, b))
    if not cands:
        return None
    return rng.choice(cands)


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
        if len(parent) > 120000:      # 大きすぎる盤は捨てる
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


def widen(level, span):
    """出口の受け付け値を前後 span だけ広げて範囲にする。

    「ちょうどの値」ではなく「この範囲に収まればよい」という問いに変える。
    広げすぎると何でも通ってしまうので、呼び出し側で検証に通すこと。
    """
    lv = json.loads(json.dumps(level))
    for ex in lv["exits"]:
        if ex.get("value") is None:
            continue
        v = ex.pop("value")
        ex["minValue"] = max(0, v - span)
        ex["maxValue"] = v + span
    return lv


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


def exits_are_tight(level, max_span=4):
    """範囲で受ける出口が緩すぎないか。

    (3, 18) のように広い範囲だと何を作っても通ってしまい、
    「ちょうどに収める」という問いが消える。
    """
    for e in level["exits"]:
        lo, hi = e.get("minValue"), e.get("maxValue")
        if lo is not None and hi is not None and hi - lo > max_span:
            return False
    return True


SPECS = {
    # --- ブロック1: 土台（床なし）。当てる順と向きだけで悩ませる。
    # 床が無いぶん「中身のある手」はタイル枚数で稼ぐ必要がある。
    "b1_tutorial": Spec("b1_tutorial", 3, 3, tiles=3, walls=1, exits=1,
                        tutorial=True, par=(3, 8)),
    "b1": Spec("b1", 4, 4, tiles=5, walls=2, exits=2, par=(8, 16)),
    # タイル6枚は状態空間が急に膨らみ検証(BFS)が追いつかず、
    # 4x5・出口3つは「使われない行」に引っかかりやすく（横に広い分、
    # 縦方向がおろそかになりやすい）、どちらも実質 0 件だった。
    # b1（4x4, tiles=5, walls=2）は確実に生成できているので、
    # そこから壁を1枚増やすだけの最小差分にする。
    "b1_boss": Spec("b1_boss", 4, 4, tiles=5, walls=3, exits=2,
                    par=(9, 22), min_aha=6),

    # --- 迷路。壁を多めにして、動かす順と経路を考えないと詰むようにする。
    "maze": Spec("maze", 4, 4, tiles=5, walls=4, exits=2, par=(8, 18), min_aha=4),
    "maze_big": Spec("maze_big", 5, 4, tiles=6, walls=6, exits=2,
                     par=(10, 20), min_aha=4),

    # --- 全面氷。どこにも止まれないので、止める理由を自分で作る。
    "all_ice": Spec("all_ice", 4, 4, tiles=5, walls=2, exits=2,
                    all_ice=True, par=(6, 18), min_aha=3),
    "all_ice_tutorial": Spec("all_ice_tutorial", 3, 3, tiles=3, walls=1, exits=1,
                             all_ice=True, tutorial=True, par=(3, 10)),

    # --- 炎。どれを諦めるかを選ばせる。
    "fire_tutorial": Spec("fire_tutorial", 3, 3, tiles=2, fire=1, walls=1,
                          exits=1, tutorial=True, par=(3, 10)),
    "fire": Spec("fire", 4, 4, tiles=4, fire=1, walls=2, exits=2, par=(7, 18)),

    # --- 動かせないタイル。「動かせれば簡単なのに」を作る。
    "fixed": Spec("fixed", 4, 4, tiles=5, fixed=1, walls=2, exits=2, par=(8, 18)),

    # --- 各ギミックの応用・ボス。b1/b1_boss（4x4, tiles=5）が確実だった
    # ことを踏まえ、正方形の盤に統一する（横に広い盤は「使われない行」に
    # 引っかかりやすかった）。応用は壁2、ボスは壁3・アハ下限を上げる。
    "ice_app": Spec("ice_app", 4, 4, tiles=5, floors=["ice", "ice"], walls=2, exits=2),
    "ice_boss": Spec("ice_boss", 4, 4, tiles=5, floors=["ice", "ice", "ice"],
                     walls=3, exits=2, min_aha=6),
    "sqrt_app": Spec("sqrt_app", 4, 4, tiles=5, floors=["sqrt"], walls=2, exits=2),
    "sqrt_boss": Spec("sqrt_boss", 4, 4, tiles=5, floors=["sqrt"], walls=3,
                      exits=2, min_aha=6),
    "fact_app": Spec("fact_app", 4, 4, tiles=5, floors=["fact"], walls=2, exits=2),
    "fact_boss": Spec("fact_boss", 4, 4, tiles=5, floors=["fact"], walls=3,
                      exits=2, min_aha=6),
    "swap_app": Spec("swap_app", 4, 4, tiles=5, floors=["swap"], walls=2, exits=2),
    "swap_boss": Spec("swap_boss", 4, 4, tiles=5, floors=["swap"], walls=3,
                      exits=2, min_aha=6),
    "rotate_app": Spec("rotate_app", 4, 4, tiles=5, floors=["rotate"], walls=2, exits=2),
    "rotate_boss": Spec("rotate_boss", 4, 4, tiles=5, floors=["rotate"], walls=3,
                        exits=2, min_aha=6),

    # --- 複数の出口。出口3つを正面から要求する。
    "multi_app": Spec("multi_app", 4, 4, tiles=5, walls=2, exits=3),
    "multi_boss": Spec("multi_boss", 4, 4, tiles=5, walls=3, exits=3, min_aha=6),

    # --- 範囲を受け付ける出口。出口を1つに絞ると、生き残った全タイルが
    # 必ずそこを通るので、異なる値が同じ出口から出て自然に範囲になる。
    #
    # 壁2枚（range_app）だと 400 回試して 0 件だった。タイルが自由に
    # 動ける分だけ出ていく値が散らばり、「出口の範囲が広すぎる」で
    # ほとんど落ちる。壁を増やして動きを縛った range_boss は通ったので、
    # 応用側も壁 3 枚にそろえる（難度差はアハ下限で付ける）。
    "range_app": Spec("range_app", 4, 4, tiles=5, walls=3, exits=2, widen_exits=1),
    "range_boss": Spec("range_boss", 4, 4, tiles=5, walls=3, exits=2,
                       widen_exits=1, min_aha=6),

    # --- 総仕上げ（41-50）。床を複数種、正方形〜わずかに縦長。
    "finale_ice_sqrt": Spec("finale_ice_sqrt", 4, 4, tiles=5,
                            floors=["ice", "ice", "sqrt"], walls=2, exits=2, min_aha=5),
    "finale_swap_rotate": Spec("finale_swap_rotate", 4, 4, tiles=5,
                               floors=["swap", "rotate"], walls=2, exits=2, min_aha=5),
    "finale_fact_ice": Spec("finale_fact_ice", 4, 4, tiles=5,
                            floors=["fact", "ice", "ice"], walls=2, exits=2, min_aha=5),
    "finale_fire_multi": Spec("finale_fire_multi", 4, 4, tiles=5, fire=1,
                              floors=["ice"], walls=2, exits=3, min_aha=5),
    "finale_range_rotate": Spec("finale_range_rotate", 4, 4, tiles=5,
                                floors=["rotate", "sqrt"], walls=2, exits=1, min_aha=5),
    # 最終ボス。tiles と fire は合算して盤に置かれるので、当初の
    # tiles=6 + fire=1 は実質 7 枚だった。6 枚ですら状態空間が破綻して
    # 生成できないことがブロック1で分かっていたのに超過させてしまい、
    # 4 時間以上かかっても 1 件も出なかった。実績のある 5 枚（うち 1 枚を
    # 炎に）に抑え、難度は床の種類・壁・アハ下限で付ける。
    "finale_boss": Spec("finale_boss", 4, 4, tiles=4, fire=1,
                        floors=["ice", "swap", "sqrt"], walls=3, exits=2,
                        par=(10, 24), min_aha=7),
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
        # 壁と床だけ先に置き、タイルは「クリア状態からの巻き戻し」で並べる
        scaffold = build_candidate(rng, spec)
        if scaffold is None:
            drop("盤が作れない")
            continue
        cand = build_by_rewind(rng, spec, scaffold["walls"], scaffold["floors"])
        if cand is None:
            drop("巻き戻しで組めない")
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
        if spec.widen_exits:
            final = widen(final, spec.widen_exits)
        if not exits_are_tight(final):
            drop("出口の範囲が広すぎる")
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
