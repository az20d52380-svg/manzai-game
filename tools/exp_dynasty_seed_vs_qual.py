#!/usr/bin/env python3
"""王者編：なぜ「予選から」が「決勝シード」より優勝回数が多いか（docs/dynasty_v2_research_v0.md §6）。
usage: python3 exp_dynasty_seed_vs_qual.py [n]。10年＋王者だけ延長(3,25)・今の式(v3経済)。決定ではなく材料。数値は全て【仮】。
各組の「初優勝の翌年以降」だけを、モード別に年単位で集計（同じ乱数の初優勝まではモード間で同一）。"""
import sys, random
import sim_career as C
import canon_v2 as V
import balance_sim as B
from bots_v3 import PNeedV3

def run(mode, n, bonus=0.0, extend=(3, 25)):
    pol = PNeedV3(); yrs = wins = 0; fame0 = []; ab = []; champs = tw = 0; trainwk = []
    for i in range(n):
        rng = random.Random(C.BASE_SEED + i); s = C.new_state()
        wn, streak, first, last = 0, 0, None, None; prev = 0
        for year in range(1, extend[1] + 1):
            if year > C.YEARS and (first is None or year - last > extend[0]):
                break
            champ = wn > 0 and streak > 0
            sf = mode != "qual" and champ
            if mode == "seed_fame" and champ:
                B.add(s, "fame", 15)          # 予選5回戦ぶんの知名度(3×5)を先渡し
            if first is not None:
                fame0.append(s.fame); ab.append(sum(getattr(s, k) for k in ("sense", "idea", "expr", "chara")))
            won, stage, fin = C.run_year(pol, s, year, rng, seed_final=sf, gp_seed=(prev >= 3))
            prev = 5 if won else stage
            if getattr(s, "_bankrupt", False): break
            if first is not None:
                yrs += 1; wins += won
            if won:
                wn += 1; streak += 1; first = first or year; last = year
            else:
                streak = 0
        if first: champs += 1; tw += wn
    m = lambda a: sum(a) / max(len(a), 1)
    print(f"{mode:<10} 王者{champs}組 平均優勝{tw/max(champs,1):.2f} | 初優勝後の年数{yrs} 年あたり優勝率{100*wins/max(yrs,1):.1f}% "
          f"年初知名度{m(fame0):.1f} 4能力計{m(ab):.0f}", flush=True)

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    try:
        for mode in ("qual", "seed", "seed_fame"):
            run(mode, n)
    finally:
        V.reset()
