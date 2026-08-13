"""検証に合格したレベルを Flutter アプリのコース JSON に流し込む。

    python tools/build_course.py

入力（どちらも tools/v3_levels.py が生成する）:
    assets/levels/levels_v3.json   検証を通ったレベルだけが入っている
    tools/solutions_v3.json        各レベルの最短手順

出力:
    number_puzzle/assets/levels/main_course.json    アプリが読むコース定義
    number_puzzle/test/fixtures/solutions_v3.json   再生テストの期待値

レベルの追加・修正は v3_levels.py 側だけを触り、
    python tools/v3_levels.py && python tools/build_course.py
の順に流せばアプリとテストの両方が揃う。
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
APP = os.path.join(ROOT, "number_puzzle")

LEVELS_JSON = os.path.join(ROOT, "assets", "levels", "levels_v3.json")
SOLUTIONS_JSON = os.path.join(HERE, "solutions_v3.json")
OUT_COURSE = os.path.join(APP, "assets", "levels", "main_course.json")
OUT_FIXTURE = os.path.join(APP, "test", "fixtures", "solutions_v3.json")

COURSE_ID = "main"
COURSE_TITLE = "基本コース"


def main():
    with open(LEVELS_JSON, encoding="utf-8") as f:
        levels = json.load(f)["levels"]
    with open(SOLUTIONS_JSON, encoding="utf-8") as f:
        solutions = json.load(f)

    # 手順が無いレベルは再生テストで検証できないので、コースにも入れない
    # （検証を通っていれば必ず手順がある。念のための保険）。
    usable = [lv for lv in levels if solutions.get(lv["levelId"], {}).get("actions")]
    dropped = [lv["levelId"] for lv in levels if lv not in usable]
    if dropped:
        print(f"手順が無いため除外: {dropped}")

    course = {
        "courses": [
            {
                "courseId": COURSE_ID,
                "title": COURSE_TITLE,
                "levels": usable,
            }
        ]
    }

    os.makedirs(os.path.dirname(OUT_COURSE), exist_ok=True)
    with open(OUT_COURSE, "w", encoding="utf-8") as f:
        json.dump(course, f, ensure_ascii=False, indent=2)
    print(f"書き出し: {OUT_COURSE}（{len(usable)} レベル）")

    # 再生テストの期待値は、コースに入れたレベルの分だけにそろえる
    fixture = {lv["levelId"]: solutions[lv["levelId"]] for lv in usable}
    os.makedirs(os.path.dirname(OUT_FIXTURE), exist_ok=True)
    with open(OUT_FIXTURE, "w", encoding="utf-8") as f:
        json.dump(fixture, f, ensure_ascii=False, indent=2)
    print(f"書き出し: {OUT_FIXTURE}")

    for i, lv in enumerate(usable, 1):
        print(f"  {i:>2}. {lv['levelId']}  {lv['limit']:>2}手  {lv['title']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
