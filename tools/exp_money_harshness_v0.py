#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""お金のきつさ代案の実測（2026-10-16・コード/式は変更しない・仮の値はこの中だけ）。
使い方: python3 exp_money_harshness_v0.py [n=1000]
代案(今=L: バイト/オファー×0.8・生活費14万): L / 生活費13万 / 生活費12万 / バイト×0.9＋14万 / バイト×1.0＋14万 / 14万のまま借金中(支払い時にマイナス)だけ半額。
ボット: 人間らしい(反応しない)・人間らしい(初マイナスでバイト週2)・のんびり改・ローテ・必要充足・やり込み。"""
import sys, importlib.util, statistics
src = open(__file__.rsplit("/", 1)[0] + "/sim_career.py", encoding="utf-8").read()
OLD = "s.money -= B.LIVING_COST\n"
assert src.count(OLD) == 1
src = src.replace(OLD, "s.money -= (B.LIVING_COST // 2 if (HALF_DEBT and s.money < 0) else B.LIVING_COST)\n")
src += "\nHALF_DEBT = False\n"
spec = importlib.util.spec_from_loader("sim_career", loader=None)
_m = importlib.util.module_from_spec(spec); _m.__file__ = "sim_career.py"
sys.modules["sim_career"] = _m; exec(compile(src, "sim_career.py", "exec"), _m.__dict__)
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
from exp_balance_snapshot_v0 import install, make2
from exp_debt_warning_v0 import Warn, HUMAN

# (名前, バイト/オファーの今(=L)に対する倍率, 生活費, 借金中半額)
VARS = [("L(今)", 1.0, 140_000, False), ("生活費13万", 1.0, 130_000, False), ("生活費12万", 1.0, 120_000, False),
        ("バイト×0.9+14万", 0.9 / 0.8, 140_000, False), ("バイト×1.0+14万", 1.0 / 0.8, 140_000, False),
        ("14万・借金中だけ半額", 1.0, 140_000, True)]
BOTS = [("人間らしい(反応しない)", HUMAN, None), ("人間らしい(初マイナスでバイト週2)", HUMAN, "j2"),
        ("のんびり改", "PCasual2", None), ("ローテ", "PRotate", None), ("必要充足", "PNeedV3", None), ("やり込み", "金→力 全振り(やり込み改)", None)]

def one(args):
    neta, vi, bi, n = args
    install(neta)
    _, f, lc, half = VARS[vi]
    B.JOBS.update({k: (int(v[0] * f), v[1]) for k, v in B.JOBS.items()})
    B.OFFER_MONEY["income"] = int(B.OFFER_MONEY["income"] * f); B.OFFER_EXP["income"] = int(B.OFFER_EXP["income"] * f)
    B.LIVING_COST = lc; C.HALF_DEBT = half
    cnt = dict(job=0, all=0)
    oj, ot, orr, oo = B.do_job, B.do_training, B.do_rest, B.do_offer
    def dj(s, nm): cnt["job"] += 1; cnt["all"] += 1; return oj(s, nm)
    def dt(s, nm): r = ot(s, nm); cnt["all"] += 1; return r
    def dr(s, nm): cnt["all"] += 1; return orr(s, nm)
    def do_(s, o): cnt["all"] += 1; return oo(s, o)
    B.do_job, B.do_training, B.do_rest, B.do_offer = dj, dt, dr, do_
    _, base, kind = BOTS[bi]; recs = []
    for i in range(n):
        pol = Warn(make2(base), kind, 0 if kind else None)
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
        d = s.__dict__
        recs.append(dict(bk=bool(d.get("_bankrupt")), win=first is not None, fin=bool(ever), m10=(ml[9][0] if ml[9] else None)))
    return neta, vi, bi, recs, cnt["job"] / max(1, cnt["all"])

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(ne, vi, bi, n) for ne in (False, True) for vi in range(len(VARS)) for bi in range(len(BOTS))]
    with Pool(10, maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)  # 毎ジョブ新プロセス(JOBS等の二重スケール防止)
    P = lambda x, k: f"{100*x/k:.1f}"
    print(f"n={n} 10年目所持金=10年目まで残った人の中央値(万)")
    print("NETA|案|ボット|夜逃げ%|バイト週%|10年目所持金(万)|決勝%|優勝%")
    for ne, vi, bi, R_, jw in res:
        k = len(R_); m10 = [r["m10"] / 10000 for r in R_ if r["m10"] is not None]
        print(f"{'込み' if ne else 'なし'}|{VARS[vi][0]}|{BOTS[bi][0]}|{P(sum(r['bk'] for r in R_),k)}|{100*jw:.0f}|"
              f"{format(statistics.median(m10),'.0f') if m10 else '-'}|{P(sum(r['fin'] for r in R_),k)}|{P(sum(r['win'] for r in R_),k)}", flush=True)

if __name__ == "__main__": main()
