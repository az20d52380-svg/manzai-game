#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 稽古の成長逓減（career_report_v0.md §4-(5)-1 の本命レバー）
- 能力上昇量に ×(1−現在値/D) を掛ける。D が小さいほど高能力での伸びが鈍る
- balance_sim.py / sim_career.py は無変更。B.add をモンキーパッチして注入する
- 目的: 初優勝中央値を仕様想定の6〜9年目に入れる D を探し、
        その D の下で相性・初期能力（相方ガチャ/周回ボーナス相当）の効きを再計測する
- 使い方: python3 exp_decay.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import sys
import statistics

import balance_sim as B
import sim_career as C

DECAY_CANDIDATES = (None, 150, 120, 100)   # None=逓減なし

def install_decay(D):
    """逓減の強さを切り替える。balance_sim v0.2 で本体に組み込まれたため定数の差し替えだけでよい。
    注意: docs/career_report_v1.md の数値は能力上限100時代の計測。現在は上限120なので再実行すると変わる"""
    B.GROWTH_DECAY_D = D

def show(r, extra=""):
    n = r["n"]
    y1 = 100.0 * r["dist"][0] / n
    med = f"{r['median']:.0f}年目" if r["median"] <= C.YEARS else f">{C.YEARS}年"
    top = " ".join(f"{y}年:{100.0 * c / n:4.1f}%" for y, c in enumerate(r["dist"], 1))
    print(f"  {r['name']:　<8}{extra}| 中央値 {med:>6} / なし {r['none_rate']:5.1f}% / 1年目 {y1:4.2f}%")
    print(f"  {'':　<8}| {top}")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else C.N_CAREERS
    print(f"=== 成長逓減 感度実験 | 上昇量×(1−現在値/D) | {n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
    print()

    print("== 実験D: 逓減の強さ（基準設定: 相性5・成長あり・初期能力10） ==")
    for D in DECAY_CANDIDATES:
        label = "なし(v0)" if D is None else f"D={D}"
        print(f"[逓減 {label}]")
        install_decay(D)
        for cls in C.BOTS:
            show(C.run_config(cls, n))
    install_decay(None)
    print()

    # 実験Dの結果を見て「中央値6〜9年」に最も近い D をここに固定して再計測する
    D_PICK = 120
    print(f"== 実験E: 逓減D={D_PICK}の下で相性・初期能力の効き直し（相方ガチャ/周回ボーナスの再評価） ==")
    install_decay(D_PICK)
    for compat in (5, 10, 15, 20):
        print(f"[相性={compat} 固定・成長なし]")
        for cls in C.BOTS:
            show(C.run_config(cls, n, compat_fixed=compat))
    for ab in (10, 15, 20, 25):
        print(f"[初期能力={ab}（相性5・成長あり）]")
        for cls in C.BOTS:
            show(C.run_config(cls, n, init_ability=ab))
    print()

    print(f"== 実験F: 逓減D={D_PICK}のお金の推移（シンク規模の再確認） ==")
    for cls in C.BOTS:
        r = C.run_config(cls, n, track_money=True)
        show(r)
        for y, log in enumerate(r["money_log"], 1):
            if log:
                print(f"    {y}年目末: 所持金中央値 {B.yen(statistics.median(log)):>9} (残存 {len(log)})")
    install_decay(None)

if __name__ == "__main__":
    main()
