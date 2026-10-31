"""できあがった盤の「粗さ」を洗い出す。

判定（v3_solver）は「悪くないこと」しか見ていない。
歩きすぎでない・スカスカでない・分割されていない……という否定形の条件は、
通っていても「よく出来ている」ことを意味しない。
ここでは、遊んだときに安っぽく感じる具体的な兆候を数える。

見るもの:
  恒等演算   … ×1 / ÷1 / +0 / −0。手数は増えるが考えることは増えない
  余り物     … 抜いても解ける（＝置いてあるだけ）のタイル
  飾りの床   … 抜いても同じ手数で解ける床
  値の重複   … 同じ数字が複数あり、どれを使っても同じになりやすい

飾りの床（抜いても同じ手数で解ける床）は、さらに 3 つに分ける（2026-11-01 MP-5）:
  罠       … par 以内に乗れるが、乗ると必ず par で解けなくなる（「使わない判断」をさせる床。役割がある）
  寄り道   … 乗っても乗らなくても par で解ける（役割が無い）
  届かない … par 以内のどの手でも乗れない（役割が無い）
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from v3_solver import analyze, explore, goal_distance, optimal_state_path, prepare  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def identity_ops(level):
    """最短手順の中で「値が変わらない合体」が何回あるか。

    ×1 や +0 は、盤の上では 1 手ぶんの操作なのに、
    出来上がる数は動かす前と同じ。考える材料にならない手。
    """
    path = optimal_state_path(level)
    if not path:
        return []
    found = []
    for before, after in zip(path, path[1:]):
        bt, at = before[0], after[0]
        if len(at) >= len(bt):
            continue                      # 合体していない
        bv = sorted(v for (_r, _c, v, _e, _f) in bt)
        av = sorted(v for (_r, _c, v, _e, _f) in at)
        # 合体で消えた 2 つと、生まれた 1 つを突き合わせる
        rest = list(av)
        for v in bv:
            if v in rest:
                rest.remove(v)
        # rest に残るのが「新しく出来た値」。消えた 2 値を求める
        gone = list(bv)
        for v in av:
            if v in gone:
                gone.remove(v)
        if len(rest) == 1 and len(gone) == 2 and rest[0] in gone:
            found.append((gone, rest[0]))
    return found


def useless_tiles(level, par):
    """抜いても（同じ手数以内で）解けてしまうタイル＝置いてあるだけの駒。"""
    out = []
    for i, t in enumerate(level["tiles"]):
        trimmed = {k: v for k, v in level.items() if not k.startswith("_")}
        trimmed = json.loads(json.dumps(trimmed))
        del trimmed["tiles"][i]
        if not trimmed["tiles"]:
            continue
        try:
            rep = analyze(trimmed)
        except Exception:
            continue
        if rep.get("solvable"):
            out.append((t["id"], t.get("value")))
    return out


def floor_roles(level, par, floors):
    """飾りの床を 罠 / 寄り道 / 届かない に分ける。乗る＝その手のあとで、床のマスにタイルが来る。"""
    lv = json.loads(json.dumps(level))
    start, dist, adj, _ = explore(lv, max_depth=par)
    dgoal = goal_distance(dist, adj)
    roles = {}
    for f in floors:
        cell = (f["row"], f["col"])
        uses = fatal = 0
        for s, edges in adj.items():
            if dist[s] >= par:
                continue
            before = {(t[0], t[1]) for t in s[0]}
            for (ns, _k, _key) in edges:
                after = {(t[0], t[1]) for t in ns[0]}
                if cell in after and cell not in before:
                    uses += 1
                    d = dgoal.get(ns)
                    if d is None or dist[s] + 1 + d > par:
                        fatal += 1
        roles[cell] = "届かない" if uses == 0 else "罠" if fatal == uses else "寄り道"
    return roles


def main():
    with open(os.path.join(ROOT, "assets", "levels", "levels_v3.json"),
              encoding="utf-8") as f:
        levels = json.load(f)["levels"]

    only = set(sys.argv[1:]) or None
    totals = {"identity": 0, "useless": 0, "decor": 0, "dup": 0}

    for lv in levels:
        if only and lv["levelId"] not in only:
            continue
        work = json.loads(json.dumps(lv))
        prepare(work)
        rep = analyze(json.loads(json.dumps(lv)))
        if not rep.get("solvable"):
            continue

        notes = []

        ids = identity_ops(json.loads(json.dumps(lv)))
        if ids:
            notes.append(f"恒等演算 {len(ids)} 回: " +
                         ", ".join(f"{g}→{r}" for g, r in ids))
            totals["identity"] += len(ids)

        decor = [n["floor"] for n in rep.get("floors", []) if not n["needed"]]
        if decor:
            # 氷はまとめて 1 つ（ice xN）なので、役割の判定は氷以外だけ
            roles = floor_roles(lv, rep["par"], [f for f in decor if not f["type"].startswith("ice")])
            def label(f):
                role = roles.get((f["row"], f["col"]))
                return f"{f['type']}({f['row']},{f['col']})" + (f"={role}" if role else "")
            notes.append("飾りの床: " + ", ".join(label(f) for f in decor))
            totals["decor"] += len(decor)
            for r in roles.values():
                totals[r] = totals.get(r, 0) + 1

        vals = [t.get("value") for t in lv["tiles"] if not t.get("fire")]
        dups = {v for v in vals if vals.count(v) > 1}
        if dups:
            notes.append(f"同じ数字が複数: {sorted(dups)}")
            totals["dup"] += len(dups)

        ones = [t["id"] for t in lv["tiles"] if t.get("value") == 1]
        if ones:
            notes.append(f"1 のタイル: {ones}（×1・÷1 は何も変えない）")

        if notes:
            print(f"{lv['levelId']} (par {rep['par']})")
            for n in notes:
                print("   ", n)

    print()
    print("合計:", totals)
    return 0


if __name__ == "__main__":
    sys.exit(main())
