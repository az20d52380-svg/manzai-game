#!/usr/bin/env python3
"""dynasty_v2_research §5 の選択肢 (A)(B) を §5 と同じ設定で実測（決定ではなく材料・数値は全て【仮】）。
usage: python3 exp_meta_curve_v3_opts.py [n]
- 現状: J0 を成長予算に上乗せ（全年）＋E0
- (A) J0 は10年目まで：11年目の頭に s._yg += J0（延長年は上乗せ分を取り上げる＝使い切っていれば延長年の伸びは基準カーブが追いつくまで0）
- (B) E0 だけ（予算の上乗せ J0 なし）
トロフィー上限カーブ（+0.02·T）は3案とも同じ。予選から・王者だけ延長（無冠3年で勇退・上限25年）。s._yg 操作は乱数を消費しない。"""
import sys, statistics, random
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import E0_SPLIT

def career(pol, seed, J0, opt, extend=(3, 25)):
    rng = random.Random(seed)
    s = C.new_state()
    if opt != "B":
        s._yg = -J0
    for k, r in E0_SPLIT.items():
        setattr(s, k, getattr(s, k) + 8 * J0 * r)
    prev, wins, streak, best, first, last_win, ext_w = 0, 0, 0, 0, None, None, 0
    for year in range(1, extend[1] + 1):
        if year > C.YEARS and (first is None or year - last_win > extend[0]):
            break
        if opt == "A" and year == C.YEARS + 1:
            s._yg = getattr(s, "_yg", 0.0) + J0
        won, stage, fin = C.run_year(pol, s, year, rng, seed_final=False, gp_seed=(prev >= 3))
        prev = 5 if won else stage
        if getattr(s, "_bankrupt", False):
            break
        if won:
            wins += 1; streak += 1; best = max(best, streak); first = first or year; last_win = year
            if year > C.YEARS: ext_w += 1
        else:
            streak = 0
    return first, wins, best, ext_w

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    ms = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else (0.5, 0.67, 0.83, 1.0)
    V.apply()
    base_curve = C.CAP_CURVE
    try:
        for m in ms:
            J0 = 44 * m ** 2.6
            C.CAP_CURVE = (base_curve[0] + 0.02 * 30 * m, base_curve[1], base_curve[2])
            for opt in ("現状", "A", "B"):
                pol = PNeedV3(); res = [career(pol, C.BASE_SEED + i, J0, opt) for i in range(n)]
                fy = [r[0] for r in res if r[0]]
                ch = max(len(fy), 1)
                in10 = sum(1 for f in fy if f <= C.YEARS)
                med = statistics.median(fy) if fy else "-"
                aw = sum(r[1] for r in res if r[0]) / ch
                ew = sum(r[3] for r in res if r[0]) / ch
                c3 = sum(1 for r in res if r[2] >= 3) / ch
                print(f"m={m:.2f} J0={J0:4.1f} {opt:<3} 10年内 {100*in10/n:5.1f}% 中央値 {med} | 王者の平均優勝 {aw:.2f}（うち延長年 {ew:.2f}） 3連覇+ {100*c3:.0f}%", flush=True)
    finally:
        C.CAP_CURVE = base_curve
        V.reset()

if __name__ == "__main__":
    main()
