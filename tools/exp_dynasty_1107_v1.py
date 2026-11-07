#!/usr/bin/env python3
"""段差の原因分解と平滑案の実測（2026-11-07・測るだけ・数値は【仮】）。exp_dynasty_1107_v0 の job/stats を使い、C.META_* をこのスクリプト内で上書きする（正典は触らない）。
usage: python3 exp_dynasty_1107_v1.py n variants Ps bots [out.json]
  variants: カンマ区切り名（VARS 参照）／Ps: カンマ区切り／bots: 0-3 のカンマ区切り（0のんびり 1ローテ 2必要充足 3やり込み）"""
import sys, json
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import exp_dynasty_1107_v0 as D
import exp_calib_all_1101_v0 as E

# 上書き。base は正典のまま。bundle(A,E,X)= 予算上乗せ・初期経験点の頂点・指数
VARS = {
 "base": {},
 "noBudget": dict(META_BUDGET_TOP=0.0),
 "noExpTop": dict(META_START_EXP_TOP=0.0),
 "noBundle": dict(META_BUDGET_TOP=0.0, META_START_EXP_TOP=0.0),
 "noCompat": dict(META_START_COMPAT_COEF=0.0),
 "noType1": dict(META_START_EXP_PER_POINT=0.0, META_START_MONEY_PER_POINT=0.0),
 "noLift": dict(META_CAP_LIFT_COEF=0.0),
 "e10": dict(META_TOP_EXP=10.0),
 "e12": dict(META_TOP_EXP=12.0),
 "e16": dict(META_TOP_EXP=16.0),
 "e16x": dict(META_TOP_EXP=16.0, META_BUDGET_TOP=44.0, META_START_EXP_TOP=420.0),
 "e12x": dict(META_TOP_EXP=12.0, META_BUDGET_TOP=40.0, META_START_EXP_TOP=340.0),
 "e5": dict(META_TOP_EXP=5.0, META_BUDGET_TOP=30.0, META_START_EXP_TOP=250.0),
 "e5b": dict(META_TOP_EXP=5.0, META_BUDGET_TOP=24.0, META_START_EXP_TOP=200.0),
 "e5c": dict(META_TOP_EXP=5.0, META_BUDGET_TOP=36.0, META_START_EXP_TOP=300.0),
}

def job(a):
    name, P, bi, seeds = a
    for k, v in VARS[name].items(): setattr(C, k, v)
    key, out = D.job((P, bi, seeds))
    return (name, P, bi), out

def main():
    n = int(sys.argv[1]); vs = sys.argv[2].split(","); Ps = [int(x) for x in sys.argv[3].split(",")]
    bots = [int(x) for x in sys.argv[4].split(",")]; outp = sys.argv[5] if len(sys.argv) > 5 else None
    chunk = 25
    jobs = [(v, P, bi, list(range(i, min(i + chunk, n)))) for v in vs for P in Ps for bi in bots for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    for key in sorted(res):
        v, P, bi = key; r = D.stats(res[key]); final[f"{v}|{P}|{E.SHORT[bi]}"] = r
        print(f"{v}|P{P}|{E.SHORT[bi]}|n={r['n']}|win={r['win']:.1f}|y1={r['y1']:.1f}|wins={r['wins']:.2f}|best={r['best']:.2f}/{r['bmax']}|s15={r['s15']:.1f}|ds={r['ds']:.1f}", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
