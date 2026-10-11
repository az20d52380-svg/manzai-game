#!/usr/bin/env python3
"""王者編（連覇あり・2026-10-11復活）の実測：初優勝後も結成10年まで続けた時の連覇・優勝回数。
usage: python3 exp_dynasty_v2.py [n]。決定ではなく材料（docs/dynasty_v2_research_v0.md）。数値は全て【仮】。
変種: 予選から出直す／決勝シード（旧王者編）／決勝シード＋王者ライン+2×連覇（旧 dynasty_design）"""
import sys, collections
import balance_sim as B
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3

def career(pol, seed, mode, extend=None):
    """extend=(無冠で勇退する年数, 上限年): 初優勝した組だけ10年を超えて続ける（旧王者編の型）"""
    import random
    rng = random.Random(seed)
    s = C.new_state()
    prev, wins, streak, best, first = 0, 0, 0, 0, None
    last_win = None
    for year in range(1, (extend[1] if extend else C.YEARS) + 1):
        if extend and year > C.YEARS and (first is None or year - last_win > extend[0]):
            break
        champ = wins > 0 and streak > 0
        seed_final = mode != "予選から" and champ
        fl = C.GP_FINAL_LINE + (2.0 * streak if (mode == "シード+王者ライン" and champ) else 0)
        won, stage, fin = C.run_year(pol, s, year, rng, seed_final=seed_final, final_line=fl, gp_seed=(prev >= 3))
        prev = 5 if won else stage
        if getattr(s, "_bankrupt", False):
            break
        if won:
            wins += 1; streak += 1; best = max(best, streak)
            first = first or year
            last_win = year
        else:
            streak = 0
    return first, wins, best

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    V.apply()
    try:
        for mode in ("予選から", "決勝シード", "シード+王者ライン"):
            pol = PNeedV3(); firsts = 0; tw = collections.Counter(); bs = collections.Counter()
            for i in range(n):
                f, w, b = career(pol, C.BASE_SEED + i, mode)
                firsts += f is not None; tw[w] += 1; bs[b] += 1
            champs = max(firsts, 1)
            multi = sum(v for k, v in tw.items() if k >= 2)
            print(f"{mode:<10} 初優勝 {100*firsts/n:.1f}% | 優勝者のうち 2回以上 {100*multi/champs:.0f}% "
                  f"連覇(2連以上) {100*sum(v for k,v in bs.items() if k>=2)/champs:.0f}% 最長連覇の分布 {dict(sorted(bs.items()))}", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
