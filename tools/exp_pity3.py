#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
裏天井 × 周回進行（トロフィー/相方）の3段階スキャン — オーナー質問用
- 「35%/58%はトロフィー0(初プレイ)の値。集めるとどう変わる？」への回答。
- 実験のみ: canon_v2.apply(trophy)/B.COMPAT_CAP/B.BURST_P/C._gp_perform を一時操作しfinallyで完全復元。
  sim_career/gen_golden 本体は未編集＝golden非干渉。数値は全て【仮】。
- 裏天井は確定式(MODE C・TH3・FLOOR8・BP0.30・初到達で恒久解除)。
- 使い方: python3 exp_pity3.py [N=600]
"""
import random
import sys

import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread

BASE_BURST_P = B.BURST_P
_ORIG_GP = C._gp_perform
TH, BP, FLOOR = 3, 0.30, 8   # 確定式


def _gp_final_at_base(s, line, rng, final):
    if final and B.BURST_P != BASE_BURST_P:
        saved = B.BURST_P; B.BURST_P = BASE_BURST_P
        try: return _ORIG_GP(s, line, rng, final)
        finally: B.BURST_P = saved
    return _ORIG_GP(s, line, rng, final)


def run_one(pol, seed, pity_on, init_ability, compat):
    rng = random.Random(seed)
    s = C.new_state(init_ability, compat)
    # run_career と同じ per-career グローバル初期化（これが無いとイベント状態が漏れて汚染する）
    if C.EVENTS_ON:
        C.RUN_EVENTS_FIRED = set()
    if C.BOREDOM_ON:
        C.RUN_BOREDOM = {}
    prev_stage = 0; dry = 0; ever_final = False
    for year in range(1, C.YEARS + 1):
        active = pity_on and (dry >= TH) and (year >= FLOOR) and (not ever_final)
        B.BURST_P = BP if active else BASE_BURST_P
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1
        if getattr(s, "_bankrupt", False): break
        if won: return True, ever_final
    return False, ever_final


def scan(pol_cls, n, pity_on, trophy_pt, compat_cap, init_ability, compat_start):
    V.apply(trophy_pt=trophy_pt)
    B.COMPAT_CAP = compat_cap
    if pity_on:
        C._gp_perform = _gp_final_at_base
    try:
        pol = pol_cls(); wins = finals = 0
        for i in range(n):
            won, ever = run_one(pol, C.BASE_SEED + i, pity_on, init_ability, compat_start)
            wins += won; finals += ever
        return 100.0 * wins / n, 100.0 * finals / n
    finally:
        C._gp_perform = _ORIG_GP
        B.BURST_P = BASE_BURST_P


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    # (ラベル, trophy_pt, compat_cap, init_ability, compat_start)
    stages = [
        ("① 初プレイ (0pt・谷口N)",   0, 20, 10, 5),
        ("② 中盤 (15pt・SSR相方)",    15, 24, 20, 20),
        ("③ コンプ後 (30pt・SSR相方)", 30, 24, 20, 20),
    ]
    try:
        print(f"=== 裏天井×周回進行 | n={n}/設定 | 裏天井=確定式(TH3/FLOOR8/BP0.30/決勝除外/初到達解除) | 全て【仮】 ===")
        print(f"{'段階':<26}| プレイ型   | 決勝到達 OFF→ON  | 優勝 OFF→ON")
        print("-" * 92)
        for label, pt, cap, ia, cs in stages:
            for cls in (PCasual2, PSpread):
                w_off, f_off = scan(cls, n, False, pt, cap, ia, cs)
                w_on,  f_on  = scan(cls, n, True,  pt, cap, ia, cs)
                name = getattr(cls(), "name", cls.__name__)
                print(f"{label:<26}| {name:<8} | {f_off:5.1f}% → {f_on:5.1f}%   | {w_off:5.2f}% → {w_on:5.2f}%",
                      flush=True)
            print()
    finally:
        V.reset()
        B.COMPAT_CAP = 20
        B.BURST_P = BASE_BURST_P


if __name__ == "__main__":
    main()
