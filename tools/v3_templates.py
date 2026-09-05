"""手筋ごとの型から盤を組み立てる。

これまでの生成器（v3_generate.py）は、盤をランダムに作って
「悪くないもの」だけ残す方式だった。その結果、床は空きマスに
ばら撒かれるだけで解法が床を経由せず、√ブロックなのに√を使わずに
解ける面が 39 か所できてしまった。「ランダム生成感」の正体はこれ。

ここでは逆に、**先に解き筋を決めてから盤を作る**。

  1. その面で気づいてほしい手筋を 1 つ選ぶ（例: 大きく作ってから√で縮める）
  2. 手筋を「解の骨格」として書く（例: 合体 → √の床に乗る → 出口）
  3. 骨格を終わりから逆にたどって盤を組み立てる

骨格に床が含まれているので、出来上がった盤では**その床を通らないと
解けない**。飾りにならない。

逆にたどる操作は 4 つ:

  un_exit  … 出口のマスにタイルを戻す（＝最後にそこから出ていったタイル）
  un_move  … タイルを、そこへ来る前のマスへ戻す
  un_floor … 今いるマスを床にして、乗る前の値に戻してから隣へ下がる
  un_merge … タイル 1 枚を、計算前の 2 枚に割る

組み上がった盤は最後に v3_solver.analyze へ通して、
唯一解であること・床が必要であること・無駄がないことを確かめる。
"""

import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_rules import DIRS, MAX_FACTORIAL_INPUT  # noqa: E402

OPS = ["+", "−", "×", "÷"]

# 盤に出す数の上限。大きい数や半端な数は計算が面倒なだけで難しさにならない。
MAX_VALUE = 24

# 進んだ向きの逆（巻き戻すときに使う）
OPPOSITE = {"up": "down", "down": "up", "left": "right", "right": "left"}
DELTA = {"up": (-1, 0), "right": (0, 1), "down": (1, 0), "left": (0, -1)}


class Board:
    """組み立て中の盤。巻き戻しの各操作はこれを書き換える。"""

    def __init__(self, rows, cols):
        self.rows, self.cols = rows, cols
        self.tiles = {}        # cell -> {"value","edges","fixed","fire"}
        self.floors = {}       # cell -> {"type","uses"}
        self.walls = set()
        self.exits = []        # {"row","col","direction","value"}

    def inside(self, cell):
        r, c = cell
        return 0 <= r < self.rows and 0 <= c < self.cols

    def free(self, cell):
        return (self.inside(cell) and cell not in self.tiles
                and cell not in self.walls)

    def neighbors(self, cell, want_free=True):
        out = []
        for d, (dr, dc) in DELTA.items():
            n = (cell[0] + dr, cell[1] + dc)
            if self.inside(n) and (not want_free or self.free(n)):
                out.append((d, n))
        return out

    def to_level(self, level_id, title, hint, tutorial=False):
        tiles = []
        for i, (cell, t) in enumerate(sorted(self.tiles.items())):
            d = {"id": chr(ord("a") + i), "row": cell[0], "col": cell[1],
                 "value": t["value"]}
            if t["edges"]:
                d["edges"] = dict(t["edges"])
            if t.get("fixed"):
                d["fixed"] = True
            if t.get("fire"):
                d["fire"] = True
                d["value"] = 0
            tiles.append(d)
        out = {
            "levelId": level_id, "title": title, "hint": hint,
            "rows": self.rows, "cols": self.cols,
            "tiles": tiles,
            "walls": [{"row": r, "col": c} for (r, c) in sorted(self.walls)],
            "floors": [
                {"row": r, "col": c, "type": f["type"],
                 **({"uses": f["uses"]} if f.get("uses") is not None else {})}
                for (r, c), f in sorted(self.floors.items())
            ],
            "exits": list(self.exits),
        }
        if tutorial:
            out["tutorial"] = True
        return out


# ----------------------------------------------------------------------
# 逆にたどる操作
# ----------------------------------------------------------------------

def border_spots(board):
    """出口を置ける場所（縁のマスと、そこから出ていく向き）。"""
    out = []
    for c in range(board.cols):
        out.append(((0, c), "up"))
        out.append(((board.rows - 1, c), "down"))
    for r in range(board.rows):
        out.append(((r, 0), "left"))
        out.append(((r, board.cols - 1), "right"))
    return [(cell, d) for cell, d in out if board.free(cell)]


def un_exit(rng, board, value):
    """出口のマスにタイルを 1 枚戻す。戻したタイルの位置を返す。"""
    spots = border_spots(board)
    if not spots:
        return None
    cell, direction = rng.choice(spots)
    board.tiles[cell] = {"value": value, "edges": {}, "fixed": False, "fire": False}
    board.exits.append({"row": cell[0], "col": cell[1],
                        "direction": direction, "value": value})
    return cell


def un_move(rng, board, cell, steps=1):
    """タイルを、そこへ来る前のマスへ戻す。戻した先の位置を返す。"""
    cur = cell
    for _ in range(steps):
        options = board.neighbors(cur)
        if not options:
            return cur
        _d, nxt = rng.choice(options)
        board.tiles[nxt] = board.tiles.pop(cur)
        cur = nxt
    return cur


def invert_floor(kind, value, edges):
    """床に乗る「前」の値と辺を求める。無理なら None。"""
    if kind == "sqrt":
        # 乗ったら √ されて value になった → 乗る前は value の 2 乗
        before = value * value
        if before > MAX_VALUE * MAX_VALUE or before < 1:
            return None
        return before, edges
    if kind == "fact":
        # 乗ったら階乗されて value になった → 乗る前はその元の数
        n, f = 0, 1
        while n <= MAX_FACTORIAL_INPUT:
            if f == value:
                return n, edges
            n += 1
            f *= n
        return None
    if kind == "swap":
        # ＋と−、×と÷ を入れ替える。もう一度かければ元に戻る
        pair = {"+": "−", "−": "+", "×": "÷", "÷": "×"}
        return value, {k: pair.get(v, v) for k, v in edges.items()}
    if kind == "rotate":
        # 乗ると時計回りに回る → 乗る前は反時計回りに戻した状態
        back = {"up": "left", "right": "up", "down": "right", "left": "down"}
        return value, {back[k]: v for k, v in edges.items()}
    if kind == "ice":
        return value, edges
    return None


def un_floor(rng, board, cell, kind, uses=1):
    """今いるマスを床にして、乗る前の値・辺に戻してから隣のマスへ下がる。

    「そのマスに乗ったから値（辺）が変わった」という手を、
    盤の側に作り付ける。これで解法が必ずその床を通る。
    """
    tile = board.tiles.get(cell)
    if tile is None or cell in board.floors:
        return None
    inv = invert_floor(kind, tile["value"], tile["edges"])
    if inv is None:
        return None
    before_value, before_edges = inv

    board.floors[cell] = {"type": kind, "uses": None if kind == "ice" else uses}
    # 乗る前の姿にして、隣のマス（そこから乗ってきた場所）へ下がる
    options = board.neighbors(cell)
    if not options:
        del board.floors[cell]
        return None
    _d, src = rng.choice(options)
    board.tiles[src] = {"value": before_value, "edges": dict(before_edges),
                        "fixed": False, "fire": False}
    del board.tiles[cell]
    return src


def split_value(rng, value, ops=OPS):
    """value になる (演算子, a, b) を 1 つ選ぶ。a op b == value。"""
    cands = []
    if "+" in ops:
        for a in range(1, value):
            b = value - a
            if 1 <= b <= MAX_VALUE and a <= MAX_VALUE:
                cands.append(("+", a, b))
    if "−" in ops:
        for b in range(1, 13):
            a = value + b
            if a <= MAX_VALUE:
                cands.append(("−", a, b))
    if "×" in ops:
        for b in range(2, 10):
            if value % b == 0 and 2 <= value // b <= 12:
                cands.append(("×", value // b, b))
    if "÷" in ops:
        for b in range(2, 10):
            a = value * b
            if a <= MAX_VALUE:
                cands.append(("÷", a, b))
    # ×1 や ÷1 のような「何も変えない」組み合わせは省く
    cands = [(op, a, b) for (op, a, b) in cands
             if not (op in ("×", "÷") and (a == 1 or b == 1))]
    return rng.choice(cands) if cands else None


def un_merge(rng, board, cell, ops=OPS):
    """タイル 1 枚を、計算前の 2 枚に割る。ぶつけた側の位置を返す。"""
    tile = board.tiles.get(cell)
    if tile is None or tile.get("fire"):
        return None
    split = split_value(rng, tile["value"], ops)
    if split is None:
        return None
    op, a, b = split

    dirs = list(DIRS)
    rng.shuffle(dirs)
    for d in dirs:
        dr, dc = DELTA[OPPOSITE[d]]
        src = (cell[0] + dr, cell[1] + dc)
        if not board.free(src):
            continue
        # 演算子は「ぶつけられた側の、接触面」に置く。こうすると
        # 合体後に mover 側の辺が消えるルールと噛み合う。
        edges = dict(tile["edges"])
        edges[OPPOSITE[d]] = op
        board.tiles[cell] = {"value": b, "edges": edges,
                             "fixed": False, "fire": False}
        board.tiles[src] = {"value": a, "edges": {},
                            "fixed": False, "fire": False}
        return src
    return None


def extra_merges(rng, board, n):
    """すでに置いてあるタイルをさらに割って、盤の中身を増やす。

    タイル 2 枚だと「合体 → 床 → 出口」で中身のある手が 3 回にしかならず、
    歯ごたえが出ない。骨格を保ったまま枚数だけ増やすのに使う。
    """
    for _ in range(n):
        cands = [c for c, t in board.tiles.items() if not t.get("fire")]
        if not cands:
            return
        un_merge(rng, board, rng.choice(cands))


def fill_spare_walls(rng, board, keep_free=1):
    """使っていない空きマスを壁で埋めて、盤を締める。

    タイルが自由に動ける空きマスが多いほど探索する状態が増え、
    検証に何十秒もかかるようになる（タイル5枚・4x4 で 40 万状態、
    十数秒かかっていた）。遊ぶ側にとっても、意味の無い空きマスは
    「歩くだけの手」を増やすだけなので、埋めた方が締まる。

    keep_free だけは残す（完全に埋めると動かす余地が無くなるため）。
    """
    spare = [(r, c) for r in range(board.rows) for c in range(board.cols)
             if board.free((r, c)) and (r, c) not in board.floors]
    rng.shuffle(spare)
    for cell in spare[keep_free:]:
        board.walls.add(cell)


def crop_board(board):
    """中身のある範囲まで盤を切り詰める。

    型は 4x4 などの決め打ちで組み立てるが、解が盤の一部しか使わない
    ことがある。使われない行や列が残ると「盤が広いだけ」になり、
    歩くだけの手も増える。空きを壁で埋めるより、盤そのものを
    小さくする方が素直（探索する状態も減って検証が速くなる）。

    出口は縁に置いてあり、切り詰める範囲は中身をすべて含むので、
    切り詰めた後も出口は縁に残る。
    """
    cells = list(board.tiles) + list(board.floors)
    cells += [(e["row"], e["col"]) for e in board.exits]
    if not cells:
        return board
    r0 = min(r for r, _ in cells)
    r1 = max(r for r, _ in cells)
    c0 = min(c for _, c in cells)
    c1 = max(c for _, c in cells)
    if (r0, c0) == (0, 0) and (r1, c1) == (board.rows - 1, board.cols - 1):
        return board

    out = Board(r1 - r0 + 1, c1 - c0 + 1)
    out.tiles = {(r - r0, c - c0): v for (r, c), v in board.tiles.items()}
    out.floors = {(r - r0, c - c0): v for (r, c), v in board.floors.items()}
    out.walls = {(r - r0, c - c0) for (r, c) in board.walls
                 if r0 <= r <= r1 and c0 <= c <= c1}
    out.exits = [{**e, "row": e["row"] - r0, "col": e["col"] - c0}
                 for e in board.exits]
    return out


# ----------------------------------------------------------------------
# 手筋の型
# ----------------------------------------------------------------------
# 型はそれぞれ「その面で気づいてほしいこと」を 1 つ持つ。
# build(rng, rows, cols) が盤を返す（組めなければ None）。
# 出来上がりは呼び出し側で analyze に通して確かめること。


def t_sqrt_grow_shrink(rng, rows, cols):
    """√: 大きく作ってから縮める。

    出口の値は小さいのに、そこへ至るには一度その 2 乗を作らねばならない。
    「わざわざ大きくする」という、素直に考えると出てこない筋を要求する。
    """
    b = Board(rows, cols)
    goal = rng.choice([2, 3, 4, 5])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    cell = un_move(rng, b, cell, steps=rng.choice([1, 2]))
    cell = un_floor(rng, b, cell, "sqrt")          # ここで value は goal^2 になる
    if cell is None:
        return None
    cell = un_merge(rng, b, cell)                  # その 2 乗を 2 枚から作る
    if cell is None:
        return None
    extra_merges(rng, b, rng.choice([2, 3]))
    b = crop_board(b)
    fill_spare_walls(rng, b, keep_free=rng.choice([1, 2]))
    return b


def t_fact_small_to_big(rng, rows, cols):
    """!: 小さくしてから大きくする。

    出口の値が大きいのに、! は 0〜8 しか受け付けない。
    先に「十分小さい数」を作る必要がある、という制約に気づかせる。
    """
    b = Board(rows, cols)
    n = rng.choice([3, 4, 5])
    goal = {3: 6, 4: 24, 5: 120}[n]
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    cell = un_move(rng, b, cell, steps=rng.choice([1, 2]))
    cell = un_floor(rng, b, cell, "fact")          # value は n に戻る
    if cell is None:
        return None
    cell = un_merge(rng, b, cell)                  # その n を 2 枚から作る
    if cell is None:
        return None
    extra_merges(rng, b, rng.choice([2, 3]))
    b = crop_board(b)
    fill_spare_walls(rng, b, keep_free=rng.choice([1, 2]))
    return b


def t_swap_wrong_op(rng, rows, cols):
    """⇄: そのままの演算子では届かない。

    盤にある演算子で素直に計算すると出口の値にならず、
    ⇄ を通して演算子を変えて初めて届く。

    床に乗せるのは「ぶつけられる側」。演算子を持っているのはそちらなので、
    ぶつける側を床に乗せても辺が無く、何も変わらない（最初その誤りで
    1 件も作れなかった）。
    """
    b = Board(rows, cols)
    goal = rng.choice([2, 3, 4, 5, 6, 8])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    # 出口の値を作る合体。演算子は cell 側（ぶつけられる側）に付く
    if un_merge(rng, b, cell) is None:
        return None
    # その演算子を持つタイルが ⇄ の床に乗ってきた、という形にする
    if un_floor(rng, b, cell, "swap") is None:
        return None
    extra_merges(rng, b, rng.choice([2, 3]))
    b = crop_board(b)
    fill_spare_walls(rng, b, keep_free=rng.choice([1, 2]))
    return b


def t_rotate_make_face(rng, rows, cols):
    """↻: 当てられる面を作り直す。

    演算子が付いている辺の向きが噛み合わず、そのままでは当たれない。
    ↻ を通して面の向きを変えることで初めて当てられるようになる。

    swap と同じく、床に乗せるのは演算子を持っている側。
    """
    b = Board(rows, cols)
    goal = rng.choice([4, 6, 8, 9, 12])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    if un_merge(rng, b, cell) is None:
        return None
    if un_floor(rng, b, cell, "rotate") is None:
        return None
    extra_merges(rng, b, rng.choice([2, 3]))
    b = crop_board(b)
    fill_spare_walls(rng, b, keep_free=rng.choice([1, 2]))
    return b


def t_ice_full_board(rng, rows, cols):
    """全面氷: 行きたいところで止まれない。

    盤全体が氷なので、動かすと必ず何かに当たるまで進む。
    止まりたい場所に止まるには、そこに何か置いておくしかない。
    「どこで止まるか」を先に作ってから動かす、という順番が要求される。
    """
    b = Board(rows, cols)
    goal = rng.choice([4, 6, 8, 9, 10, 12])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    cell = un_merge(rng, b, cell)
    if cell is None:
        return None
    cell = un_merge(rng, b, rng.choice(list(b.tiles)))
    if cell is None:
        return None
    # 壁を少し置いて「滑って止まる理由」を作る（角に寄せると通路になる）
    for _ in range(rng.choice([1, 2])):
        spots = [(r, c) for r in range(rows) for c in range(cols)
                 if b.free((r, c))]
        if spots:
            b.walls.add(rng.choice(spots))
    # 使う範囲まで切り詰めてから、残った通れるマスを全部氷にする
    # （先に氷を敷くと全マスが「中身あり」になって切り詰められない）
    b = crop_board(b)
    for r in range(b.rows):
        for c in range(b.cols):
            if (r, c) not in b.walls:
                b.floors[(r, c)] = {"type": "ice", "uses": None}
    return b


def t_edge_inheritance(rng, rows, cols):
    """辺の相続: どちらを動かすかで、次に使える演算子が変わる。

    合体すると残るのは「ぶつけられた側の、使わなかった辺」だけ。
    同じ 2 枚でも、どちらを動かしたかで盤に残る演算子が変わる。
    出来る数は同じなので、その場では見分けがつかない。
    """
    b = Board(rows, cols)
    goal = rng.choice([6, 8, 10, 12])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    # 2 段階に割る。1 回目の合体で残る辺を、2 回目で使う形になる
    cell = un_merge(rng, b, cell)
    if cell is None:
        return None
    target = rng.choice([c for c in b.tiles])
    cell = un_merge(rng, b, target)
    if cell is None:
        return None
    extra_merges(rng, b, rng.choice([2, 3]))
    b = crop_board(b)
    fill_spare_walls(rng, b, keep_free=rng.choice([1, 2]))
    return b


TEMPLATES = {
    "sqrt_grow_shrink": t_sqrt_grow_shrink,
    "fact_small_to_big": t_fact_small_to_big,
    "swap_wrong_op": t_swap_wrong_op,
    "rotate_make_face": t_rotate_make_face,
    "ice_full_board": t_ice_full_board,
    "edge_inheritance": t_edge_inheritance,
}


# ----------------------------------------------------------------------
# 氷（滑る盤）専用の巻き戻し
# ----------------------------------------------------------------------
# 氷の上では当たるまで止まらないので、「今ここに止まっている」ことには
# 必ず理由がある ―― 進行方向の先が盤の端か、壁か、別のタイルか。
# 巻き戻すときはその理由を保ったまま、滑ってきた元の位置へ戻す。
# こうしないと、氷を敷いても解が滑りに依存せず飾りになる。

def _blocked_ahead(board, cell, d):
    """cell から d へ進もうとしたとき、その先が塞がっているか。"""
    dr, dc = DELTA[d]
    ahead = (cell[0] + dr, cell[1] + dc)
    if not board.inside(ahead):
        return True                       # 盤の端は止まる理由になる
    return ahead in board.walls or ahead in board.tiles


def _slide_origins(board, cell, d):
    """d 向きに滑って cell で止まったとき、出発点になりうるマス。"""
    back = OPPOSITE[d]
    dr, dc = DELTA[back]
    out, cur = [], cell
    while True:
        cur = (cur[0] + dr, cur[1] + dc)
        if not board.free(cur):
            break
        out.append(cur)
    return out


def un_move_ice(rng, board, cell):
    """滑って cell に止まったことにして、出発点へタイルを戻す。"""
    dirs = [d for d in DIRS if _blocked_ahead(board, cell, d)]
    rng.shuffle(dirs)
    for d in dirs:
        origins = _slide_origins(board, cell, d)
        if not origins:
            continue
        src = rng.choice(origins)
        board.tiles[src] = board.tiles.pop(cell)
        return src
    return None


def un_merge_ice(rng, board, cell, ops=OPS):
    """滑ってぶつかって合体した、という形に割る。

    ぶつけた側は cell の手前まで一直線に滑ってくるので、
    間のマスは空いていなければならない。
    """
    tile = board.tiles.get(cell)
    if tile is None or tile.get("fire"):
        return None
    split = split_value(rng, tile["value"], ops)
    if split is None:
        return None
    op, a, b = split

    dirs = list(DIRS)
    rng.shuffle(dirs)
    for d in dirs:
        origins = _slide_origins(board, cell, d)
        if not origins:
            continue
        src = rng.choice(origins)
        edges = dict(tile["edges"])
        edges[OPPOSITE[d]] = op
        board.tiles[cell] = {"value": b, "edges": edges,
                             "fixed": False, "fire": False}
        board.tiles[src] = {"value": a, "edges": {},
                            "fixed": False, "fire": False}
        return src
    return None


def t_ice_field(rng, rows, cols):
    """全面氷: 行きたいところで止まれない。

    盤全体が氷なので、動かすと必ず何かに当たるまで進む。
    止まりたい場所に止まるには、そこに何か置いておくしかない。
    「どこで止まるか」を先に作ってから動かす、という順番が要求される。

    解の骨格を最初から滑る前提で組み立てるので、氷を外すと
    （手数が足りなくなって）解けなくなる。
    """
    b = Board(rows, cols)
    # 先に壁を少し置く。滑って止まる理由になり、通路の形も決まる。
    for _ in range(rng.choice([2, 3])):
        spots = [(r, c) for r in range(rows) for c in range(cols)]
        b.walls.add(rng.choice(spots))

    goal = rng.choice([4, 6, 8, 9, 10, 12])
    cell = un_exit(rng, b, goal)
    if cell is None:
        return None
    for _ in range(rng.choice([3, 4])):
        cands = [c for c, t in b.tiles.items() if not t.get("fire")]
        if not cands:
            break
        nxt = un_merge_ice(rng, b, rng.choice(cands))
        if nxt is None:
            return None
    # 使う範囲まで切り詰めてから、残った通れるマスを全部氷にする
    # （先に氷を敷くと全マスが「中身あり」になって切り詰められない）
    b = crop_board(b)
    for r in range(b.rows):
        for c in range(b.cols):
            if (r, c) not in b.walls:
                b.floors[(r, c)] = {"type": "ice", "uses": None}
    return b


TEMPLATES["ice_field"] = t_ice_field
