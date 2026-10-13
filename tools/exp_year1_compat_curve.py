#!/usr/bin/env python3
"""dynasty_v2_research §9 ③「周回ボーナスに相性を入れる」を周回の途中（m=0.25〜1）でも実測。決定ではない・数値は全て【仮】。
usage: python3 exp_year1_compat_curve.py [n] [頂点の相性 c,...]
J0 = 44·m^2.6・E0 = 8·J0（exp_year1_levers と同じ）に、相性 +c·m を足す。1年目優勝・10年内・初優勝中央値・10年の優勝回数を見る。
式・GameCore は触らない。"""
import sys, random, statistics
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import E0_SPLIT

def career(seed, m, compat_add):
    j0 = 44.0 * m ** 2.6
    rng = random.Random(seed)
    s = C.new_state()
    s._yg = -j0
    for k, r in E0_SPLIT.items():
        setattr(s, k, getattr(s, k) + 8 * j0 * r)
    s.compat += compat_add
    pol = PNeedV3(); first = None; wins = 0
    for year in range(1, 11):
        won, stage, fin = C.run_year(pol, s, year, rng, gp_seed=False)
        if getattr(s, "_bankrupt", False): break
        if won:
            wins += 1
            if first is None: first = year
    return first, wins

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    cs = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else [0, 5, 10]
    V.apply()
    try:
        for m in (0.25, 0.5, 0.75, 1.0):
            for c in cs:
                res = [career(C.BASE_SEED + i, m, c * m) for i in range(n)]
                fy = [f for f, w in res if f]
                y1 = sum(1 for f in fy if f == 1)
                med = statistics.median(fy) if fy else "-"
                print(f"m={m:<4} 相性+{c*m:4.1f} 1年目優勝 {100*y1/n:5.1f}% 10年内 {100*len(fy)/n:5.1f}% 中央値 {med} 優勝回数 {statistics.mean(w for f, w in res):.2f}", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
