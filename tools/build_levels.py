"""レベル候補を検証し、合格したものだけを assets/levels/levels.json に書き出す。

使い方:
    python tools/build_levels.py            … 検証してレポート表示 + JSON 出力
    python tools/build_levels.py --report   … 検証レポートのみ（出力しない）

不合格（クリア不能 / 出口がマス内 / 使わない行列がある 等）のレベルは
JSON に書き出さず、エラーとして表示する。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from solver import analyze, explore, goal_distance, cells_used_on_optimal, wall_candidates  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_JSON = os.path.join(ROOT, "assets", "levels", "levels.json")


def P(pid, row, col, tokens, fixed=False, slide=False):
    d = {"id": pid, "row": row, "col": col, "tokens": tokens}
    if fixed:
        d["fixed"] = True
    if slide:
        d["slide"] = True        # 止まるまで滑るタイル
    return d


def W(row, col):
    return {"row": row, "col": col}


def E(row, col, direction, value=None, rng=None):
    d = {"row": row, "col": col, "direction": direction}
    if rng is not None:
        d["minValue"], d["maxValue"] = rng
    elif value is not None:
        d["value"] = value
    return d


# ============================================================
# レベル候補
# ============================================================
CANDIDATES = [
    # ---------- チュートリアル（難易度の足切りは免除） ----------
    {
        "levelId": "level_001",
        "title": "はじめての結合",
        "hint": "数字を演算子にぶつける",
        "tutorial": True,
        "size": 3,
        "pieces": [P("a", 1, 0, [8]), P("b", 1, 1, ["÷", 4])],
        "walls": [W(0, 0), W(0, 1), W(0, 2), W(2, 0), W(2, 1), W(2, 2)],
        "exits": [E(1, 2, "right", 2)],
    },
    {
        "levelId": "level_002",
        "title": "ぶつける向き",
        "hint": "ぶつけた側が式の前になる",
        "tutorial": True,
        "size": 3,
        "pieces": [P("a", 1, 0, [3]), P("b", 1, 1, ["+"]), P("c", 1, 2, [5]),
                   P("d", 0, 0, ["×"])],
        "walls": [W(2, 0), W(2, 1), W(2, 2), W(0, 1)],
        "exits": [E(1, 2, "right", 8)],
    },
    {
        "levelId": "level_003",
        "title": "動かせないタイル",
        "hint": "灰色のタイルは動かせない",
        "tutorial": True,
        "size": 3,
        "pieces": [P("a", 2, 0, [6]), P("b", 1, 0, ["×"]),
                   P("c", 0, 0, [7], fixed=True)],
        "walls": [W(0, 1), W(1, 1), W(2, 1), W(0, 2), W(1, 2), W(2, 2)],
        "exits": [E(0, 0, "up", 42)],
    },

    # ---------- 本編（難易度の閾値をすべて満たすこと） ----------
    {
        # 24 ÷ (7 − 3) = 6。÷ も − も非可換なので組み立て順が一通りに決まる。
        # 24−3=21, 21÷7=3 のような「作れるが出せない値」が罠になる。
        "levelId": "level_004",
        "title": "順番がすべて",
        "hint": "先に引き算を作る",
        "size": 4,
        "pieces": [P("a", 0, 0, [24]), P("b", 2, 2, ["÷"]), P("c", 3, 0, [7]),
                   P("d", 3, 2, ["−"]), P("e", 1, 3, [3])],
        "walls": [W(1, 1)],
        "exits": [E(0, 3, "up", 6)],
    },
    {
        # レンジ出口。大きく作りすぎても小さすぎても出せない。
        "levelId": "level_005",
        "title": "ちょうどに収める",
        "hint": "20〜25 に収まる形を探す",
        "size": 4,
        "pieces": [P("a", 0, 0, [9]), P("b", 1, 2, ["×"]), P("c", 3, 1, [3]),
                   P("d", 2, 0, ["−"]), P("e", 3, 3, [5])],
        "walls": [W(1, 1)],
        "exits": [E(0, 3, "up", rng=(20, 25))],
    },
    {
        # 固定タイルを軸にする。動かせない 24 に式を運んでぶつける。
        "levelId": "level_006",
        "title": "動かない的",
        "hint": "固定タイルへ式を運ぶ",
        "size": 4,
        "pieces": [P("a", 0, 0, [24], fixed=True), P("b", 3, 0, [96]),
                   P("c", 3, 2, ["÷"]), P("d", 2, 3, [4]), P("e", 1, 2, ["+"])],
        "walls": [W(1, 1), W(2, 1)],
        "exits": [E(0, 0, "up", 48)],
    },
    {
        # 平方根。√ を数字の前につける必要があり、順序を間違えると詰む。
        "levelId": "level_007",
        "title": "平方根",
        "hint": "√ を使う相手を間違えない",
        "size": 4,
        # √ が 4 の隣にある。√4=2 は合法だがその瞬間に詰む（10 が作れなくなる）。
        "pieces": [P("a", 1, 2, ["√"]), P("b", 0, 1, [36]), P("c", 3, 0, ["+"]),
                   P("d", 1, 3, [4]), P("e", 2, 2, ["×"])],
        "walls": [W(1, 1)],
        "exits": [E(0, 3, "up", 10)],
    },
    {
        # 階乗。4! = 24 を作ってから割る。! を先に使いすぎると届かない。
        "levelId": "level_008",
        "title": "階乗",
        "hint": "! は数字の後ろにつく",
        "size": 4,
        "pieces": [P("a", 3, 0, [4]), P("b", 2, 2, ["!"]), P("c", 0, 1, ["÷"]),
                   P("d", 1, 3, [6]), P("e", 3, 2, ["+"])],
        "walls": [W(1, 1)],
        "exits": [E(0, 3, "up", 4)],
    },
    {
        # 出口が2つ。どの数字をどちらへ回すかで手数が変わる。
        "levelId": "level_009",
        "title": "ふたつの出口",
        "hint": "数字ごとに行き先が違う",
        "size": 4,
        # − は非可換なので 2−3 も 3−2 も出口を通れず、6 を作る筋しか残らない。
        "pieces": [P("a", 3, 0, [2]), P("b", 2, 2, ["×"]), P("c", 3, 3, [3]),
                   P("d", 0, 1, [5]), P("e", 1, 0, ["−"])],
        "walls": [W(2, 1)],
        "exits": [E(0, 0, "up", 6), E(0, 3, "up", 5)],
    },
    {
        # 累乗。3^3=27 から 7 を引く。^ の相手を間違えると爆発して出せない。
        "levelId": "level_010",
        "title": "累乗",
        "hint": "^ の右に来る数で決まる",
        "size": 4,
        "pieces": [P("a", 3, 0, [3]), P("b", 2, 2, ["^"]), P("c", 3, 3, [3]),
                   P("d", 1, 0, ["−"]), P("e", 0, 2, [7])],
        "walls": [W(1, 2)],
        "exits": [E(0, 0, "up", 20)],
    },
    {
        # 滑るタイルの入門。1マスずつではなく、当たるまで一気に進む。
        "levelId": "level_011",
        "title": "滑るタイル",
        "hint": "緑のタイルは止まるまで滑る",
        "tutorial": True,
        "size": 3,
        "pieces": [P("a", 2, 0, [12], slide=True), P("b", 2, 2, ["÷"]),
                   P("c", 0, 1, [4])],
        "walls": [],
        "exits": [E(0, 1, "up", 3)],
    },
    {
        # 滑るタイルは止めたい場所に止まってくれない。
        # 別のタイルを置いてぶつける相手を作ってから動かす必要がある。
        "levelId": "level_012",
        "title": "止め方を考える",
        "hint": "滑る先に何を置くか",
        "size": 4,
        "pieces": [P("a", 3, 0, [30], slide=True), P("b", 1, 1, ["÷"]),
                   P("c", 3, 3, [5]), P("d", 0, 2, ["+"]), P("e", 2, 0, [4])],
        "walls": [W(2, 2)],
        "exits": [E(0, 0, "up", 10)],
    },
]


def optimize_walls(level, target_routes=2, max_added=4):
    """簡単な別解を潰す位置に壁を足す（意図した最短手順は壊さない）。

    最短手順で一度も使わないマスに壁を置いても、その手順は必ず残る。
    その中で「解法の総数が最も減る」位置を貪欲に選ぶ。
    """
    added = []
    for _ in range(max_added):
        base = analyze(level)
        if not base.get("solvable") or base["errors"]:
            break
        if base["routes_within_slack"] <= target_routes:
            break
        lv = dict(level)
        lv["_wallset"] = {(w["row"], w["col"]) for w in lv["walls"]}
        start, dist, adj, _tr = explore(lv)
        dgoal = goal_distance(dist, adj)
        cands = wall_candidates(lv, start, adj, dgoal, dgoal[start])
        best = None
        for (r, c) in cands:
            trial = dict(level)
            trial["walls"] = level["walls"] + [W(r, c)]
            rep = analyze(trial)
            if not rep.get("solvable") or rep["errors"]:
                continue
            score = (rep["routes_within_slack"], rep["par"])
            if best is None or score < best[0]:
                best = (score, (r, c), rep)
        if best is None:
            break
        score, cell, rep = best
        if score[0] >= base["routes_within_slack"]:
            break
        level = dict(level)
        level["walls"] = level["walls"] + [W(cell[0], cell[1])]
        added.append(cell)
    return level, added


def main():
    report_only = "--report" in sys.argv
    optimize = "--optimize" in sys.argv

    results = []
    ok_levels = []
    for cand in CANDIDATES:
        lv = json.loads(json.dumps(cand))  # deep copy
        added = []
        if optimize:
            lv, added = optimize_walls(lv)
        rep = analyze(lv)
        rep["added_walls"] = added
        results.append((lv, rep))
        if not rep["errors"] and rep.get("solvable"):
            out = {k: v for k, v in lv.items() if not k.startswith("_")}
            out["par"] = rep["par"]
            out["routes"] = rep["routes_within_slack"]
            ok_levels.append(out)

    print("=" * 96)
    print(f"{'level':<12}{'解':<4}{'par':<5}{'解法':<5}{'一本道率':<9}"
          f"{'外れ手/局面':<12}{'詰み手':<7}{'ひっかけ':<9}{'状態数':<8}")
    print("=" * 96)
    for lv, rep in results:
        if rep.get("solvable"):
            d = rep["difficulty"]
            print(f"{rep['levelId']:<12}{'○':<4}{rep['par']:<5}{rep['routes_optimal']:<5}"
                  f"{d['forced_ratio']:<9}{d['wrong_per_step']:<12}{d['trap_edges']:<7}"
                  f"{len(d['decoy_values']):<9}{rep['states']:<8}  {rep['title']}")
        else:
            print(f"{rep['levelId']:<12}{'×':<4}{'-':<5}{'-':<5}{'-':<9}{'-':<12}"
                  f"{'-':<7}{'-':<9}{rep['states']:<8}  {rep['title']}")
        for e in rep["errors"]:
            print(f"    [ERROR] {e}")
        for w in rep["warnings"]:
            print(f"    [warn ] {w}")
        if rep.get("added_walls"):
            print(f"    [wall ] 追加した壁: {rep['added_walls']}")
        if rep.get("never_used_cells"):
            print(f"    [info ] 最短手順で使わないマス: {rep['never_used_cells']}")

    print("=" * 78)
    print(f"合格 {len(ok_levels)} / {len(CANDIDATES)}")

    if not report_only:
        os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
        with open(OUT_JSON, "w", encoding="utf-8") as f:
            json.dump({"levels": ok_levels}, f, ensure_ascii=False, indent=2)
        print(f"書き出し: {OUT_JSON}")

    return 0 if len(ok_levels) == len(CANDIDATES) else 1


if __name__ == "__main__":
    sys.exit(main())
