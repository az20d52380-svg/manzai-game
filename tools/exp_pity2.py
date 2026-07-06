#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
裏天井 効果式の較正スキャン v0 — exp_pity.py の変種台（Fableセッション Q1）
- 分離レバーを測る: 一律ハマ率up(A) / 初到達まで限定(B) / B＋決勝の本番だけ素のハマ率(C)
- 本体(sim_career/balance_sim/gen_golden)は一切編集しない。B.BURST_P の一時上書きと
  C._gp_perform の実行時ラップのみ（finallyで完全復元）＝experiment-only・golden非干渉。
- 数値は全て【仮】。使い方:
    python3 exp_pity2.py N TH BP MODE [YEAR_FLOOR]
    例: python3 exp_pity2.py 1000 3 0.30 C 0
  MODE: A=毎回発動(baseline同等・再発動あり) / B=初到達までに限定(一度決勝を見たら以後発動なし)
        C=Bに加えて「決勝の本番だけ素のハマ率」(準決以下にだけ効く)
  YEAR_FLOOR: この年以降のみ発動(0=制限なし)
"""
import random
import statistics
import sys

import balance_sim as B
import sim_career as C
from exp_human import PCasual2
from exp_human_fix import PSpread

BASE_BURST_P = B.BURST_P
_ORIG_GP = C._gp_perform


def _gp_final_at_base(s, line, rng, final):
    """決勝の本番だけ BURST_P を素に戻すラッパ（MODE=C・実行時のみ・本体無編集）"""
    if final and B.BURST_P != BASE_BURST_P:
        saved = B.BURST_P
        B.BURST_P = BASE_BURST_P
        try:
            return _ORIG_GP(s, line, rng, final)
        finally:
            B.BURST_P = saved
    return _ORIG_GP(s, line, rng, final)


def run_career_pity(pol, seed, th, bp, mode, floor):
    rng = random.Random(seed)
    s = C.new_state()
    prev_stage = 0
    dry = 0                # 無決勝連続年数
    ever_final = False
    pity_years = 0
    first_final = None
    for year in range(1, C.YEARS + 1):
        active = (dry >= th) and (year >= floor) and (mode == "A" or not ever_final)
        B.BURST_P = bp if active else BASE_BURST_P
        if active:
            pity_years += 1
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        if finalist and first_final is None:
            first_final = year
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1
        if getattr(s, "_bankrupt", False):
            break
        if won:
            return year, ever_final, pity_years, first_final
    return None, ever_final, pity_years, first_final


def scan(pol_cls, n, th, bp, mode, floor):
    pol = pol_cls()
    wins = finals = 0
    win_years, ff_years = [], []
    pity_total = 0
    for i in range(n):
        first, ever, py, ff = run_career_pity(pol, C.BASE_SEED + i, th, bp, mode, floor)
        if first is not None:
            wins += 1
            win_years.append(first)
        finals += ever
        pity_total += py
        if ff is not None:
            ff_years.append(ff)
    ffmed = statistics.median(ff_years) if ff_years else "-"
    return dict(win=100.0 * wins / n, final=100.0 * finals / n,
                pity=pity_total / n, ffmed=ffmed)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    th = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    bp = float(sys.argv[3]) if len(sys.argv) > 3 else 0.30
    mode = (sys.argv[4] if len(sys.argv) > 4 else "C").upper()
    floor = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    if mode == "C":
        C._gp_perform = _gp_final_at_base
    try:
        print(f"=== 裏天井スキャン | n={n}/設定 | TH={th} BP={bp:.2f} MODE={mode} FLOOR={floor} "
              f"| シード{C.BASE_SEED} | 全て【仮】 ===")
        for cls in (PSpread, C.CareerBalanced, PCasual2):
            r = scan(cls, n, th, bp, mode, floor)
            name = getattr(cls(), "name", cls.__name__)
            print(f"  {name:　<6}| 優勝 {r['win']:5.2f}% / 決勝到達 {r['final']:5.1f}% "
                  f"/ 平均発動{r['pity']:.2f}年 / 初到達中央値{r['ffmed']}年", flush=True)
    finally:
        B.BURST_P = BASE_BURST_P
        C._gp_perform = _ORIG_GP


if __name__ == "__main__":
    main()
