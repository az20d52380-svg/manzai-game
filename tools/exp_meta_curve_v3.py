#!/usr/bin/env python3
"""周回曲線（b2 §5 の J0 = 44·m^2.6・E0 = 8·J0）を v3 計測ボットで実測（連覇あり＝10年＋王者だけ延長）。
usage: python3 exp_meta_curve_v3.py [n]。決定ではなく材料（docs/dynasty_v2_research_v0.md §5）。数値は全て【仮】。
J0 は成長予算の上乗せ（s._yg を −J0 から始める）・E0 は 5通貨に 35/27/18/10/10% で配る（b2 §5-1 の初期値）。
トロフィー→上限カーブは T = 30·m と見なし CAP_CURVE の基準に +0.02·T。式・GameCore は触らない（実験内で一時的に差し替え→戻す）。"""
import sys, random, statistics
import balance_sim as B
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3

E0_SPLIT = dict(exp_hirameki=.35, exp_maai=.27, exp_goi=.18, exp_sonzaikan=.10, exp_tanryoku=.10)

def career(pol, seed, J0, mode, extend=(3, 25)):
    rng = random.Random(seed)
    s = C.new_state()
    s._yg = -J0
    for k, r in E0_SPLIT.items():
        setattr(s, k, getattr(s, k) + 8 * J0 * r)
    prev, wins, streak, best, first, last_win = 0, 0, 0, 0, None, None
    for year in range(1, extend[1] + 1):
        if year > C.YEARS and (first is None or year - last_win > extend[0]):
            break
        champ = streak > 0
        won, stage, fin = C.run_year(pol, s, year, rng, seed_final=(mode == "決勝シード" and champ), gp_seed=(prev >= 3))
        prev = 5 if won else stage
        if getattr(s, "_bankrupt", False):
            break
        if won:
            wins += 1; streak += 1; best = max(best, streak); first = first or year; last_win = year
        else:
            streak = 0
    return first, wins, best

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    base_curve = C.CAP_CURVE
    try:
        for m in (0, 0.33, 0.5, 0.67, 0.83, 0.89, 0.93, 1.0):
            J0 = 44 * m ** 2.6
            C.CAP_CURVE = (base_curve[0] + 0.02 * 30 * m, base_curve[1], base_curve[2])
            for mode in ("予選から", "決勝シード"):
                pol = PNeedV3(); res = [career(pol, C.BASE_SEED + i, J0, mode) for i in range(n)]
                fy = [f for f, w, b in res if f]
                ch = max(len(fy), 1)
                in10 = sum(1 for f in fy if f <= C.YEARS)
                y1 = sum(1 for f in fy if f == 1)
                med = statistics.median(fy) if fy else "-"
                aw = sum(w for f, w, b in res if f) / ch
                c2 = sum(1 for f, w, b in res if b >= 2) / ch
                c3 = sum(1 for f, w, b in res if b >= 3) / ch
                mx = max((b for f, w, b in res), default=0)
                print(f"m={m:.2f} T≈{30*m:4.1f} J0={J0:4.1f} {mode:<6} 10年内 {100*in10/n:5.1f}% Y1 {100*y1/n:4.1f}% 初優勝年中央値 {med} "
                      f"| 王者の平均優勝 {aw:.2f} 2連覇+ {100*c2:.0f}% 3連覇+ {100*c3:.0f}% 最長 {mx}", flush=True)
    finally:
        C.CAP_CURVE = base_curve
        V.reset()

if __name__ == "__main__":
    main()
