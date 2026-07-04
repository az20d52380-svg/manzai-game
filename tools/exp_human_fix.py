#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 「借金無罪×分散稽古」穴の修正候補（docs/human_calibration_v0.md の根拠データ）
- exp_human.py の発見: 逓減D=120下では無料稽古3種を回す分散育成が一点特化より圧倒的に強く、
  さらに借金にペナルティがないため金策が不要 → 稽古全振りが優勝100%・ランダムでも66%
- 修正候補（全て既定OFFのフラグ・goldenバイト一致を確認済み）:
    A 借金中は稽古が半分しか身にならない … balance_sim.DEBT_TRAIN_FACTOR = 0.5
    B 借金中は稽古が全く身にならない     … 同 = 0.0
    C 生活費が払えない月は生活苦         … sim_career.DEBT_LIFE_PEN = (体力-15, メンタル-5)
    A+C / B+C の複合
- 「真の最適」近似として分散稽古＋金管理の PSpread を新設し、修正後の実力上限も測る
- 使い方: python3 exp_human_fix.py [キャリア数/設定]   （省略時 1000）
- 数値は全て【仮】
"""

import statistics
import sys

import balance_sim as B
import sim_career as C
from exp_human import PCasual

class PSpread(B.Policy):
    """分散稽古型: 逓減仕様の「正解プレイ」近似。5能力の最低を無料/有料稽古で埋め、金は必要最小限だけ稼ぐ"""
    name = "分散稽古型"
    BUFFER = 150_000   # 生活費・遠征のための最低残高【仮】

    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)
        if s.money < self.BUFFER:
            return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "完全休養")
        cands = [("ネタ作り", s.idea), ("ネタ合わせ", s.sense), ("フリーライブ", s.chara)]
        if s.money >= 400_000:   # 有料稽古は余裕がある時だけ分散対象に加える
            cands += [("ネタ見せ会", s.expr), ("ランニング・サウナ", s.mental)]
        cands.sort(key=lambda x: x[1])
        return ("train", cands[0][0])

    def transport(self, s):
        return B.TRAIN if s.money >= 150_000 else B.BUS

FIXES = [
    ("基準（借金無罪・現行仕様）", None, None),
    ("A 借金中は稽古半減",         0.5,  None),
    ("B 借金中は稽古無効",         0.0,  None),
    ("C 生活苦（体力-15/メンタル-5）", None, (-15, -5)),
    ("A+C 複合",                   0.5,  (-15, -5)),
    ("B+C 複合",                   0.0,  (-15, -5)),
]
PROBE_BOTS = (B.PTrain, B.PRandom, PSpread, C.CareerBalanced, PCasual)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    print(f"=== 借金無罪×分散稽古の修正候補 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"イベント込み正典(決勝{C.GP_FINAL_LINE:.0f}) | 全て【仮】 ===")
    print("目標: 稽古全振り(踏み倒し)を大幅に下げ、金管理する分散稽古が『上手いプレイ』として残ること")
    print()
    saved_on = C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        for label, train_fac, life_pen in FIXES:
            B.DEBT_TRAIN_FACTOR = train_fac
            C.DEBT_LIFE_PEN = life_pen
            print(f"== {label} ==")
            for cls in PROBE_BOTS:
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
            print()
    finally:
        C.EVENTS_ON = saved_on
        B.DEBT_TRAIN_FACTOR = None
        C.DEBT_LIFE_PEN = None

if __name__ == "__main__":
    main()
