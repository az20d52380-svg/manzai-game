#!/usr/bin/env python3
"""L35 続き：ネタを磨かないボットへの係数倍の効き（研究用・コード不変）。
usage: python3 exp_neta_coef_nopolish_1026.py n [mults=0,0.5,1,2]
磨かない＝base ボットと稽古選択は同じ・ネタの完成度だけ稽古で上がらない（comp 凍結）。
"""
import sys
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import exp_money_after_merge_v0 as M
import exp_balance_snapshot_v0 as S
import measure_band_reference_v1 as MB

# 「磨かない」＝ボットの稽古選択は base と同じ（能力は同じだけ伸びる）。ただしネタの完成度(comp)は稽古で上がらない
# （ネタ作り/書く系/ネタ見せ会/フリーライブの完成度加算を打ち消す）。ネタは最初に2本できるだけ・buzz(反応)は通常どおり動く。
NEW = {"磨かない(ローテ)": "PRotate", "磨かない(必要充足)": "PNeedV3", "磨かない(のんびり改)": "PCasual2"}
LBL = {"PCasual2": "のんびり改", "PRotate": "ローテ", "PNeedV3": "必要充足"}
BASE_C, BASE_B = C.NETA_COEF_COMP, C.V2_COEF_BUZZ

def one(a):
    name, n, mult = a
    C.NETA_COEF_COMP = BASE_C * mult; C.V2_COEF_BUZZ = BASE_B * mult
    orig_make2 = S.make2
    comps = []
    freeze = name in NEW
    def mk(nm): return orig_make2(NEW.get(nm, nm))
    orig_ot = C._neta_on_train
    def ot(s, arg):
        before = [x["comp"] for x in s.netas]; k = len(before)
        orig_ot(s, arg)
        if freeze:
            for x, c in zip(s.netas[:k], before): x["comp"] = c
    if freeze: C._neta_on_train = ot
    orig_ry = C.run_year
    def ry(pol, s, year, rng, **kw):
        r = orig_ry(pol, s, year, rng, **kw)
        ns = getattr(s, "netas", None) or []
        if ns: comps.append(sum(q["comp"] for q in ns) / len(ns))
        return r
    S.make2, C.run_year = mk, ry
    try:
        r = MB.one((True, True, name, n))[3]
    finally:
        S.make2, C.run_year, C._neta_on_train = orig_make2, orig_ry, orig_ot
        C.NETA_COEF_COMP, C.V2_COEF_BUZZ = BASE_C, BASE_B
    r["comp"] = sum(comps) / len(comps) if comps else float("nan")
    return a, r

if __name__ == "__main__":
    n = int(sys.argv[1]); mults = [float(x) for x in (sys.argv[2] if len(sys.argv) > 2 else "0,0.5,1,2").split(",")]
    names = ["PCasual2", "PRotate", "PNeedV3"] + list(NEW)
    jobs = [(b, n, m) for b in names for m in mults]
    with Pool(maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)
    print(f"# n={n} EVENTS_APP=True NETA_ON/V2=True base comp={BASE_C} buzz={BASE_B}")
    print("ボット|係数倍|決勝%|優勝%|持ちネタ平均完成度(年末×全年)|1年目決勝%")
    for (b, n_, m), r in res:
        print(f"{LBL.get(b, b)}|{m:g}|{r['fin']:.1f}|{r['win']:.1f}|{r['comp']:.1f}|{r['y1fin']:.1f}", flush=True)
