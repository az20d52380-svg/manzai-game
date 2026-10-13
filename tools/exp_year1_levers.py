#!/usr/bin/env python3
"""1年目の壁（dynasty_v2_research §7）の材料①②③を周回の頂点（m=1・J0=44・E0=8·J0）で実測。決定ではない・数値は全て【仮】。
usage: python3 exp_year1_levers.py [n]
① 準決勝ライン 74→X ② 1年目の成長上限：CAP 基準の周回上乗せ +0.6 → +k ③ 初期の相性 +c（J0 の配分に相性を入れた代わり）
1年目だけ回し、準決勝通過・1年目優勝を数える。2〜10年目への波及（10年内・初優勝中央値）も同じ設定で10年回して見る。式・GameCore は触らない（実験内で差し替え→戻す）。"""
import sys, random, statistics
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import E0_SPLIT

J0 = 44.0

def career(seed, compat_add, years):
    rng = random.Random(seed)
    s = C.new_state()
    s._yg = -J0
    for k, r in E0_SPLIT.items():
        setattr(s, k, getattr(s, k) + 8 * J0 * r)
    s.compat += compat_add
    pol = PNeedV3(); first = None; semi1 = False
    for year in range(1, years + 1):
        won, stage, fin = C.run_year(pol, s, year, rng, gp_seed=False)
        if year == 1: semi1 = stage >= 5 or won
        if getattr(s, "_bankrupt", False): break
        if won and first is None: first = year
    return first, semi1

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    base_curve, base_rounds = C.CAP_CURVE, list(C.GP_ROUNDS)
    cases = [("今（m=1）", 74, 0.6, 0), ("①準決勝74→65", 65, 0.6, 0), ("①準決勝74→60", 60, 0.6, 0),
             ("②CAP +3", 74, 3.0, 0), ("②CAP +6", 74, 6.0, 0), ("③相性 +5", 74, 0.6, 5), ("③相性 +10", 74, 0.6, 10)]
    try:
        for lab, semi, capk, cadd in cases:
            C.GP_ROUNDS = [r if r[2] != "GP準決勝" else (r[0], semi, r[2]) for r in base_rounds]
            C.CAP_CURVE = (base_curve[0] + capk, base_curve[1], base_curve[2])
            res = [career(C.BASE_SEED + i, cadd, 10) for i in range(n)]
            y1 = sum(1 for f, s1 in res if f == 1); sp = sum(1 for f, s1 in res if s1)
            fy = [f for f, s1 in res if f]
            med = statistics.median(fy) if fy else "-"
            print(f"{lab:<12} 1年目 準決勝通過 {100*sp/n:5.1f}% 優勝 {100*y1/n:5.1f}% | 10年内 {100*len(fy)/n:5.1f}% 初優勝中央値 {med}", flush=True)
    finally:
        C.CAP_CURVE, C.GP_ROUNDS = base_curve, base_rounds
        V.reset()

if __name__ == "__main__":
    main()
