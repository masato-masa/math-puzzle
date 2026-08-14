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


def T(tid, row, col, value, edges=None, fixed=False):
    d = {"id": tid, "row": row, "col": col, "value": value}
    if edges:
        d["edges"] = edges
    if fixed:
        d["fixed"] = True
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
    {
        "levelId": "v3_001",
        "title": "辺で計算する",
        "hint": "演算子のある辺に当てる",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 1, 0, 7), T("b", 1, 1, 3, {"left": "−"})],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "floors": [],
        "exits": [E(1, 2, "right", 4)],
    },
    {
        "levelId": "v3_002",
        "title": "当てる向き",
        "hint": "演算子の無い辺には入れない",
        "tutorial": True,
        "size": 3,
        "tiles": [T("a", 2, 1, 12), T("b", 1, 1, 4, {"down": "÷"})],
        "walls": [W(0, 0), W(1, 0), W(2, 0), W(0, 2), W(1, 2), W(2, 2)],
        "floors": [],
        "exits": [E(0, 1, "up", 3)],
    },
    {
        # 遠くの2枚を合わせてから、その結果をさらに奥の1枚へぶつける。
        "levelId": "v3_003",
        "title": "3枚を組み立てる",
        "hint": "近い2枚を先に合わせる",
        "rows": 5,
        "cols": 5,
        "tiles": [T("a", 4, 0, 3), T("b", 4, 4, 5, {"left": "+"}),
                  T("c", 0, 0, 2, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [],
        "exits": [E(0, 0, "up", 16)],
    },
    {
        # 「大きい方から引く」「割り切れる方でしか割れない」を、盤の広さで再確認する。
        "levelId": "v3_004",
        "title": "順序を組み立てる",
        "hint": "先に引き算を済ませる",
        "rows": 5,
        "cols": 5,
        "tiles": [T("a", 4, 0, 20), T("b", 0, 0, 4, {"down": "−"}),
                  T("c", 4, 4, 4, {"left": "÷", "up": "÷"})],
        "walls": [],
        "floors": [],
        "exits": [E(4, 4, "right", 4)],
    },
    {
        # ボス: 二組をそれぞれ組み立ててから、最後にその結果同士をぶつける。
        "levelId": "v3_005",
        "title": "四枚のボス",
        "hint": "二組に分けてから最後にひとつへ",
        "rows": 5,
        "cols": 6,
        "tiles": [T("a", 4, 0, 6), T("b", 0, 0, 3, {"down": "×", "right": "+"}),
                  T("c", 4, 5, 8), T("d", 0, 5, 2, {"down": "÷"})],
        "walls": [],
        "floors": [],
        "exits": [E(0, 0, "up", 22)],
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
        "levelId": "v3_007",
        "title": "大きい方から引く",
        "hint": "負になる向きには当てられない",
        "tutorial": True,
        "rows": 3,
        "cols": 5,
        "tiles": [T("a", 2, 0, 9), T("b", 2, 4, 4, {"left": "−"}),
                  T("c", 0, 0, 2, {"down": "×"})],
        "walls": [W(1, 2)],
        "floors": [F(2, 2, "ice")],
        "exits": [E(0, 0, "up", 10)],
    },
    {
        # 上下の氷レーンを行きと帰りで使う。上の氷は出口までの近道になる。
        "levelId": "v3_008",
        "title": "氷で一気に",
        "hint": "氷は当たるまで止まらない",
        "rows": 6,
        "cols": 5,
        "tiles": [T("a", 5, 0, 4), T("b", 5, 4, 5, {"left": "+"}),
                  T("c", 0, 0, 3, {"down": "×"})],
        "walls": [],
        "floors": [F(5, 1, "ice"), F(5, 2, "ice"), F(5, 3, "ice"),
                   F(0, 1, "ice"), F(0, 2, "ice"), F(0, 3, "ice")],
        "exits": [E(0, 4, "right", 27)],
    },
    {
        # 下の氷で一気に寄せてから、上は氷が無いので一歩ずつ運ぶ。
        "levelId": "v3_009",
        "title": "氷で二段仕込み",
        "hint": "氷が無い側は歩いて運ぶ",
        "size": 5,
        "tiles": [T("a", 4, 0, 2), T("b", 4, 4, 6, {"left": "+"}),
                  T("c", 0, 0, 3, {"down": "×"})],
        "walls": [],
        "floors": [F(4, 1, "ice"), F(4, 2, "ice"), F(4, 3, "ice")],
        "exits": [E(0, 4, "right", 24)],
    },
    {
        # ボス: 二本の氷レーンを使って二組を仕込み、最後にぶつけ合う。
        "levelId": "v3_010",
        "title": "二本の氷レーン",
        "hint": "両端から仕込んで中央でぶつける",
        "size": 6,
        "tiles": [T("a", 5, 0, 8), T("b", 5, 5, 2, {"left": "×", "up": "×"}),
                  T("c", 0, 0, 20), T("d", 0, 5, 4, {"left": "−", "down": "−"})],
        "walls": [],
        "floors": [F(5, 1, "ice"), F(5, 2, "ice"), F(5, 3, "ice"), F(5, 4, "ice"),
                   F(0, 1, "ice"), F(0, 2, "ice"), F(0, 3, "ice"), F(0, 4, "ice")],
        "exits": [E(5, 5, "down", 256)],
    },

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
        "title": "平方根の床",
        "hint": "平方数でないと入れない",
        "size": 4,
        "tiles": [T("a", 3, 0, 4), T("b", 3, 2, 9, {"left": "×"}),
                  T("c", 0, 0, 2, {"down": "+"})],
        "walls": [W(1, 1), W(2, 2)],
        "floors": [F(3, 3, "sqrt", uses=1)],
        "exits": [E(0, 0, "up", 8)],
    },
    {
        # 氷レーンの端に √ を置く。作った 36 をいったん右端まで滑らせて
        # 根を取り、また左端へ戻してから上へ運ぶ「往復」がねらい。
        "levelId": "v3_014",
        "title": "根を経由する遠回り",
        "hint": "大きく作ってから根で小さくする",
        "size": 5,
        "tiles": [T("a", 4, 0, 4), T("b", 4, 4, 9, {"left": "×"}),
                  T("c", 0, 0, 7, {"down": "+"})],
        "walls": [],
        "floors": [F(4, 1, "ice"), F(4, 2, "ice"), F(4, 3, "ice"),
                   F(4, 4, "sqrt", uses=1)],
        "exits": [E(0, 0, "up", 13)],
    },
    {
        # ボス: 81 → 9 → 3 と根を二回通す。上下の氷レーンで端から端へ運ぶ。
        "levelId": "v3_015",
        "title": "根を二回",
        "hint": "81 を 3 まで落とす",
        "rows": 7,
        "cols": 6,
        "tiles": [T("a", 6, 0, 9), T("b", 6, 5, 9, {"left": "×"}),
                  T("c", 0, 0, 5, {"right": "+"})],
        "walls": [],
        "floors": [F(6, 1, "ice"), F(6, 2, "ice"), F(6, 3, "ice"), F(6, 4, "ice"),
                   F(6, 5, "sqrt", uses=1),
                   F(0, 1, "ice"), F(0, 2, "ice"), F(0, 3, "ice"), F(0, 4, "ice"),
                   F(0, 5, "sqrt", uses=1)],
        "exits": [E(0, 0, "up", 8)],
    },

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
        "title": "階乗の床",
        "hint": "42 は 4・3・2 だけでは作れない",
        "size": 4,
        "tiles": [T("a", 3, 0, 4), T("b", 0, 3, 3, {"down": "−"}),
                  T("c", 3, 3, 2, {"up": "×"})],
        "walls": [W(1, 1), W(2, 2)],
        "floors": [F(3, 1, "fact", uses=1)],
        "exits": [E(3, 3, "down", 42)],
    },
    {
        # 階乗の範囲(0〜8)を超えないよう先に小さくしてから使う必要がある。
        "levelId": "v3_019",
        "title": "範囲に収めてから階乗",
        "hint": "! に入れる前は 8 以下に",
        "size": 5,
        "tiles": [T("a", 4, 0, 20), T("b", 4, 4, 15, {"left": "−"}),
                  T("c", 0, 0, 1, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(0, 2, "fact", uses=1)],
        "exits": [E(0, 4, "right", 120)],
    },
    {
        # ボス: 階乗を二回使って大きな値を組み立てる。
        "levelId": "v3_020",
        "title": "階乗を二回",
        "hint": "両方の階乗を通す順番を考える",
        "size": 6,
        "tiles": [T("a", 5, 0, 3), T("b", 5, 5, 1, {"left": "+", "up": "+"}),
                  T("c", 0, 0, 2, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(5, 2, "fact", uses=1), F(0, 2, "fact", uses=1)],
        "exits": [E(0, 5, "right", 48)],
    },

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
        "levelId": "v3_022",
        "title": "入れ替えてから当てる",
        "hint": "＋のままでは出せない",
        "tutorial": True,
        "rows": 1,
        "cols": 6,
        "tiles": [T("a", 0, 0, 12), T("b", 0, 2, 4, {"left": "+"})],
        "walls": [],
        "floors": [F(0, 1, "swap", uses=1)],
        "exits": [E(0, 5, "right", 8)],
    },
    {
        "levelId": "v3_023",
        "title": "演算子を入れ替える",
        "hint": "＋のままでは 8 が作れない",
        "rows": 4,
        "cols": 3,
        "tiles": [T("a", 3, 0, 12), T("b", 0, 2, 4, {"down": "+"}),
                  T("c", 3, 2, 2, {"up": "×"})],
        "walls": [W(1, 1)],
        "floors": [F(0, 0, "swap", uses=1)],
        "exits": [E(3, 2, "down", 16)],
    },
    {
        "levelId": "v3_024",
        "title": "二度の入替",
        "hint": "行きと帰りで別々に入れ替える",
        "size": 5,
        "tiles": [T("a", 4, 0, 6), T("b", 4, 4, 2, {"left": "÷"}),
                  T("c", 0, 0, 5, {"down": "−", "right": "−"})],
        "walls": [],
        "floors": [F(4, 2, "swap", uses=1), F(0, 2, "swap", uses=1)],
        "exits": [E(0, 4, "right", 7)],
    },
    {
        # ボス: 氷で ⇄ の上へ滑り込ませてから当てる。氷に乗ると
        # 止まりたいマスで止まれないので、順番を間違えると ⇄ を無駄打ちする。
        "levelId": "v3_025",
        "title": "入替とスライドのボス",
        "hint": "滑る前に演算子を整える",
        "rows": 6,
        "cols": 5,
        "tiles": [T("a", 5, 0, 24), T("b", 5, 4, 6, {"left": "×"}),
                  T("c", 0, 0, 5, {"down": "+"})],
        "walls": [],
        "floors": [F(5, 1, "ice"), F(5, 2, "swap", uses=1), F(5, 3, "ice")],
        "exits": [E(0, 0, "up", 9)],
    },

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
        # 回転が必須になる形。6 の右辺と 4 の左辺の両方に演算子があるので
        # そのままでは横からぶつかれない。どちらかを回して面を空けるしかない。
        "levelId": "v3_028",
        "title": "硬い面どうし",
        "hint": "両方に演算子があると当たらない",
        "size": 4,
        "tiles": [T("a", 3, 1, 6, {"right": "×"}),
                  T("b", 3, 2, 4, {"left": "+"}),
                  T("c", 0, 3, 2, {"down": "+"})],
        "walls": [W(1, 1), W(2, 1), W(1, 2), W(2, 2)],
        "floors": [F(3, 0, "rotate", uses=1)],
        "exits": [E(0, 3, "up", 26)],
    },
    {
        # 地形で当てる向きが縦に限定されるのに、演算子が横向きに付いている。
        "levelId": "v3_029",
        "title": "向きを作り直す",
        "hint": "邪魔な演算子を横へ逃がす",
        "rows": 4,
        "cols": 4,
        "tiles": [T("a", 3, 0, 20, {"up": "÷"}),
                  T("b", 2, 0, 5, {"down": "−"}),
                  T("c", 0, 3, 3, {"down": "×"})],
        "walls": [W(1, 1), W(2, 2)],
        "floors": [F(2, 1, "rotate", uses=1)],
        "exits": [E(0, 3, "up", 12)],
    },
    {
        # ボス（総仕上げ）: 氷・回転・階乗の回数制限を一度に使う。
        "levelId": "v3_030",
        "title": "総仕上げ",
        "hint": "床は使い切りに注意",
        "rows": 4,
        "cols": 5,
        "tiles": [T("a", 3, 0, 4), T("b", 3, 4, 6, {"left": "÷"}),
                  T("c", 0, 0, 20, {"down": "−"}), T("d", 0, 4, 2, {"down": "×"})],
        "walls": [W(1, 2), W(2, 2)],
        "floors": [F(3, 2, "ice"), F(1, 4, "rotate", uses=1)],
        "exits": [E(0, 0, "up", 8)],
    },

    # ================================================================
    # ブロック7（31-35）複数の出口
    # ================================================================
    {
        "levelId": "v3_031",
        "title": "出口はふたつ",
        "hint": "値ごとに出口が違う",
        "tutorial": True,
        "rows": 1,
        "cols": 5,
        "tiles": [T("a", 0, 1, 3), T("b", 0, 3, 5)],
        "walls": [W(0, 2)],
        "floors": [],
        "exits": [E(0, 0, "left", 3), E(0, 4, "right", 5)],
    },
    {
        "levelId": "v3_032",
        "title": "行き先を選ぶ",
        "hint": "作った値に合う出口へ",
        "tutorial": True,
        "rows": 1,
        "cols": 7,
        "tiles": [T("a", 0, 2, 6), T("b", 0, 1, 3, {"right": "−"}),
                  T("c", 0, 4, 10), T("d", 0, 5, 5, {"left": "÷"})],
        "walls": [W(0, 3)],
        "floors": [],
        "exits": [E(0, 0, "left", 3), E(0, 6, "right", 2)],
    },
    {
        # 壁で二本の道に割り、それぞれで別の式を組み立てて別の出口へ出す。
        "levelId": "v3_033",
        "title": "二本立てで組み立てる",
        "hint": "左右で別々の式を作る",
        "rows": 4,
        "cols": 5,
        "tiles": [T("a", 3, 1, 5), T("b", 3, 0, 4, {"right": "+"}),
                  T("c", 3, 3, 2), T("d", 3, 4, 3, {"left": "×"})],
        "walls": [W(0, 2), W(1, 2), W(2, 2), W(3, 2)],
        "floors": [],
        "exits": [E(0, 0, "up", 9), E(0, 4, "up", 6)],
    },
    {
        # 出口が三つ。似た値が並ぶので、どれをどこへ出すか取り違えやすい。
        "levelId": "v3_034",
        "title": "三つの行き先",
        "hint": "似た値ほど出口を間違えやすい",
        "rows": 4,
        "cols": 4,
        "tiles": [T("a", 3, 0, 6), T("b", 3, 1, 4, {"left": "+"}),
                  T("c", 3, 2, 3, {"left": "×"}), T("d", 3, 3, 3)],
        "walls": [],
        "floors": [],
        "exits": [E(0, 0, "up", 6), E(0, 2, "up", 12), E(0, 3, "up", 3)],
    },
    {
        # ボス: 壁で二本に割り、片方は組み立ててから、もう片方はそのまま出す。
        # 右側の 2 枚は掛けると 14 になって行き場を失う（合わせてはいけない組）。
        "levelId": "v3_035",
        "title": "出口の総仕上げ",
        "hint": "組み立てる物とそのまま出す物を見分ける",
        "size": 5,
        "tiles": [T("a", 4, 1, 5), T("b", 4, 0, 4, {"right": "+"}),
                  T("c", 4, 3, 7, {"right": "×"}), T("d", 4, 4, 2)],
        "walls": [W(0, 2), W(1, 2), W(2, 2), W(3, 2), W(4, 2)],
        "floors": [],
        "exits": [E(0, 0, "up", 9), E(0, 3, "up", 7), E(0, 4, "up", 2)],
    },

    # ================================================================
    # ブロック8（36-40）範囲を受け付ける出口
    # ================================================================
    {
        "levelId": "v3_036",
        "title": "範囲で受け付ける出口",
        "hint": "ぴったりでなくても出せる",
        "tutorial": True,
        "rows": 1,
        "cols": 4,
        "tiles": [T("a", 0, 0, 9)],
        "walls": [],
        "floors": [],
        "exits": [E(0, 3, "right", rng=(5, 15))],
    },
    {
        "levelId": "v3_037",
        "title": "収まる形を探す",
        "hint": "大きすぎても小さすぎても出せない",
        "tutorial": True,
        "rows": 1,
        "cols": 5,
        "tiles": [T("a", 0, 0, 9), T("b", 0, 1, 4, {"left": "+"})],
        "walls": [],
        "floors": [],
        "exits": [E(0, 4, "right", rng=(10, 14))],
    },
    {
        # 範囲出口＋√。作りすぎると範囲を外れるので、根で調整する必要がある。
        "levelId": "v3_038",
        "title": "範囲に合わせて調整する",
        "hint": "大きく作ってから根で収める",
        "size": 5,
        "tiles": [T("a", 4, 0, 7), T("b", 4, 4, 9, {"left": "×"}),
                  T("c", 0, 0, 1, {"down": "+", "right": "+"})],
        "walls": [],
        "floors": [F(0, 2, "sqrt", uses=1)],
        "exits": [E(0, 4, "right", rng=(8, 9))],
    },
    {
        # 範囲出口＋氷。際どい範囲なので、作る順番を変えると入らなくなる。
        "levelId": "v3_039",
        "title": "範囲を外さない",
        "hint": "際どい値ほど正確に運ぶ",
        "size": 5,
        "tiles": [T("a", 4, 0, 6), T("b", 4, 4, 5, {"left": "−"}),
                  T("c", 0, 0, 3, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(4, 2, "ice")],
        "exits": [E(0, 4, "right", rng=(2, 4))],
    },
    {
        # ボス: 壁で二本に割り、片方は掛けて範囲へ、片方は階乗で範囲へ入れる。
        "levelId": "v3_040",
        "title": "範囲の振り分け",
        "hint": "どちらの範囲に収まるか見極める",
        "rows": 4,
        "cols": 4,
        "tiles": [T("a", 3, 1, 2), T("b", 3, 0, 6, {"right": "×"}),
                  T("c", 3, 3, 4)],
        "walls": [W(0, 2), W(1, 2), W(2, 2), W(3, 2)],
        "floors": [F(2, 3, "fact", uses=1)],
        "exits": [E(0, 0, "up", rng=(10, 14)), E(0, 3, "up", rng=(20, 25))],
    },

    # ================================================================
    # ブロック9-10（41-50）総仕上げ（高難度・組み合わせ）
    # ================================================================
    {
        "levelId": "v3_041",
        "title": "総仕上げ1：氷と根",
        "hint": "滑らせてから根で整える",
        "size": 5,
        "tiles": [T("a", 4, 0, 8), T("b", 4, 4, 8, {"left": "+"}),
                  T("c", 0, 0, 2, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(4, 1, "ice"), F(4, 2, "ice"), F(0, 2, "sqrt", uses=1)],
        "exits": [E(0, 4, "right", 12)],
    },
    {
        # ＋のままでは 14 になり ! に入れない。⇄ で − にして 6 を作る。
        "levelId": "v3_042",
        "title": "総仕上げ2：階乗と入替",
        "hint": "＋のままでは! に入れられない",
        "size": 5,
        "tiles": [T("a", 4, 0, 10), T("b", 4, 4, 4, {"left": "+"})],
        "walls": [],
        "floors": [F(4, 1, "ice"), F(4, 2, "swap", uses=1), F(4, 3, "ice"),
                   F(0, 0, "fact", uses=1)],
        "exits": [E(0, 0, "up", 720)],
    },
    {
        "levelId": "v3_043",
        "title": "総仕上げ3：回転と氷",
        "hint": "回してから滑らせる",
        "size": 5,
        "tiles": [T("a", 4, 0, 6), T("b", 4, 4, 3, {"up": "×"}),
                  T("c", 0, 0, 9, {"down": "−", "right": "−"})],
        "walls": [],
        "floors": [F(4, 2, "rotate", uses=1), F(4, 3, "ice")],
        "exits": [E(0, 4, "right", 9)],
    },
    {
        # 片方は根を通さないと出口の値にならない。もう片方は素直に足すだけ。
        "levelId": "v3_044",
        "title": "総仕上げ4：複数出口と根",
        "hint": "根を通した方だけがその出口に合う",
        "rows": 4,
        "cols": 3,
        "tiles": [T("a", 3, 0, 9), T("b", 3, 1, 4),
                  T("c", 3, 2, 6, {"left": "+"})],
        "walls": [],
        "floors": [F(1, 0, "sqrt", uses=1)],
        "exits": [E(0, 0, "up", 3), E(0, 2, "up", 10)],
    },
    {
        "levelId": "v3_045",
        "title": "総仕上げ5：範囲と階乗",
        "hint": "! を通してから範囲に収める",
        "size": 6,
        "tiles": [T("a", 5, 0, 3), T("b", 5, 5, 1, {"left": "+", "up": "+"}),
                  T("c", 0, 0, 2, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(5, 2, "fact", uses=1)],
        "exits": [E(0, 5, "right", rng=(45, 50))],
    },
    {
        "levelId": "v3_046",
        "title": "総仕上げ6：入替と根の連携",
        "hint": "順序を間違えると届かない",
        "size": 6,
        "tiles": [T("a", 5, 0, 5), T("b", 5, 5, 20, {"left": "−", "up": "−"}),
                  T("c", 0, 0, 2, {"down": "×", "right": "×"})],
        "walls": [],
        "floors": [F(5, 2, "swap", uses=1), F(0, 2, "sqrt", uses=1)],
        "exits": [E(0, 5, "right", 10)],
    },
    {
        # 壁で二本に割る。左は互いの接する面に演算子があって当たれないので、
        # 片方を ↻ で逃がしてから、下から当て直す形にするしかない。
        "levelId": "v3_047",
        "title": "総仕上げ7：回転と複数出口",
        "hint": "当てられる面をどう作るか",
        "rows": 4,
        "cols": 4,
        "tiles": [T("a", 3, 0, 3, {"right": "+"}), T("b", 3, 1, 5, {"left": "×"}),
                  T("c", 0, 3, 4), T("d", 3, 3, 6, {"up": "×"})],
        "walls": [W(0, 2), W(1, 2), W(2, 2), W(3, 2)],
        "floors": [F(0, 0, "rotate", uses=1)],
        "exits": [E(0, 0, "up", 8), E(3, 3, "down", 24)],
    },
    {
        # 64 のままでは範囲に入らない。氷で根の上へ運んで 8 に落としてから足す。
        "levelId": "v3_048",
        "title": "総仕上げ8：範囲・根・氷",
        "hint": "滑って作った値を根で範囲に収める",
        "rows": 6,
        "cols": 5,
        "tiles": [T("a", 5, 0, 8), T("b", 5, 4, 8, {"left": "×"}),
                  T("c", 0, 4, 3, {"down": "+"})],
        "walls": [],
        "floors": [F(5, 1, "ice"), F(5, 2, "ice"), F(5, 3, "ice"),
                   F(5, 4, "sqrt", uses=1)],
        "exits": [E(0, 4, "up", rng=(10, 12))],
    },
    {
        "levelId": "v3_049",
        "title": "総仕上げ9：全ギミック前半",
        "hint": "回転・入替・氷を順に使う",
        "rows": 6,
        "cols": 6,
        "tiles": [T("a", 5, 0, 4), T("b", 5, 5, 2, {"up": "÷"}),
                  T("c", 0, 0, 10, {"down": "+", "right": "+"})],
        "walls": [],
        "floors": [F(5, 2, "rotate", uses=1), F(5, 3, "swap", uses=1),
                   F(0, 2, "ice")],
        "exits": [E(0, 5, "right", 12)],
    },
    {
        # 最終ボス。壁で二本に割り、⇄ と ! で 720 を、↻ と √ で 9 を作る。
        "levelId": "v3_050",
        "title": "最終ボス",
        "hint": "これまでの床を全部使うつもりで",
        "size": 5,
        "tiles": [T("a", 4, 0, 10), T("b", 4, 1, 4, {"left": "+"}),
                  T("c", 4, 4, 9), T("d", 4, 3, 9, {"up": "×"})],
        "walls": [W(0, 2), W(1, 2), W(2, 2), W(3, 2), W(4, 2)],
        "floors": [F(3, 1, "swap", uses=1), F(0, 0, "fact", uses=1),
                   F(3, 3, "rotate", uses=1), F(1, 3, "sqrt", uses=1)],
        "exits": [E(0, 0, "up", 720), E(0, 3, "up", 9)],
    },
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
