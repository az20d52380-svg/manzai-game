#!/usr/bin/env python3
"""dynasty_v2_research §10 (iii)「相性は1年目だけ（翌年に戻す）」を実測。決定ではない・数値は全て【仮】。
usage: python3 exp_year1_compat_once.py [n] [頂点の相性 c,...]
exp_year1_compat_curve と同じ設定で、相性 +c·m を1年目の頭に足し、1年目の終わりに同じ量を引く（1年目に稽古で伸びた分は残す）。
式・GameCore は触らない。"""
import sys, random, statistics
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import E0_SPLIT

def career(seed, m, compat_add, once):
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
        if once and year == 1:
            s.compat -= compat_add
    return first, wins

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    cs = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else [5, 10]
    V.apply()
    try:
        for m in (0.75, 1.0):
            for c in cs:
                for once in (False, True):
                    res = [career(C.BASE_SEED + i, m, c * m, once) for i in range(n)]
                    fy = [f for f, w in res if f]
                    y1 = sum(1 for f in fy if f == 1)
                    med = statistics.median(fy) if fy else "-"
                    tag = "1年目だけ" if once else "ずっと"
                    print(f"m={m:<4} 相性+{c*m:4.1f} {tag:5} 1年目優勝 {100*y1/n:5.1f}% 10年内 {100*len(fy)/n:5.1f}% 中央値 {med} 優勝回数 {statistics.mean(w for f, w in res):.2f}", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
