"""数式パズル v3 コアルール（案B：演算子はタイルの辺、単項演算子と特殊効果は床）

v2 からの変更点:
  - 演算子ブロックを廃止。盤上のタイルは常に「数字」。
  - 演算子は数字タイルの辺（上右下左）に付く。ぶつかった 2 辺のうち
    片方だけに演算子があるときだけ計算が成立する。
  - 計算後に残るのは「ぶつけられた側の、使わなかった辺」だけ。
    ぶつけた側の辺は消える。
  - 単項演算子（√ ・ !）と回転・氷はマス（床）の効果。
    氷は何度でも使えるが、それ以外は使用回数を設定できる。

辺は必ず (up, right, down, left) の 4 要素タプルで持つ。
"""

from math import isqrt, factorial

DIRS = ("up", "right", "down", "left")
DIR_DELTA = {"up": (-1, 0), "right": (0, 1), "down": (1, 0), "left": (0, -1)}
DIR_INDEX = {d: i for i, d in enumerate(DIRS)}
OPPOSITE = {"up": "down", "right": "left", "down": "up", "left": "right"}

BINARY = ("+", "−", "×", "÷")

MAX_ABS_VALUE = 100000
MAX_FACTORIAL_INPUT = 8

# 床の種類。ice だけは回数無制限が既定。
#   ice    … 止まるまで滑る
#   rotate … 辺を時計回りに 90 度回す
#   swap   … 辺の + と −、× と ÷ を入れ替える
#   sqrt   … 平方根（平方数でないと入れない）
#   fact   … 階乗
FLOOR_TYPES = ("ice", "rotate", "swap", "sqrt", "fact")
EDGE_FLOORS = ("rotate", "swap")          # 値ではなく辺に作用する床
VALUE_FLOORS = ("sqrt", "fact")

SWAP_PAIRS = {"+": "−", "−": "+", "×": "÷", "÷": "×"}


def apply_op(op, a, b):
    """a op b を計算する。成立しない組み合わせは None。

    マイナスは扱わない。引いて負になる向きは衝突自体が成立しない
    （同じ演算子でも当てる向きで A−B / B−A を選べるので、
      「大きい方から当てる」という制約になる）。
    """
    if op == "+":
        r = a + b
    elif op == "−":
        if a < b:                     # 負になる向きには当てられない
            return None
        r = a - b
    elif op == "×":
        r = a * b
    elif op == "÷":
        if b == 0 or a % b != 0:      # 割り切れないなら衝突自体が成立しない
            return None
        r = a // b
    else:
        return None
    if r > MAX_ABS_VALUE:
        return None
    return r


def apply_unary(kind, value):
    """床の値効果。適用できない値なら None（＝そのマスに入れない）。"""
    if kind == "sqrt":
        if value < 0:
            return None
        r = isqrt(value)
        return r if r * r == value else None
    if kind == "fact":
        if value < 0 or value > MAX_FACTORIAL_INPUT:
            return None
        return factorial(value)
    return None


def rotate_edges_cw(edges):
    """辺を時計回りに 90 度回す。(up, right, down, left) -> (left, up, right, down)"""
    return (edges[3], edges[0], edges[1], edges[2])


def swap_edges(edges):
    """辺の演算子を逆にする（+ ↔ −、× ↔ ÷）"""
    return tuple(SWAP_PAIRS.get(op, op) if op is not None else None for op in edges)


# 炎タイルの目印。盤の数字は 0 以上なので、負の値なら炎だと分かる。
# タイルの持ち物を 1 つ増やすと、状態を展開している箇所すべてに
# 手を入れることになるため、値の側に印を持たせている。
FIRE = -1


def is_fire(value):
    return value == FIRE


def can_burn(mover_value, target_value):
    """炎タイルがぶつかったときに燃やせるか。

    炎は数字を 1 枚燃やして消し、燃やした炎自身も消える。
    「どのタイルを諦めるか」を 1 回だけ選べる資源になる。
    出せない数を作ってしまっても炎で始末できる代わりに、
    向ける先を間違えると本当に必要な数を失う。

    炎どうしはぶつけられない（どちらが残るか決められないため）。
    """
    return is_fire(mover_value) and not is_fire(target_value)


def collide(mover_value, mover_edges, target_value, target_edges, direction):
    # 炎は計算に加わらない（燃やすだけ）。
    if is_fire(mover_value) or is_fire(target_value):
        return None
    return _collide_numbers(mover_value, mover_edges, target_value,
                            target_edges, direction)


def _collide_numbers(mover_value, mover_edges, target_value, target_edges, direction):
    """ぶつかった結果を返す。

    direction は mover が進んだ向き。
    接触するのは mover の進行方向の辺と、target のその逆向きの辺。
    片方だけに演算子があるときだけ成立し、ぶつけた側が左辺になる。

    戻り値: (新しい値, 新しい辺) / 成立しないなら None
    """
    m_edge = mover_edges[DIR_INDEX[direction]]
    t_edge = target_edges[DIR_INDEX[OPPOSITE[direction]]]

    if (m_edge is None) == (t_edge is None):
        return None                        # 両方にある / どちらにも無い → ぶつかれない

    op = m_edge if m_edge is not None else t_edge
    value = apply_op(op, mover_value, target_value)
    if value is None:
        return None

    # 残るのは「ぶつけられた側の、使わなかった辺」だけ
    new_edges = list(target_edges)
    new_edges[DIR_INDEX[OPPOSITE[direction]]] = None
    return value, tuple(new_edges)


def can_exit(value, exit_def):
    if is_fire(value):
        return False              # 炎は出口から出られない（燃やして消すしかない）
    lo, hi = exit_def.get("minValue"), exit_def.get("maxValue")
    if lo is not None and hi is not None:
        return lo <= value <= hi
    if exit_def.get("value") is None:
        return True
    return value == exit_def["value"]


def exit_is_on_border(exit_def, rows, cols=None):
    """出口マーカーが盤外に描けるか（盤は N×M）"""
    if cols is None:
        cols = rows
    d = exit_def["direction"]
    if d == "up":
        return exit_def["row"] == 0
    if d == "down":
        return exit_def["row"] == rows - 1
    if d == "left":
        return exit_def["col"] == 0
    if d == "right":
        return exit_def["col"] == cols - 1
    return False


def edges_from_dict(d):
    """{"right": "−"} のような辞書を 4 要素タプルにする"""
    d = d or {}
    return tuple(d.get(name) for name in DIRS)


def edges_to_dict(edges):
    return {name: op for name, op in zip(DIRS, edges) if op is not None}
