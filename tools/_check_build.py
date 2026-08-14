"""ビルド済み main.dart.js に、期待する機能の痕跡が入っているか調べる。"""
import sys

path = sys.argv[1]
data = open(path, "rb").read().decode("utf-8", errors="replace")

checks = {
    "クリア！（演出/ダイアログの文字）": "クリア！",
    "手数オーバー": "手数オーバー",
    "その向きには動けません": "その向きには動けません",
    "平方数でないと": "平方数でないと",
    "レベル選択": "レベル選択",
}
for label, s in checks.items():
    print(f"{label:34} {data.count(s):>3} 件")
print()
print("サイズ:", len(data))
