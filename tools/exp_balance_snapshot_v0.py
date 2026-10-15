#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""10年通しの手応え スナップショット（2026-10-16）。コード・式は変更しない。
使い方: python3 exp_balance_snapshot_v0.py [n=1000]
設定: NETAなし(ON=False) / NETA込み(NETA_ON=NETA_V2=True・飽きD PEN1.0/CAP2)。正典v2・EVENTS_ON・今の既定(お金L・知名度G・rift GAIN0.5/HEAL3)。
ボット: のんびり改/ローテ/必要充足/やり込み/人間らしい(無料稽古3週:バイト1週＋喫茶店)/放置(相方を放っておく)2種。
エンディング(docs/endings_spec_v1.md §1-1の順): 夜逃げ#1→解散#2→優勝(相性>=15で#8/未満#7)→10年末(決勝>=1)×(相性>=15): #6/#5/#4/#3。
sim の相性は s.compat（本番と同じ上限20）。決勝回数は run_year の finalist を年ごとに数えた値（近似なし）。"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_stuck_v0 import make, POne, J, T, R
from exp_places_v1 import Cafe

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "人間らしい(稽古3週:バイト1週+喫茶店)",
        "放置(ネタ作り/フリーライブ/バイト)", "放置(バイト+休み)"]

def make2(name):
    if name.startswith("人間らしい"):
        return Cafe(POne(name, [T(["ネタ作り", "ネタ合わせ", "フリーライブ"][j % 3]) for j in range(3)] + [J("標準")], take_offer=True, rest_below=20))
    if name.startswith("放置(ネタ作り"):
        return POne(name, [T("ネタ作り"), T("フリーライブ"), J("標準")], rest_below=20)
    if name.startswith("放置(バイト"):
        return POne(name, [J("標準"), J("標準"), R("気分転換")], rest_below=20)
    return make(name)

def install(neta):
    V.apply(); C.EVENTS_ON = True
    C.NETA_ON = C.NETA_V2 = neta
    if neta: C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2
    B.enable_places(True); B.enable_paid_rests(True)
    o = C.run_year
    def run_year(pol, s, year, rng, **kw):
        r = o(pol, s, year, rng, **kw)
        if r[2]: s.__dict__["_finals"] = s.__dict__.get("_finals", 0) + 1
        s.__dict__["_yr"] = year
        return r
    C.run_year = run_year

def one(args):
    neta, name, n = args
    install(neta)
    cnt = dict(job=0, all=0)
    oj, ot, orr, oo = B.do_job, B.do_training, B.do_rest, B.do_offer
    def dj(s, nm): cnt["job"] += 1; cnt["all"] += 1; return oj(s, nm)
    def dt(s, nm):
        r = ot(s, nm); cnt["all"] += 1; return r
    def dr(s, nm): cnt["all"] += 1; return orr(s, nm)
    def do_(s, o): cnt["all"] += 1; return oo(s, o)
    B.do_job, B.do_training, B.do_rest, B.do_offer = dj, dt, dr, do_
    pol = make2(name); recs = []
    for i in range(n):
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
        d = s.__dict__
        bk, ds = bool(d.get("_bankrupt")), bool(d.get("_dissolved"))
        champ = first is not None; fin = d.get("_finals", 0); hi = s.compat >= 15
        if bk: e = 1
        elif ds: e = 2
        elif champ: e = 8 if hi else 7
        else: e = {(True, True): 6, (True, False): 5, (False, True): 4, (False, False): 3}[(fin >= 1, hi)]
        recs.append(dict(bk=bk, ds=ds, win=first, fin=ever, e=e, m10=(ml[9][0] if ml[9] else None), full=(not bk and not ds and not champ)))
    return neta, name, recs, cnt["job"] / max(1, cnt["all"])

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(ne, b, n) for ne in (False, True) for b in BOTS]
    with Pool(10) as p: res = p.map(one, jobs)
    p1 = lambda x, k: f"{100*x/k:.1f}"
    print(f"n={n} 優勝年=初優勝年の中央値 | 10年目所持金=10年目の年末まで残った人の中央値(万) | バイト週=バイト週/全行動週")
    print("NETA|ボット|決勝到達%|優勝%|初優勝年(中央)|夜逃げ%|解散%|10年完走%(未優勝で生存)|10年目所持金|バイト週%|#1|#2|#3|#4|#5|#6|#7|#8")
    for ne, name, R_, jw in res:
        k = len(R_); wy = [r["win"] for r in R_ if r["win"]]; m10 = [r["m10"] / 10000 for r in R_ if r["m10"] is not None]
        es = [p1(sum(r["e"] == j for r in R_), k) for j in range(1, 9)]
        print(f"{'込み' if ne else 'なし'}|{name}|{p1(sum(r['fin'] for r in R_),k)}|{p1(sum(r['win'] is not None for r in R_),k)}|"
              f"{statistics.median(wy) if wy else '-'}|{p1(sum(r['bk'] for r in R_),k)}|{p1(sum(r['ds'] for r in R_),k)}|{p1(sum(r['full'] for r in R_),k)}|"
              f"{(format(statistics.median(m10), '.0f') if m10 else '-')}|{100*jw:.0f}|" + "|".join(es), flush=True)

if __name__ == "__main__": main()
