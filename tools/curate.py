"""生成した候補から、1 ブロック分を選んで v3_levels.py に貼れる形で書き出す。

    python tools/curate.py --pick b1_tutorial:2 b1:2 b1_boss:1 \
        --ids v3_001,v3_002,v3_003,v3_004,v3_005

候補は難易度（中身のある手の数）の順に並べ、指定した数だけ取る。
出力はそのまま v3_levels.py の LEVELS に貼り込める Python の断片。
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _readable(lv):
    """暗算しやすい盤かどうか。難しさに寄与しない「計算の面倒さ」を落とす。"""
    for e in lv["exits"]:
        lo, hi = e.get("minValue"), e.get("maxValue")
        if lo is not None and hi is not None and hi - lo > 4:
            return False          # 範囲が広い出口は問いが緩くなる
    for t in lv["tiles"]:
        if t.get("fire"):
            continue
        v = t.get("value", 0)
        if v > 24:
            return False
        # 13 以上の素数（17, 19, 23）は割れず足しにくいだけなので避ける
        if v in (17, 19, 23):
            return False
    return True


def load(spec_name):
    path = os.path.join(HERE, f"generated_{spec_name}.json")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)["levels"]


def fmt_edges(edges):
    if not edges:
        return None
    inner = ", ".join(f'"{k}": "{v}"' for k, v in edges.items())
    return "{" + inner + "}"


def fmt_level(lv, level_id, title, hint):
    out = []
    out.append("    {")
    out.append(f'        "levelId": "{level_id}",')
    out.append(f'        "title": "{title}",')
    out.append(f'        "hint": "{hint}",')
    if lv.get("tutorial"):
        out.append('        "tutorial": True,')
    if lv["rows"] == lv["cols"]:
        out.append(f'        "size": {lv["rows"]},')
    else:
        out.append(f'        "rows": {lv["rows"]},')
        out.append(f'        "cols": {lv["cols"]},')

    parts = []
    for t in lv["tiles"]:
        args = [f'"{t["id"]}"', str(t["row"]), str(t["col"])]
        if t.get("fire"):
            args.append("0")
            extra = ", fire=True"
        else:
            args.append(str(t["value"]))
            extra = ""
            e = fmt_edges(t.get("edges"))
            if e:
                args.append(e)
            if t.get("fixed"):
                extra = ", fixed=True"
        parts.append(f'T({", ".join(args)}{extra})')
    out.append('        "tiles": [' + ", ".join(parts) + "],")

    walls = ", ".join(f'W({w["row"]}, {w["col"]})' for w in lv["walls"])
    out.append(f'        "walls": [{walls}],')

    fparts = []
    for f in lv["floors"]:
        a = f'F({f["row"]}, {f["col"]}, "{f["type"]}"'
        if f.get("uses") is not None:
            a += f', uses={f["uses"]}'
        fparts.append(a + ")")
    out.append('        "floors": [' + ", ".join(fparts) + "],")

    eparts = []
    for e in lv["exits"]:
        a = f'E({e["row"]}, {e["col"]}, "{e["direction"]}"'
        if e.get("minValue") is not None:
            a += f', rng=({e["minValue"]}, {e["maxValue"]})'
        elif e.get("value") is not None:
            a += f', {e["value"]}'
        eparts.append(a + ")")
    out.append('        "exits": [' + ", ".join(eparts) + "],")
    out.append("    },")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pick", nargs="+", required=True,
                    help="spec名:枚数 の並び（例: b1_tutorial:2 b1:2）")
    ap.add_argument("--ids", required=True, help="割り当てるレベルID（カンマ区切り）")
    ap.add_argument("--titles", default="", help="タイトル（カンマ区切り、省略可）")
    args = ap.parse_args()

    chosen = []
    for item in args.pick:
        name, n = item.rsplit(":", 1)
        cands = [c for c in load(name) if _readable(c)]
        # 中身のある手が多い順＝考えることが多い順に並べる
        cands.sort(key=lambda c: (c["_report"].get("aha_forks", 0),
                                  c["_report"].get("par", 0)), reverse=True)
        chosen.extend(cands[:int(n)])

    ids = args.ids.split(",")
    titles = args.titles.split(",") if args.titles else []
    if len(chosen) < len(ids):
        print(f"候補が足りない: {len(chosen)} 件しかない（{len(ids)} 件必要）",
              file=sys.stderr)

    for i, (lv, level_id) in enumerate(zip(chosen, ids)):
        title = titles[i] if i < len(titles) else f"仮タイトル{i + 1}"
        print(fmt_level(lv, level_id, title, ""))
        r = lv["_report"]
        print(f"    # par={r.get('par')} 歩き={r.get('walk_ratio')} "
              f"密度={r.get('density')} アハ={r.get('aha_forks')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
