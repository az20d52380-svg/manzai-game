#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
裏天井（初回の保証弁）測定台 v0 — sim_scaffold_spec_v0.md T4
- 「決勝に一度も立てない年が続いたら、晩年のハマ率(BURST_P)を持ち上げて救済」の効果を測る台。
- 骨だけ提供（PITY_DRY_TH/PITY_BURST_P は【仮】・最終の効果式はオーナー＋Fable較正）。
- balance_sim/sim_career の本体は編集しない（B.BURST_P を各年の直前に一時上書き→finallyで復元）。
  ＝ run_year/gen_golden/golden に非干渉（experiment-only）。
- 数値は全て【仮】。使い方: python3 exp_pity.py [キャリア数=500]
"""
import random
import sys

import balance_sim as B
import sim_career as C
from exp_human import PCasual2
from exp_human_fix import PSpread

# --- 裏天井パラメータ（全て【仮】・骨のみ） ---
PITY_DRY_TH   = 3      # 無決勝がこの年数続いたら発動
PITY_BURST_P  = 0.30   # 発動中のハマ率（既定0.10→0.30）
BASE_BURST_P  = B.BURST_P


def run_career_pity(pol, seed, pity_on):
    """run_career を模倣しつつ、無決勝連続年で BURST_P を持ち上げる。
    戻り: (初優勝年 or None, 決勝経験, 発動年数)"""
    rng = random.Random(seed)
    s = C.new_state()
    best_stage = 0
    ever_final = False
    prev_stage = 0
    dry = 0            # 無決勝連続年数
    pity_years = 0
    for year in range(1, C.YEARS + 1):
        # --- 年の直前に BURST_P を決める ---
        if pity_on and dry >= PITY_DRY_TH:
            B.BURST_P = PITY_BURST_P
            pity_years += 1
        else:
            B.BURST_P = BASE_BURST_P
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        best_stage = max(best_stage, stage)
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1
        if getattr(s, "_bankrupt", False):
            break
        if won:
            return year, ever_final, pity_years
    return None, ever_final, pity_years


def scan(pol_cls, n, pity_on):
    pol = pol_cls()
    wins = finals = 0
    win_years = []
    pity_total = 0
    for i in range(n):
        first, ever_final, py = run_career_pity(pol, C.BASE_SEED + i, pity_on)
        if first is not None:
            wins += 1
            win_years.append(first)
        finals += ever_final
        pity_total += py
    import statistics
    med = statistics.median(win_years) if win_years else "-"
    return dict(win=100.0*wins/n, final=100.0*finals/n, med=med, pity=pity_total/n)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    try:
        print(f"=== 裏天井 測定台 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
              f"発動閾値{PITY_DRY_TH}年・発動ハマ{PITY_BURST_P:.0%}(既定{BASE_BURST_P:.0%}) | 全て【仮】 ===")
        print("狙い: 決勝を一度も見ずに終わる率を下げつつ、優勝率帯(canonical §2)を壊さない\n")
        for cls in (PSpread, C.CareerBalanced, PCasual2):
            off = scan(cls, n, pity_on=False)
            on  = scan(cls, n, pity_on=True)
            name = cls().name if hasattr(cls(), "name") else cls.__name__
            print(f"[{name}]")
            print(f"  OFF: 優勝 {off['win']:5.2f}% / 決勝到達 {off['final']:5.1f}% / 優勝中央値{off['med']}年")
            print(f"  ON : 優勝 {on['win']:5.2f}% / 決勝到達 {on['final']:5.1f}% / 優勝中央値{on['med']}年"
                  f"  (平均発動{on['pity']:.2f}年)")
            print(f"   Δ決勝到達 {on['final']-off['final']:+.1f}pt / Δ優勝 {on['win']-off['win']:+.2f}pt\n")
    finally:
        B.BURST_P = BASE_BURST_P   # 必ず復元（他への波及防止）


if __name__ == "__main__":
    main()
