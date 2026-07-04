#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 王者編マトリクス（docs/dynasty_design_v0.md §2 の表の再現機）
- トロフィー累計pt（=逓減D）× 相方ティア × 2ボットの10連覇率を、イベント込み正典条件で測る
- 王者ライン = C.GP_FINAL_LINE + 5×現連覇数（採用STEP=5・詳細は exp_renpa.py）
- 使い方: python3 exp_dynasty_matrix.py [キャリア数/設定]   （省略時 1000）
- 数値は全て【仮】
"""

import random
import sys

import balance_sim as B
import sim_career as C
import exp_renpa as R

STEP = 5
GRID = ((0, 120), (10, 130), (20, 140), (30, 150))   # (トロフィーpt, D)
TIERS = [
    ("N相方(5→20)",    dict(COMPAT_CAP=20), dict(compat_start=5,  init_ability=20)),
    ("SSR相方(20→30)", dict(COMPAT_CAP=30), dict(compat_start=20, init_ability=20)),
]

def run_dynasty_ev(pol, seed, kwargs):
    """exp_renpa.run_dynasty のイベント込み版（キャリア内1回制を自前で張る）"""
    rng = random.Random(seed)
    s = C.new_state(kwargs.get("init_ability"), kwargs.get("compat_start"))
    C.RUN_EVENTS_FIRED = set()
    streak = titles = max_streak = dry = 0
    for year in range(1, R.MAX_YEARS + 1):
        defending = streak > 0
        line = C.GP_FINAL_LINE + STEP * streak if defending else None
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
                if dry >= R.RETIRE_AFTER:
                    break
    return max_streak

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    saved = dict(GROWTH_DECAY_D=B.GROWTH_DECAY_D, COMPAT_CAP=B.COMPAT_CAP)
    C.EVENTS_ON = True
    try:
        print(f"=== 王者編マトリクス | 基準{C.GP_FINAL_LINE:.0f}+{STEP}×連覇 | イベント込み正典 | "
              f"{n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
        for pt, d in GRID:
            B.GROWTH_DECAY_D = d
            row = [f"{pt}pt(D{d})"]
            for tier_name, overrides, kwargs in TIERS:
                for k, v in overrides.items():
                    setattr(B, k, v)
                rates = []
                for cls in C.BOTS:
                    pol = cls()
                    ten = sum(1 for i in range(n) if run_dynasty_ev(pol, C.BASE_SEED + i, kwargs) >= 10)
                    rates.append(100.0 * ten / n)
                row.append(f"{tier_name}: 10連覇 {min(rates):.1f}〜{max(rates):.1f}%")
                B.COMPAT_CAP = saved["COMPAT_CAP"]
            print(" | ".join(row), flush=True)
    finally:
        C.EVENTS_ON = False
        C.RUN_EVENTS_FIRED = None
        for k, v in saved.items():
            setattr(B, k, v)

if __name__ == "__main__":
    main()
