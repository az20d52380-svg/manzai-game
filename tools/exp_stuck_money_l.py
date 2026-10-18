#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
お金の調整後(815b443)の夜逃げ・借金の実測（2026-10-16）。コード・式は変更しない（実験の中だけで値を差し替える）。
使い方: python3 exp_stuck_money_l.py [n=1000] ／ 新設定(今)と旧設定(生活費10万・バイト/オファー×1.0)を同じボットで回す。
出力: 夜逃げ率・年別・最低所持金の分布・借金週の割合・-50万を割る率。NETA_ON=NETA_V2=True・正典v2・イベント込み。
"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import exp_stuck_v0 as X

OLD = dict(LIVING=100_000, JOBS={"キツい": (120_000, -30), "標準": (80_000, -20), "楽": (40_000, -10)}, OM=300_000, OE=150_000)
BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)",
        "無料稽古1週:バイト1週", "無料稽古3週:バイト1週", "無料稽古5週:バイト1週", "無料稽古8週:バイト1週",
        "無料稽古5週:バイト1週+借金したらバイト専念",
        "巡回:バイト標準→作家の勉強会→休養", "巡回:バイト標準→ネタ見せ会→休養", "ネタ見せ会だけ(有料8万)", "ネタ作りだけ", "バイト標準+オファー"]

def run(args):
    name, n, setting = args
    X.install()
    if setting == "old":
        B.LIVING_COST = OLD["LIVING"]; B.JOBS.clear(); B.JOBS.update(OLD["JOBS"])
        B.OFFER_MONEY["income"] = OLD["OM"]; B.OFFER_EXP["income"] = OLD["OE"]
    o_roll = B.roll_offer
    def roll(s, rng):
        d = s.__dict__
        d["_wk"] = d.get("_wk", 0) + 1
        if s.money < 0: d["_neg_wk"] = d.get("_neg_wk", 0) + 1
        if s.money < -500_000: d["_neg50_wk"] = d.get("_neg50_wk", 0) + 1
        return o_roll(s, rng)
    B.roll_offer = roll
    pol = X.make(name)
    R = []
    for i in range(n):
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        R.append(dict(bk=bool(d.get("_bankrupt")), bky=d.get("_yr") if d.get("_bankrupt") else None,
                      mn=s.min_money, wk=d.get("_wk", 1), neg=d.get("_neg_wk", 0), neg50=d.get("_neg50_wk", 0), won=first is not None))
    return name, setting, R

def q(v, p): v = sorted(v); return v[min(len(v) - 1, int(p * len(v)))]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(b, n, st) for st in ("new", "old") for b in BOTS]
    with Pool(10, maxtasksperchild=1) as p: res = p.map(run, jobs, chunksize=1)
    print(f"n={n} NETA_ON=NETA_V2=True 夜逃げ=-100万 | 最低所持金は万円 | 借金週=週頭の所持金<0の週/全週（夜逃げで終わったキャリアはその時点まで）")
    print("設定|ボット|優勝%|夜逃げ%|夜逃げ年(1/2/3/4/5/6+ %)|最低所持金 p10/中央/p90|借金週%(平均)|借金経験%|-50万割れ%|-50万週%(平均)")
    for name, st, R in res:
        k = len(R); bks = [r for r in R if r["bk"]]
        yrs = [sum(1 for r in bks if (r["bky"] == y if y < 6 else r["bky"] >= 6)) * 100 / k for y in range(1, 7)]
        mn = [r["mn"] / 10000 for r in R]
        negw = 100 * sum(r["neg"] for r in R) / sum(r["wk"] for r in R)
        n50 = 100 * sum(r["neg50"] for r in R) / sum(r["wk"] for r in R)
        print(f"{st}|{name}|{100*sum(r['won'] for r in R)/k:.1f}|{100*len(bks)/k:.1f}|" + "/".join(f"{y:.1f}" for y in yrs) +
              f"|{q(mn,.1):.0f}/{statistics.median(mn):.0f}/{q(mn,.9):.0f}|{negw:.1f}|{100*sum(r['neg']>0 for r in R)/k:.1f}|{100*sum(r['mn']<-500000 for r in R)/k:.1f}|{n50:.1f}", flush=True)

if __name__ == "__main__": main()
