#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
正典v2の最終アンカー確定スキャン（docs/human_calibration_v0.md §5-C）
- canon_v2一式を適用し、GP準決×決勝の最終グリッドで「普通にやったら1%」への着地点を探す
- 帯の定義: 普通=のんびり改〜バランス型 / 上手い=分散稽古型（どれも優勝は稀・決勝到達2〜4割がA案の狙い）
- 使い方: python3 exp_v2_anchor.py [キャリア数/設定]   （省略時 1000）
- 数値は全て【仮】
"""

import statistics
import sys

import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    V.apply()
    print(f"=== 正典v2 最終アンカー | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"カーブ上限{V.CAP_CURVE} ハマ{V.BURST_P:.0%}/+{V.BURST_BONUS:.0f} | 全て【仮】 ===")
    print()
    try:
        for sf in (74, 75, 76):
            for fin in (80, 81, 82):
                C.GP_ROUNDS = V.GP_ROUNDS + [(45, sf, "GP準決勝")]
                C.GP_FINAL_LINE = fin
                C.GP_REVIVAL_LINE = fin + V.GP_REVIVAL_OFFSET
                print(f"[準決{sf} 決勝{fin}]")
                for cls in (PSpread, C.CareerBalanced, PCasual2):
                    pol = cls()
                    wins = finals = 0
                    years = []
                    for i in range(n):
                        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
                        if first is not None:
                            wins += 1
                            years.append(first)
                        finals += ever_final
                    med = statistics.median(years) if years else "-"
                    print(f"  {pol.name:　<6}| 優勝 {100.0*wins/n:5.2f}%(中央値{med}年) / 決勝到達 {100.0*finals/n:5.1f}%",
                          flush=True)
                print()
    finally:
        V.reset()

if __name__ == "__main__":
    main()
