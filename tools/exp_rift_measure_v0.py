#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""途中解散（すれ違いゲージ）の実測 v0。式は変えない（定数の上書きと集計のみ）。
使い方: python3 exp_rift_measure_v0.py [n=1000] [--sweep]
設定A=現行(ネタOFF) / B=NETA_ON+V2。ボット: PCasual2/PRotate/PNeedV3/PNeedMax(やり込み)/放置(相方を避ける)。
RIFT: OFF / ON(既定) / ON+RESPOND。--sweep で GAIN/HEAL/WARN の調整案も。"""
import sys
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_stuck_v0 import make, POne, J, T, R

YEARS = 10
BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)", "放置(バイト+休み)"]

def make2(name):
    if name.startswith("放置(ネタ作り"):
        return POne(name, [T("ネタ作り"), T("フリーライブ"), J("標準")], rest_below=20)
    if name.startswith("放置(バイト"):
        return POne(name, [J("標準"), J("標準"), R("気分転換")], rest_below=20)
    return make(name)

def install(setting, cfg):
    V.apply(); C.EVENTS_ON = True
    C.NETA_ON = C.NETA_V2 = (setting == "B")
    if setting == "B": C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2
    B.enable_places(True); B.enable_paid_rests(True)
    C.RIFT_ON = cfg["on"]; C.RIFT_RESPOND = cfg.get("respond", False)
    C.RIFT_GAIN = cfg.get("gain", 1.5); C.RIFT_HEAL = cfg.get("heal", 3.0); C.RIFT_WARN = cfg.get("warn", 50.0)
    o = C.run_year
    def run_year(pol, s, year, rng, **kw):
        r = o(pol, s, year, rng, **kw)
        d = s.__dict__
        d.setdefault("_ry", []).append((year, getattr(s, "rift", 0.0)))
        return r
    C.run_year = run_year

def one(args):
    setting, name, cname, cfg, n = args
    install(setting, cfg)
    pol = make2(name); recs = []
    for i in range(n):
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__; ry = d.get("_ry", [])
        recs.append(dict(dis=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt")), yr=ry[-1][0] if ry else 0,
                         rifts=[x[1] for x in ry], win=first, stage=stage, fin=bool(ever), fame=s.fame, compat=s.compat))
    return setting, name, cname, recs

def pct(x, n): return f"{100*x/n:.1f}"
def q(v, p): v = sorted(v); return v[min(len(v)-1, int(p*len(v)))] if v else float('nan')

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1000
    cfgs = {"OFF": dict(on=False), "ON": dict(on=True), "ON+向き合う": dict(on=True, respond=True)}
    if "--sweep" in sys.argv:
        for g, h, w in [(1.0, 3.0, 50.0), (2.0, 3.0, 50.0), (1.5, 2.0, 50.0), (1.5, 4.0, 50.0), (1.5, 3.0, 40.0), (1.5, 3.0, 60.0), (2.0, 2.0, 50.0)]:
            cfgs[f"G{g}/H{h}/W{w:.0f}"] = dict(on=True, gain=g, heal=h, warn=w)
    if "--sweep2" in sys.argv:
        cfgs = {"OFF": dict(on=False)}
        for g, h in [(0.5, 3.0), (0.7, 3.0), (1.0, 3.0), (1.0, 5.0), (0.7, 5.0), (1.2, 4.0)]:
            cfgs[f"G{g}/H{h}/W50"] = dict(on=True, gain=g, heal=h); cfgs[f"G{g}/H{h}/W50+向き合う"] = dict(on=True, gain=g, heal=h, respond=True)
    jobs = [(s, b, cn, cf, n) for s in (("A",) if "--sweep2" in sys.argv else ("A", "B")) for b in BOTS for cn, cf in cfgs.items()]
    with Pool(10, maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)
    R_ = {(s, b, c): r for s, b, c, r in res}
    for s in (("A",) if "--sweep2" in sys.argv else ("A", "B")):
        print(f"\n## 設定{s} n={n}")
        print("\n### 解散率・夜逃げ・決勝・優勝（cfg別）\n| ボット | cfg | 解散% | 夜逃げ% | 決勝進出% | 優勝% | 知名度中央 |\n|---|---|---|---|---|---|---|")
        for b in BOTS:
            for c in cfgs:
                r = R_[(s, b, c)]
                print(f"| {b} | {c} | {pct(sum(x['dis'] for x in r),n)} | {pct(sum(x['bk'] for x in r),n)} | {pct(sum(x['fin'] for x in r),n)} | {pct(sum(x['win'] is not None for x in r),n)} | {q([x['fame'] for x in r],.5):.0f} |")
        if "--sweep2" in sys.argv: continue
        print("\n### 解散した年の分布（ON）と年末rift（全キャリア年末値のp50/p90、ON）\n| ボット | 解散年1〜10(件%) | rift p50/p90/p99 |\n|---|---|---|")
        for b in BOTS:
            r = R_[(s, b, "ON")]; dy = [x['yr'] for x in r if x['dis']]
            allr = [v for x in r for v in x['rifts']]
            print(f"| {b} | " + " ".join(f"{sum(1 for y in dy if y==k)*100/n:.1f}" for k in range(1, 11)) + f" | {q(allr,.5):.0f}/{q(allr,.9):.0f}/{q(allr,.99):.0f} |")
        print("\n### 解散×成績（ON）: 解散者の決勝経験率/優勝率 vs 継続者、成績良(決勝経験)で解散%、成績悪(決勝なし)で継続%\n| ボット | 解散者:決勝% | 解散者:優勝% | 継続者:決勝% | 継続者:優勝% | 決勝経験者の解散% | 決勝なしの継続% | 解散者fame中央 | 継続者fame中央 |\n|---|---|---|---|---|---|---|---|---|")
        for b in BOTS:
            r = R_[(s, b, "ON")]; D = [x for x in r if x['dis']]; K = [x for x in r if not x['dis']]
            f = lambda L, k: pct(sum(1 for x in L if k(x)), max(1, len(L)))
            F = [x for x in r if x['fin']]; NF = [x for x in r if not x['fin']]
            print(f"| {b} | {f(D,lambda x:x['fin'])} | {f(D,lambda x:x['win'] is not None)} | {f(K,lambda x:x['fin'])} | {f(K,lambda x:x['win'] is not None)} | {f(F,lambda x:x['dis'])} | {f(NF,lambda x:not x['dis'])} | {q([x['fame'] for x in D],.5):.0f} | {q([x['fame'] for x in K],.5):.0f} |")

if __name__ == "__main__": main()
