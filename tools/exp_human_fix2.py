#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験2: 分散稽古の構造優位そのものを消す2レバー（docs/human_calibration_v0.md §3）
- exp_human_fix.py の結論: 借金ペナルティは「踏み倒し型」しか止めない。金管理する分散稽古型は
  どの修正でも優勝100%（実力値78超・ライン94に相性20で常勝）。真因は借金ではなく
  「能力ごとの逓減 × 無料稽古」の組み合わせが分散育成を構造的に最強にしていること。
- レバー:
    P1 稽古の有料化 … 無料稽古3種に稽古場代（ネタ作り/ネタ合わせ2万・フリーライブ3万）→ 金策が本質的に必要になり稽古週率が下がる
    P2 逓減の総合値化 … ×(1−現在値/D) を ×(1−実力値/D) に（balance_sim.GROWTH_DECAY_TOTAL）→ 分散と特化の成長が等価になる
    P1+P2 複合
- 使い方: python3 exp_human_fix2.py [キャリア数/設定]   （省略時 1000）
- 数値は全て【仮】
"""

import statistics
import sys

import balance_sim as B
import sim_career as C
from exp_human import PCasual
from exp_human_fix import PSpread

PAID = {"ネタ作り": 20_000, "ネタ合わせ": 20_000, "フリーライブ": 30_000}

def measure(n, bots):
    for cls in bots:
        pol = cls()
        wins = finals = 0
        jitsus = []
        for i in range(n):
            first, s, _stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
            wins += first is not None
            finals += ever_final
            jitsus.append(B.jitsuryoku(s))
        print(f"  {pol.name:　<7}| 優勝 {100.0*wins/n:6.2f}% / 決勝到達 {100.0*finals/n:5.1f}% / "
              f"10年目実力値 {statistics.median(jitsus):5.1f}", flush=True)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    bots = (B.PTrain, PSpread, C.CareerBalanced, PCasual)
    print(f"=== 分散稽古の構造対策 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"イベント込み正典(決勝{C.GP_FINAL_LINE:.0f}) | 全て【仮】 ===")
    print("目標: 分散稽古型(=正解プレイ)の優勝率を数%〜十数%へ。カジュアル帯(バランス/のんびり)の決勝到達は残す")
    print()
    saved_costs = {k: B.TRAININGS[k]["cost"] for k in PAID}
    saved_on = C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        print("== 基準（現行仕様） ==")
        measure(n, bots)
        print()

        print("== P1 稽古の有料化（ネタ作り/ネタ合わせ2万・フリーライブ3万） ==")
        for k, v in PAID.items():
            B.TRAININGS[k]["cost"] = v
        measure(n, bots)
        for k, v in saved_costs.items():
            B.TRAININGS[k]["cost"] = v
        print()

        print("== P2 逓減の総合値化（×(1−実力値/120)） ==")
        B.GROWTH_DECAY_TOTAL = True
        measure(n, bots)
        B.GROWTH_DECAY_TOTAL = False
        print()

        print("== P1+P2 複合 ==")
        for k, v in PAID.items():
            B.TRAININGS[k]["cost"] = v
        B.GROWTH_DECAY_TOTAL = True
        measure(n, bots)
    finally:
        for k, v in saved_costs.items():
            B.TRAININGS[k]["cost"] = v
        B.GROWTH_DECAY_TOTAL = False
        C.EVENTS_ON = saved_on

if __name__ == "__main__":
    main()
