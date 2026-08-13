"""数式パズル コアルール（Python 版リファレンス実装）

POC(JS) / 本実装(Dart) と完全に同じ挙動になるように書く。
ここが「正解」の定義であり、ソルバー・検証器・レベル生成器はすべてこれを使う。

トークン:
  数値      -> int
  二項演算子 -> "+", "−", "×", "÷", "^"
  前置単項   -> "√"
  後置単項   -> "!"
"""

from math import isqrt, factorial

BINARY = {"+", "−", "×", "÷", "^"}
PREFIX = {"√"}
POSTFIX = {"!"}
OPERATORS = BINARY | PREFIX | POSTFIX

# 計算結果の暴走を防ぐガード
MAX_ABS_VALUE = 100000
MAX_FACTORIAL_INPUT = 8
MAX_POW_EXP = 4
MAX_POW_BASE = 20


def is_num(t):
    return isinstance(t, int)


def is_op(t):
    return isinstance(t, str) and t in OPERATORS


def has_number(tokens):
    return any(is_num(t) for t in tokens)


def normalize(tokens):
    """トークン列を正規化する。

    戻り値:
        ("value", [n])      … 式が完成し計算できた
        ("incomplete", [..]) … まだ完成していないが構造として妥当
        None                 … 不正（この結合は成立させない）
    """
    t = list(tokens)

    # 1) 単項演算子の簡約（√9 -> 3 / 5! -> 120）
    changed = True
    while changed:
        changed = False
        for i, x in enumerate(t):
            if x in PREFIX and i + 1 < len(t) and is_num(t[i + 1]):
                v = t[i + 1]
                if v < 0:
                    return None
                r = isqrt(v)
                if r * r != v:      # 整数の平方根にならない場合は結合不可
                    return None
                t[i:i + 2] = [r]
                changed = True
                break
            if x in POSTFIX and i - 1 >= 0 and is_num(t[i - 1]):
                v = t[i - 1]
                if v < 0 or v > MAX_FACTORIAL_INPUT:
                    return None
                t[i - 1:i + 1] = [factorial(v)]
                changed = True
                break

    if not t:
        return None

    # 2) 構造チェック（隣り合いとして成立しない並びを弾く）
    for i in range(len(t) - 1):
        a, b = t[i], t[i + 1]
        if is_num(a) and is_num(b):
            return None                     # 数字どうしの隣接は不可
        if is_num(a) and (b in PREFIX or b in POSTFIX):
            return None                     # 簡約済みなのでここに来たら不正
        if a in BINARY and (b in BINARY or b in POSTFIX):
            return None
        if a in PREFIX and (b in BINARY or b in POSTFIX or is_num(b)):
            return None
        if a in POSTFIX and (is_num(b) or b in POSTFIX or b in PREFIX):
            return None

    # 3) 先頭と末尾が数値なら完成した式 -> 左から順に計算（優先順位なし）
    if is_num(t[0]) and is_num(t[-1]):
        res = t[0]
        i = 1
        while i < len(t):
            op = t[i]
            if op not in BINARY or i + 1 >= len(t) or not is_num(t[i + 1]):
                return None
            b = t[i + 1]
            if op == "+":
                res = res + b
            elif op == "−":
                res = res - b
            elif op == "×":
                res = res * b
            elif op == "÷":
                if b == 0 or res % b != 0:   # 割り切れない場合は結合自体を無効化
                    return None
                res = res // b
            elif op == "^":
                if b < 0 or b > MAX_POW_EXP or abs(res) > MAX_POW_BASE:
                    return None
                res = res ** b
            if abs(res) > MAX_ABS_VALUE:
                return None
            i += 2
        return ("value", [res])

    return ("incomplete", t)


def try_merge(mover_tokens, target_tokens):
    """3.3 結合判定。mover が先・target が後という順序を厳守する。

    戻り値: 結合後のトークン列(list) / 結合不可なら None
    """
    m_last = mover_tokens[-1]
    t_first = target_tokens[0]
    if is_num(m_last) and is_num(t_first):
        return None                     # 数字どうしは不可
    if is_op(m_last) and is_op(t_first):
        return None                     # 演算子どうしは不可

    merged = list(mover_tokens) + list(target_tokens)
    result = normalize(merged)
    if result is None:
        return None
    return result[1]


def can_exit(tokens, exit_def):
    """3.5 出口ルール（固定値・レンジ・指定なしに対応）"""
    if len(tokens) != 1 or not is_num(tokens[0]):
        return False
    v = tokens[0]
    lo = exit_def.get("minValue")
    hi = exit_def.get("maxValue")
    if lo is not None and hi is not None:
        return lo <= v <= hi
    if exit_def.get("value") is None:
        return True
    return v == exit_def["value"]


def exit_is_on_border(exit_def, size):
    """出口マーカーが盤外に描かれるための条件（マスの中に埋まらない）"""
    d = exit_def["direction"]
    if d == "up":
        return exit_def["row"] == 0
    if d == "down":
        return exit_def["row"] == size - 1
    if d == "left":
        return exit_def["col"] == 0
    if d == "right":
        return exit_def["col"] == size - 1
    return False
