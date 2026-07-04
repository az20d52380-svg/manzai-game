#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
正典v2の周回メタ再スキャン（canonical_v2_spec.md チェックリスト2）
- (1) トロフィーpt × 相方ティア → 初優勝率の周回カーブ
- (2) 王者編: 王者ライン = 決勝80 + STEP×連覇数 の STEP スキャン（v2はスコアスケールが縮むためSTEPも縮む）
- 使い方: python3 exp_v2_meta.py [キャリア数/設定]   （省略時 500）
- 数値は全て【仮】
"""

import random
import statistics
import sys

import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread

MAX_YEARS = 25
RETIRE_AFTER = 3

TIERS = [
    ("N相方(5→20)",    20, dict(compat_start=5,  init_ability=20)),
    ("SSR相方(20→30)", 30, dict(compat_start=20, init_ability=20)),
]

def career_scan(n):
    print("== (1) トロフィーpt × 相方ティア → 10年内初優勝率 ==")
    for pt in (0, 6, 11, 20, 30):
        V.apply(trophy_pt=pt)
        row = [f"{pt:2d}pt"]
        for tier_name, ccap, kw in TIERS:
            B.COMPAT_CAP = ccap
            for cls in (PSpread, PCasual2):
                pol = cls()
                wins = 0
                years = []
                for i in range(n):
                    first, s, _st, _f = C.run_career(pol, C.BASE_SEED + i,
                                                     init_ability=kw["init_ability"], compat=kw["compat_start"])
                    if first is not None:
                        wins += 1
                        years.append(first)
                med = statistics.median(years) if years else "-"
                row.append(f"{tier_name}×{pol.name}: {100.0*wins/n:5.2f}%({med}年)")
            B.COMPAT_CAP = 20
        print("  " + " / ".join(row), flush=True)
    print()

def run_dynasty(pol, seed, step, kw):
    rng = random.Random(seed)
    s = C.new_state(kw["init_ability"], kw["compat_start"])
    C.RUN_EVENTS_FIRED = set()
    streak = titles = max_streak = dry = 0
    for year in range(1, MAX_YEARS + 1):
        defending = streak > 0
        line = C.GP_FINAL_LINE + step * streak if defending else None
        won, _, _ = C.run_year(pol, s, year, rng, seed_final=defending, final_line=line)
        if won:
            titles += 1
            streak += 1
            max_streak = max(max_streak, streak)
            dry = 0
        else:
            streak = 0
            if titles > 0:
                dry += 1
                if dry >= RETIRE_AFTER:
                    break
    return max_streak

def dynasty_scan(n):
    print("== (2) 王者編STEPスキャン（30pt全解放・王者ライン=80+STEP×連覇・25年） ==")
    V.apply(trophy_pt=30)
    for step in (1.0, 1.5, 2.0, 3.0):
        row = [f"STEP={step}"]
        for tier_name, ccap, kw in TIERS:
            B.COMPAT_CAP = ccap
            pol = PSpread()
            outs = [run_dynasty(pol, C.BASE_SEED + i, step, kw) for i in range(n)]
            ten = 100.0 * sum(1 for m in outs if m >= 10) / n
            med = statistics.median(outs)
            row.append(f"{tier_name}: 10連覇 {ten:5.1f}% / 最高連覇中央値 {med:.0f}")
            B.COMPAT_CAP = 20
        print("  " + " / ".join(row), flush=True)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    print(f"=== 正典v2 周回メタ | {n}キャリア/設定 | シード{C.BASE_SEED} | 決勝{V.GP_FINAL_LINE} | 全て【仮】 ===")
    print()
    try:
        career_scan(n)
        dynasty_scan(n)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
