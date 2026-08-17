"""v3 レベル定義と検証。

    python tools/v3_levels.py               検証してレポート + JSON 出力
    python tools/v3_levels.py --report      検証のみ
    python tools/v3_levels.py --only=v3_014,v3_015   指定した面だけ検証
    python tools/v3_levels.py --all         下書き（DRAFTS）も含めて検証

50 ステージ構成（5 ステージ = 1 ギミック導入ブロック、8 ブロック分）:
  1- 5  演算子と衝突（土台）
  6-10  氷の床
 11-15  √ の床
 16-20  ! の床
 21-25  ⇄ の床（入替）
 26-30  ↻ の床（回転）
 31-35  複数の出口
 36-40  範囲を受け付ける出口
 41-50  総仕上げ（新ギミックなし、既存ギミックの組み合わせで高難度）

各ブロック内は 1,2=チュートリアル / 3,4=応用 / 5=ボスの並び。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_solver import analyze, shortest_actions  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_JSON = os.path.join(ROOT, "assets", "levels", "levels_v3.json")


def T(tid, row, col, value, edges=None, fixed=False, fire=False):
    """タイル 1 枚。fire=True なら炎タイル（値は使わないが形はそろえる）。"""
    d = {"id": tid, "row": row, "col": col, "value": value}
    if edges:
        d["edges"] = edges
    if fixed:
        d["fixed"] = True
    if fire:
        d["fire"] = True
    return d


def W(row, col):
    return {"row": row, "col": col}


def F(row, col, kind, uses=None):
    d = {"row": row, "col": col, "type": kind}
    if uses is not None:
        d["uses"] = uses
    return d


def E(row, col, direction, value=None, rng=None):
    d = {"row": row, "col": col, "direction": direction}
    if rng:
        d["minValue"], d["maxValue"] = rng
    elif value is not None:
        d["value"] = value
    return d


# 検証に通っていない下書き。既定ではコースに含めない（--all で一緒に検証できる）。
# 直したらこの表から消すこと。空になれば 50 面そろったということ。
DRAFTS = {}


LEVELS = [
    # ================================================================
    # ブロック1（1-5）演算子と衝突
    # ================================================================
    # ブロック1は自動生成（tools/v3_generate.py）+ 判定通過分から選んだもの。
    # 盤を小さく密にし、歩き率・密度・アハ分岐を数値で満たしている
    # （手作りの旧版は「盤が広いだけで手数が伸びる」問題があり作り直した）。
    {
        "levelId": "v3_001",
        "title": "ぶつけて計算",
        "hint": "演算子のある辺に当てる",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 0, 0, 7, {"right": "+"}), T("b", 1, 1, 3),
                  T("c", 1, 2, 2, {"left": "+"})],
        "walls": [W(0, 1)],
        "floors": [],
        "exits": [E(2, 0, "left", 12)],
    },
    {
        "levelId": "v3_002",
        "title": "当てる向き",
        "hint": "演算子の無い辺には入れない",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 0, 1, 7, {"right": "+"}), T("b", 0, 2, 13),
                  T("c", 1, 0, 8, {"up": "−"})],
        "walls": [W(1, 2)],
        "floors": [],
        "exits": [E(2, 0, "left", 12)],
    },
    {
        # par=8 歩き=0.38 密度=0.36 アハ=31
        "levelId": "v3_003",
        "title": "どれとどれを",
        "hint": "似た数ほど組み合わせを間違えやすい",
        "size": 4,
        "tiles": [T("a", 0, 2, 9), T("b", 0, 3, 1, {"left": "−"}), T("c", 1, 0, 2),
                  T("d", 3, 1, 5, {"up": "+", "right": "−"}), T("e", 3, 2, 7)],
        "walls": [W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(3, 0, "down", 4), E(1, 3, "right", 8)],
    },
    {
        # par=8 歩き=0.38 密度=0.36 アハ=29
        "levelId": "v3_004",
        "title": "順番を選ぶ",
        "hint": "動かす順番で結果が変わる",
        "size": 4,
        "tiles": [T("a", 0, 1, 1, {"down": "+"}), T("b", 2, 0, 7),
                  T("c", 3, 1, 5, {"right": "−"}), T("d", 3, 2, 6, {"right": "−"}),
                  T("e", 3, 3, 15)],
        "walls": [W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(0, 0, "up", 8), E(3, 0, "down", 4)],
    },
    {
        # ボス。par=9 歩き=0.44 密度=0.38 アハ=83
        "levelId": "v3_005",
        "title": "五枚のボス",
        "hint": "範囲に収まる出口もある",
        "size": 4,
        "tiles": [T("a", 0, 2, 3, {"down": "×"}), T("b", 0, 3, 8, {"left": "−"}),
                  T("c", 1, 2, 1), T("d", 2, 2, 15), T("e", 3, 0, 16)],
        "walls": [W(1, 1), W(1, 3), W(2, 3)],
        "floors": [],
        "exits": [E(3, 2, "down", rng=(15, 16)), E(0, 3, "up", 5)],
    },

    # ================================================================
    # ブロック2（6-10）氷の床
    # ================================================================
    {
        "levelId": "v3_006",
        "title": "氷の床",
        "hint": "氷の上では止まらない",
        "tutorial": True,
        "size": 4,
        "tiles": [T("a", 3, 0, 9), T("b", 3, 3, 4, {"left": "−"}),
                  T("c", 0, 0, 6, {"down": "+"})],
        "walls": [],
        "floors": [F(3, 1, "ice"), F(3, 2, "ice")],
        "exits": [E(0, 0, "up", 11)],
    },
    {
        # v3_006 と同じ骨格をコンパクトにし、演算子だけ ÷ に変えて
        # 「割り切れる方でしか割れない」を確認する第2の氷チュートリアル。
        # 横に広い盤（旧版は 3x5）は歩くだけの手が増えやすかったので
        # 正方形にした。
        "levelId": "v3_007",
        "title": "割り切れる向き",
        "hint": "割り切れない向きには当てられない",
        "tutorial": True,
        "size": 4,
        "tiles": [T("a", 3, 0, 12), T("b", 3, 3, 4, {"left": "÷"}),
                  T("c", 0, 0, 2, {"down": "+"})],
        "walls": [],
        "floors": [F(3, 1, "ice"), F(3, 2, "ice")],
        "exits": [E(0, 0, "up", 5)],
    },
    {
        "levelId": "v3_008",
        "title": "氷で運ぶ",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 1, 0, 4, {"down": "×", "right": "+"}), T("b", 1, 1, 4), T("c", 2, 0, 1), T("d", 3, 1, 7), T("e", 3, 2, 11, {"left": "+"})],
        "walls": [W(1, 3), W(3, 0)],
        "floors": [F(2, 2, "ice"), F(0, 0, "ice")],
        "exits": [E(3, 3, "down", 18), E(0, 0, "left", 8)],
    },
    {
        "levelId": "v3_009",
        "title": "滑る先を読む",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 20), T("b", 1, 0, 1), T("c", 2, 0, 11, {"up": "+"}), T("d", 3, 0, 3, {"up": "÷", "right": "−"}), T("e", 3, 2, 6)],
        "walls": [W(0, 2), W(2, 3)],
        "floors": [F(1, 0, "ice"), F(3, 0, "ice")],
        "exits": [E(0, 3, "up", 20), E(3, 0, "left", 2)],
    },
    {
        "levelId": "v3_010",
        "title": "氷のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 1, 2, {"down": "−", "right": "+"}), T("b", 0, 2, 3), T("c", 1, 2, 13), T("d", 2, 0, 2, {"right": "−"}), T("e", 3, 3, 4)],
        "walls": [W(3, 0), W(2, 1), W(0, 3)],
        "floors": [F(2, 0, "ice"), F(1, 0, "ice"), F(0, 1, "ice")],
        "exits": [E(0, 1, "up", 10), E(3, 3, "down", 4)],
    },
    # par=7 歩き=0.29 密度=0.62 アハ=24

    # ================================================================
    # ブロック3（11-15）√ の床
    # ================================================================
    {
        "levelId": "v3_011",
        "title": "平方根の床",
        "hint": "平方数でないと入れない",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 16)],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [F(1, 1, "sqrt", uses=1)],
        "exits": [E(1, 2, "right", 4)],
    },
    {
        "levelId": "v3_012",
        "title": "合わせてから根を取る",
        "hint": "9 になれば通れる",
        "tutorial": True,
        "rows": 1,
        "cols": 5,
        "tiles": [T("a", 0, 0, 5), T("b", 0, 1, 4, {"left": "+"})],
        "walls": [],
        "floors": [F(0, 2, "sqrt", uses=1)],
        "exits": [E(0, 4, "right", 3)],
    },
    {
        "levelId": "v3_013",
        "title": "根で小さくする",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 2, 20), T("b", 0, 3, 2, {"left": "−", "down": "×"}), T("c", 2, 1, 20), T("d", 2, 3, 6, {"down": "−"}), T("e", 3, 3, 10)],
        "walls": [W(2, 0), W(3, 2)],
        "floors": [F(2, 1, "sqrt", uses=1)],
        "exits": [E(3, 0, "left", 20), E(0, 3, "up", 72)],
    },
    {
        "levelId": "v3_014",
        "title": "根を通す順番",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 1, {"right": "+", "down": "−"}), T("b", 0, 1, 1), T("c", 0, 3, 16), T("d", 2, 0, 5, {"right": "−"}), T("e", 2, 1, 21)],
        "walls": [W(3, 0), W(1, 2)],
        "floors": [F(3, 2, "sqrt", uses=1)],
        "exits": [E(0, 0, "left", 14), E(0, 2, "up", 16)],
    },
    {
        "levelId": "v3_015",
        "title": "平方根のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 2, 9, {"right": "+", "down": "÷"}), T("b", 0, 3, 2, {"down": "+"}), T("c", 1, 2, 9), T("d", 1, 3, 9), T("e", 2, 1, 9)],
        "walls": [W(1, 0), W(0, 1), W(3, 1)],
        "floors": [F(3, 0, "sqrt", uses=1)],
        "exits": [E(0, 2, "up", 12), E(2, 0, "left", 9)],
    },
    # par=6 歩き=0.17 密度=0.46 アハ=26

    # ================================================================
    # ブロック4（16-20）! の床
    # ================================================================
    {
        "levelId": "v3_016",
        "title": "階乗の床",
        "hint": "0〜8 でないと入れない",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 4)],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [F(1, 1, "fact", uses=1)],
        "exits": [E(1, 2, "right", 24)],
    },
    {
        "levelId": "v3_017",
        "title": "合わせてから階乗",
        "hint": "! は数字の直後に効く",
        "tutorial": True,
        "rows": 1,
        "cols": 5,
        "tiles": [T("a", 0, 0, 2), T("b", 0, 1, 1, {"left": "+"})],
        "walls": [],
        "floors": [F(0, 2, "fact", uses=1)],
        "exits": [E(0, 4, "right", 6)],
    },
    {
        "levelId": "v3_018",
        "title": "階乗で増やす",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 6), T("b", 1, 0, 1), T("c", 2, 2, 5, {"up": "+", "right": "+"}), T("d", 2, 3, 1), T("e", 3, 0, 4, {"up": "×"})],
        "walls": [W(3, 2), W(2, 1)],
        "floors": [F(0, 1, "fact", uses=1)],
        "exits": [E(0, 3, "right", 6), E(3, 0, "left", 4)],
    },
    {
        "levelId": "v3_019",
        "title": "階乗に入る値",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 3, {"down": "+"}), T("b", 1, 1, 5), T("c", 3, 1, 12), T("d", 3, 2, 18), T("e", 3, 3, 6, {"left": "−"})],
        "walls": [W(1, 2), W(0, 2)],
        "floors": [F(2, 0, "fact", uses=1)],
        "exits": [E(1, 0, "left", 8), E(3, 3, "down", 12)],
    },
    {
        "levelId": "v3_020",
        "title": "階乗のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 15), T("b", 0, 1, 2, {"down": "÷"}), T("c", 1, 0, 8, {"up": "−", "down": "−"}), T("d", 2, 0, 13), T("e", 3, 3, 24)],
        "walls": [W(2, 3), W(2, 2), W(0, 2)],
        "floors": [F(1, 3, "fact", uses=1)],
        "exits": [E(3, 1, "down", 24), E(0, 0, "left", 3)],
    },
    # par=8 歩き=0.38 密度=0.46 アハ=23

    # ================================================================
    # ブロック5（21-25）⇄ の床（演算子入替）
    # ================================================================
    {
        # ⇄ の初出。× のままでは 36 にしかならない。÷ に変えて 4 を作る。
        "levelId": "v3_021",
        "title": "演算子を入れ替える",
        "hint": "×を÷に変えられる",
        "tutorial": True,
        "rows": 1,
        "cols": 4,
        "tiles": [T("a", 0, 0, 12), T("b", 0, 2, 3, {"left": "×"})],
        "walls": [],
        "floors": [F(0, 1, "swap", uses=1)],
        "exits": [E(0, 3, "right", 4)],
    },
    {
        # b 自身が swap の上を通って ＋→− に変わってから、a を当てる。
        # 旧版（1x6）は歩くだけの手が多かったので詰めた。
        "levelId": "v3_022",
        "title": "入れ替えてから当てる",
        "hint": "＋のままでは出せない",
        "tutorial": True,
        "rows": 1,
        "cols": 5,
        "tiles": [T("a", 0, 0, 12), T("b", 0, 3, 4, {"left": "+"})],
        "walls": [],
        "floors": [F(0, 2, "swap", uses=1)],
        "exits": [E(0, 4, "right", 8)],
    },
    {
        "levelId": "v3_023",
        "title": "入替を挟む",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 2, 0, 15), T("b", 2, 3, 1), T("c", 3, 1, 13), T("d", 3, 2, 9, {"left": "−"}), T("e", 3, 3, 3, {"left": "×", "up": "×"})],
        "walls": [W(3, 0), W(1, 1)],
        "floors": [F(0, 0, "swap", uses=1)],
        "exits": [E(0, 0, "up", 15), E(3, 3, "right", 12)],
    },
    {
        "levelId": "v3_024",
        "title": "入替の使いどころ",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 9), T("b", 2, 0, 6, {"right": "+", "down": "−"}), T("c", 2, 2, 2), T("d", 3, 0, 15), T("e", 3, 1, 2, {"right": "÷"})],
        "walls": [W(1, 1), W(3, 2)],
        "floors": [F(3, 3, "swap", uses=1)],
        "exits": [E(2, 0, "left", 10), E(1, 0, "left", 9)],
    },
    {
        "levelId": "v3_025",
        "title": "入替のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 1), T("b", 1, 3, 6, {"up": "×"}), T("c", 2, 2, 13), T("d", 2, 3, 9, {"up": "+", "left": "−"}), T("e", 3, 0, 6)],
        "walls": [W(0, 2), W(1, 2), W(1, 0)],
        "floors": [F(3, 3, "swap", uses=1)],
        "exits": [E(3, 3, "right", 10), E(3, 1, "down", 6)],
    },
    # par=7 歩き=0.29 密度=0.46 アハ=24

    # ================================================================
    # ブロック6（26-30）↻ の床（回転）
    # ================================================================
    {
        # ↻ の初出。下辺に付いた演算子は横一列の盤では使えない。
        # 時計回りに一回まわすと下→左に移り、左から当てられるようになる。
        "levelId": "v3_026",
        "title": "演算子を回す",
        "hint": "辺は時計回りに移る",
        "tutorial": True,
        "rows": 1,
        "cols": 4,
        "tiles": [T("a", 0, 0, 3), T("b", 0, 2, 5, {"down": "+"})],
        "walls": [],
        "floors": [F(0, 1, "rotate", uses=1)],
        "exits": [E(0, 3, "right", 8)],
    },
    {
        # 上辺の演算子を右辺へ回す。横一列なので上辺は永久に使えず、
        # 回して初めて「右から当てる」という向きが生まれる。
        # 最初は 3 が 5 に阻まれて動けないので、必ず 5 から動かすことになる。
        "levelId": "v3_027",
        "title": "回してから当てる",
        "hint": "当てられる向きを作る",
        "tutorial": True,
        "rows": 1,
        "cols": 4,
        "tiles": [T("a", 0, 3, 3), T("b", 0, 2, 5, {"up": "+"})],
        "walls": [],
        "floors": [F(0, 1, "rotate", uses=1)],
        "exits": [E(0, 0, "left", 8)],
    },
    {
        "levelId": "v3_028",
        "title": "面を作り直す",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 16), T("b", 1, 3, 2, {"up": "+"}), T("c", 2, 1, 2), T("d", 3, 1, 1, {"up": "−"}), T("e", 3, 3, 7, {"left": "+"})],
        "walls": [W(0, 2), W(2, 2)],
        "floors": [F(0, 0, "rotate", uses=1)],
        "exits": [E(1, 3, "right", 18), E(3, 2, "down", 8)],
    },
    {
        "levelId": "v3_029",
        "title": "回して当てる",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 1, 7), T("b", 0, 2, 2, {"left": "×"}), T("c", 1, 3, 10, {"left": "+"}), T("d", 3, 0, 6, {"right": "+"}), T("e", 3, 1, 10)],
        "walls": [W(1, 2), W(3, 2)],
        "floors": [F(2, 0, "rotate", uses=1)],
        "exits": [E(0, 3, "right", 24), E(3, 0, "down", 16)],
    },
    {
        "levelId": "v3_030",
        "title": "回転のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 6, {"down": "×"}), T("b", 1, 2, 4, {"down": "−"}), T("c", 2, 0, 10), T("d", 2, 1, 5), T("e", 3, 0, 5, {"up": "−"})],
        "walls": [W(2, 2), W(1, 0), W(3, 2)],
        "floors": [F(0, 3, "rotate", uses=1)],
        "exits": [E(3, 0, "down", 5), E(0, 2, "up", 24)],
    },
    # par=8 歩き=0.38 密度=0.46 アハ=44

    # ================================================================
    # ブロック7（31-35）複数の出口
    # ================================================================
    {
        # 出口が2つあり、値ごとに行き先が決まっていることを見せるだけの面。
        # 旧版は壁で盤を2つに割っていた（＝実質2つのパズルを並べた形）。
        #
        # タイル2枚・出口2つだと「中身のある手」は2回しか無いので、
        # 歩く手が2手以上あるとそれだけで歩き率が基準を超えてしまう。
        # 通れるマスを3つに絞り、ほぼ出口の隣から始める形にした。
        "levelId": "v3_031",
        "title": "出口はふたつ",
        "hint": "値ごとに出口が違う",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 0, 1, 3), T("b", 1, 1, 5)],
        "walls": [W(0, 0), W(0, 2), W(1, 0), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(0, 1, "up", 3), E(1, 2, "right", 5)],
    },
    {
        # 合体してできた値がどちらの出口に合うかを選ぶ。
        # 旧版は 1x7 と横長で、歩くだけの手が多かった。
        "levelId": "v3_032",
        "title": "行き先を選ぶ",
        "hint": "作った値に合う出口へ",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 12), T("b", 1, 1, 4, {"left": "÷"}),
                  T("c", 2, 1, 5)],
        "walls": [W(0, 0), W(0, 2), W(2, 0), W(2, 2)],
        "floors": [],
        "exits": [E(0, 1, "up", 3), E(1, 2, "right", 5)],
    },
    {
        "levelId": "v3_033",
        "title": "行き先を見分ける",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 1, 8, {"down": "−"}), T("b", 1, 2, 16), T("c", 1, 3, 18), T("d", 3, 0, 20), T("e", 3, 1, 4, {"left": "÷"})],
        "walls": [W(2, 1), W(1, 0)],
        "floors": [],
        "exits": [E(3, 1, "down", 5), E(0, 1, "up", 8), E(3, 3, "down", 18)],
    },
    {
        "levelId": "v3_034",
        "title": "三つの出口",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 2, 9), T("b", 0, 3, 3, {"left": "+"}), T("c", 1, 2, 8), T("d", 2, 0, 2), T("e", 3, 0, 4, {"up": "+"})],
        "walls": [W(3, 2), W(0, 1)],
        "floors": [],
        "exits": [E(3, 1, "down", 6), E(0, 2, "up", 8), E(0, 3, "right", 12)],
    },
    {
        "levelId": "v3_035",
        "title": "出口のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 2, 2, {"down": "×"}), T("b", 1, 0, 20), T("c", 1, 2, 4), T("d", 2, 1, 20), T("e", 3, 1, 11, {"up": "−"})],
        "walls": [W(3, 3), W(1, 3), W(0, 1)],
        "floors": [],
        "exits": [E(0, 3, "right", 8), E(1, 0, "left", 20), E(3, 1, "down", 9)],
    },
    # par=6 歩き=0.17 密度=0.38 アハ=17

    # ================================================================
    # ブロック8（36-40）範囲を受け付ける出口
    # ================================================================
    {
        # 範囲出口の初出。2枚をどう組み合わせても、範囲に入るのは一通り。
        # 旧版は 1x4 にタイル1枚で、ほぼ歩くだけの面だった。
        "levelId": "v3_036",
        "title": "範囲で受け付ける出口",
        "hint": "ぴったりでなくても出せる",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 5), T("b", 1, 1, 4, {"left": "+"})],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(1, 2, "right", rng=(8, 10))],
    },
    {
        # 範囲が狭く、作り方を選ばないと入らない。
        # 12−4=8 は範囲内だが、12÷4=3 では小さすぎる。
        "levelId": "v3_037",
        "title": "収まる形を探す",
        "hint": "大きすぎても小さすぎても出せない",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 12), T("b", 1, 1, 4, {"left": "−"})],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(1, 2, "right", rng=(7, 9))],
    },
    {
        "levelId": "v3_038",
        "title": "範囲に合わせる",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 12, {"right": "−"}), T("b", 0, 1, 15), T("c", 1, 0, 2, {"up": "×"}), T("d", 1, 2, 1, {"down": "−"}), T("e", 2, 2, 9)],
        "walls": [W(2, 1), W(0, 2), W(3, 3)],
        "floors": [],
        "exits": [E(3, 0, "left", rng=(5, 7)), E(2, 3, "right", rng=(7, 9))],
    },
    {
        "levelId": "v3_039",
        "title": "範囲を外さない",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 1, 0, 8, {"right": "−"}), T("b", 2, 1, 20), T("c", 2, 2, 4, {"down": "+", "right": "×"}), T("d", 2, 3, 1), T("e", 3, 2, 1)],
        "walls": [W(0, 2), W(2, 0), W(0, 0)],
        "floors": [],
        "exits": [E(1, 0, "left", rng=(11, 13)), E(0, 3, "right", rng=(4, 6))],
    },
    {
        "levelId": "v3_040",
        "title": "範囲のボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 1, 3), T("b", 0, 2, 1, {"down": "−", "left": "+"}), T("c", 1, 1, 6, {"right": "+"}), T("d", 1, 3, 8), T("e", 2, 0, 8)],
        "walls": [W(0, 3), W(2, 2), W(3, 3)],
        "floors": [],
        "exits": [E(3, 0, "left", rng=(7, 9)), E(0, 1, "up", rng=(15, 17))],
    },
    # par=7 歩き=0.29 密度=0.38 アハ=26

    # ================================================================
    # ブロック9-10（41-50）総仕上げ（既存ギミックの組み合わせ）
    # ================================================================
    {
        "levelId": "v3_041",
        "title": "氷と根",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 3, {"down": "−"}), T("b", 0, 2, 3, {"down": "×"}), T("c", 1, 2, 3, {"down": "+"}), T("d", 1, 3, 2), T("e", 2, 2, 6)],
        "walls": [W(1, 1), W(1, 0)],
        "floors": [F(3, 2, "ice"), F(0, 1, "ice"), F(3, 0, "sqrt", uses=1)],
        "exits": [E(0, 2, "up", 6), E(0, 3, "right", 6)],
    },
    # par=7 歩き=0.29 密度=0.57 アハ=29
    {
        "levelId": "v3_042",
        "title": "氷と根の応用",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 1, 0, 3), T("b", 2, 0, 10, {"up": "+", "down": "−"}), T("c", 2, 1, 13), T("d", 3, 1, 9, {"up": "+"}), T("e", 3, 3, 12)],
        "walls": [W(2, 3), W(0, 3)],
        "floors": [F(3, 3, "ice"), F(0, 2, "ice"), F(0, 0, "sqrt", uses=1)],
        "exits": [E(2, 0, "left", 9), E(3, 3, "down", 12)],
    },
    {
        "levelId": "v3_043",
        "title": "入替と回転",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 3), T("b", 1, 2, 3), T("c", 1, 3, 5, {"up": "×", "left": "+"}), T("d", 2, 1, 4), T("e", 3, 2, 1, {"left": "+"})],
        "walls": [W(2, 0), W(0, 2)],
        "floors": [F(2, 1, "swap", uses=1), F(3, 0, "rotate", uses=1)],
        "exits": [E(2, 3, "right", 18), E(3, 3, "right", 5)],
    },
    {
        "levelId": "v3_044",
        "title": "入替と回転の応用",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 1, 0, 10, {"down": "−"}), T("b", 2, 0, 18), T("c", 3, 0, 7, {"up": "+"}), T("d", 3, 2, 3, {"right": "+"}), T("e", 3, 3, 21)],
        "walls": [W(2, 1), W(0, 3)],
        "floors": [F(3, 2, "swap", uses=1), F(0, 1, "rotate", uses=1)],
        "exits": [E(3, 1, "down", 24), E(3, 0, "left", 15)],
    },
    {
        "levelId": "v3_045",
        "title": "階乗と氷",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 12), T("b", 0, 1, 15), T("c", 0, 2, 12, {"left": "−"}), T("d", 1, 2, 4), T("e", 1, 3, 2, {"left": "+"})],
        "walls": [W(3, 1), W(2, 3)],
        "floors": [F(2, 0, "fact", uses=1), F(1, 3, "ice"), F(3, 2, "ice")],
        "exits": [E(0, 3, "up", rng=(3, 6)), E(0, 0, "up", 12)],
    },
    {
        "levelId": "v3_046",
        "title": "階乗と氷の応用",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 3, {"down": "−"}), T("b", 0, 1, 7, {"right": "−"}), T("c", 0, 2, 16), T("d", 2, 0, 5, {"down": "+"}), T("e", 3, 0, 6)],
        "walls": [W(3, 3), W(2, 2)],
        "floors": [F(3, 0, "fact", uses=1), F(2, 3, "ice"), F(1, 3, "ice")],
        "exits": [E(0, 0, "up", 9), E(1, 0, "left", 8)],
    },
    {
        "levelId": "v3_047",
        "title": "炎で始末する",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 0, 15, {"right": "+"}), T("b", 0, 1, 6, {"right": "÷"}), T("c", 0, 2, 0, fire=True), T("d", 1, 1, 6), T("e", 2, 3, 12), T("f", 3, 3, 6, {"up": "+"})],
        "walls": [W(1, 3), W(2, 2)],
        "floors": [F(3, 1, "ice")],
        "exits": [E(3, 3, "right", 18), E(0, 0, "left", 21)],
    },
    {
        "levelId": "v3_048",
        "title": "炎と複数出口",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 3, 0, fire=True), T("b", 2, 0, 16), T("c", 3, 0, 10, {"up": "−"}), T("d", 3, 1, 9, {"right": "+"}), T("e", 3, 2, 11, {"right": "−"}), T("f", 3, 3, 22)],
        "walls": [W(1, 2), W(0, 1)],
        "floors": [F(2, 0, "ice")],
        "exits": [E(3, 0, "left", 6), E(3, 1, "down", 20)],
    },
    {
        "levelId": "v3_049",
        "title": "範囲と回転",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 0, 1, 14), T("b", 0, 2, 5, {"left": "+"}), T("c", 2, 0, 10, {"right": "−"}), T("d", 2, 1, 11), T("e", 3, 0, 3, {"right": "−", "up": "+"})],
        "walls": [W(1, 3), W(1, 0)],
        "floors": [F(3, 3, "rotate", uses=1), F(0, 2, "sqrt", uses=1)],
        "exits": [E(2, 0, "left", 17)],
    },
    {
        "levelId": "v3_050",
        "title": "最終ボス",
        "hint": "",
        "size": 4,
        "tiles": [T("a", 1, 2, 4, {"down": "+"}), T("b", 2, 1, 6, {"right": "+", "down": "÷"}), T("c", 2, 2, 4), T("d", 3, 1, 12), T("e", 3, 2, 8, {"up": "+"})],
        "walls": [W(2, 3), W(3, 3)],
        "floors": [F(3, 1, "rotate", uses=1), F(0, 3, "sqrt", uses=1)],
        "exits": [E(3, 0, "down", 18)],
    },
    # par=7 歩き=0.29 密度=0.5 アハ=18
]


def main():
    report_only = "--report" in sys.argv
    include_drafts = "--all" in sys.argv
    only = None
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only = {s for s in arg[len("--only="):].split(",") if s}

    targets = []
    for cand in LEVELS:
        if only is not None:
            if cand["levelId"] in only:
                targets.append(cand)
            continue
        if cand["levelId"] in DRAFTS and not include_drafts:
            continue
        targets.append(cand)

    results = []
    ok = []
    for cand in targets:
        lv = json.loads(json.dumps(cand))
        rep = analyze(lv)
        results.append(rep)
        if rep.get("solvable") and not rep["errors"]:
            out = {k: v for k, v in cand.items() if not k.startswith("_")}
            out["par"] = rep["par"]
            out["limit"] = rep["limit"]
            ok.append(out)

    print("=" * 108)
    print(f"{'level':<10}{'解':<4}{'par':<5}{'歩き':<6}{'密度':<6}{'区画':<5}"
          f"{'盤':<7}{'枚':<4}{'出口':<5}{'ひっかけ':<9}{'状態数':<8}")
    print("=" * 108)
    for rep in results:
        if rep.get("solvable"):
            d = rep["difficulty"]
            lv = next(x for x in targets if x["levelId"] == rep["levelId"])
            size = f"{lv.get('rows', lv.get('size'))}x{lv.get('cols', lv.get('size'))}"
            print(f"{rep['levelId']:<10}{'○':<4}{rep['par']:<5}"
                  f"{str(rep.get('walk_ratio', '-')):<6}"
                  f"{str(rep.get('density', '-')):<6}{rep.get('regions', '-'):<5}"
                  f"{size:<7}{len(lv['tiles']):<4}{len(lv['exits']):<5}"
                  f"{len(d['decoy_values']):<9}{rep['states']:<8}"
                  f"  {rep['title']}")
        else:
            print(f"{rep['levelId']:<10}{'×':<4}{'-':<5}{'-':<6}{'-':<5}{'-':<9}{'-':<8}"
                  f"{'-':<7}{'-':<9}{rep.get('states', 0):<8}  {rep['title']}")
        for e in rep["errors"]:
            print(f"    [ERROR] {e}")
        for w in rep["warnings"]:
            print(f"    [warn ] {w}")
        if rep.get("never_used"):
            print(f"    [info ] 使わないマス: {rep['never_used']}")

    print("=" * 92)
    print(f"合格 {len(ok)} / {len(targets)}")
    skipped = [lid for lid in DRAFTS if only is None and not include_drafts]
    if skipped:
        print(f"下書きとして除外 {len(skipped)} 面（--all で一緒に検証できる）:")
        for lid in sorted(skipped):
            print(f"  {lid}: {DRAFTS[lid]}")

    if not report_only and ok:
        os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
        with open(OUT_JSON, "w", encoding="utf-8") as f:
            json.dump({"levels": ok}, f, ensure_ascii=False, indent=2)
        print(f"書き出し: {OUT_JSON}")

        sols = {}
        for lv in ok:
            acts = shortest_actions(json.loads(json.dumps(lv)))
            sols[lv["levelId"]] = {"par": lv["par"], "actions": acts}
            mark = "OK" if acts and len(acts) == lv["par"] else "不一致"
            print(f"  {lv['levelId']}: {len(acts) if acts else '-'} 手 "
                  f"(par {lv['par']}) {mark}")
        with open(os.path.join(HERE, "solutions_v3.json"), "w", encoding="utf-8") as f:
            json.dump(sols, f, ensure_ascii=False, indent=2)

    return 0 if len(ok) == len(targets) else 1


if __name__ == "__main__":
    sys.exit(main())
