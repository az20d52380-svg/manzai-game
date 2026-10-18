#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""イベント発火上限×抽選率の実測（2026-10-16）。式は変えない。仮の値はこのスクリプト内だけ。
使い方: python3 exp_event_cap_v0.py [n=1000]   → 結果は stdout（docs/event_cap_measure_v0.md に要約）
設定: exp_balance_snapshot_v0 と同じ（NETA込み・正典v2・EVENTS_ON・OTHERS_ON）。ボット4種=のんびり改/ローテ/必要充足/やり込み改。
抽選: Swift 本番と同じ「発火帯の未発火候補から一様」(EVENT_DRAW_FILTER=True)。上限=cap(15/20/25/None) × 率(0.12/0.16) × 確定(なし/夏祭り=窓14-20の最初の自由週・年末=窓33-36の最初の自由週（窓内で発火帯を満たす週）)。
集計: ①1キャリアで発火した数 ②種ごとの「1キャリアで見る確率」 ③決勝・優勝・夜逃げ・解散・10年目所持金。"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_stuck_v0 import make

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
LBL = {"PCasual2": "のんびり改", "PRotate": "ローテ", "PNeedV3": "必要充足", "金→力 全振り(やり込み改)": "やり込み改"}
CONFIGS = [(cap, rate, force) for force in (False, True) for rate in (0.12, 0.16) for cap in (15, 20, 25, None)]

def one(args):
    (cap, rate, force), name, n = args
    V.apply(); C.EVENTS_ON = True; C.OTHERS_ON = True
    C.NETA_ON = C.NETA_V2 = True; C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2
    B.enable_places(True); B.enable_paid_rests(True)
    C.EVENT_DRAW_FILTER = True; C.EVENT_FIRE_CAP = cap; C.EVENT_RATE = rate
    C.EVENT_FORCE = {"festival": (14, 20), "yearend": (33, 36)} if force else {}
    nm = [f"T{i}" for i in range(len(C.EVENT_TABLE))] + list(C.OTHERS_EVENTS)
    pol = make(name)
    seen = {k: 0 for k in nm}; fired_n = []; fin = win = bk = ds = 0; m10 = []
    for i in range(n):
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
        f = C.RUN_EVENTS_FIRED
        fired_n.append(len(f))
        for idx in f: seen[nm[idx]] += 1
        d = s.__dict__
        fin += bool(ever); win += first is not None; bk += bool(d.get("_bankrupt")); ds += bool(d.get("_dissolved"))
        if ml[9]: m10.append(ml[9][0] / 10000)
    return (cap, rate, force), name, dict(n=n, fired=fired_n, seen=seen, fin=fin, win=win, bk=bk, ds=ds, m10=m10)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(c, b, n) for c in CONFIGS for b in BOTS]
    with Pool(10, maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)
    nm = [f"T{i}" for i in range(len(C.EVENT_TABLE))] + list(C.OTHERS_EVENTS)
    by = {}
    for cfg, name, r in res: by.setdefault(cfg, []).append(r)
    print(f"n={n}/ボット x4ボット(のんびり/ローテ/必要充足/やり込み)・NETA込み。種数 T=既存{len(C.EVENT_TABLE)}+others{len(C.OTHERS_EVENTS)}")
    print("## 表1 設定別\n|上限|率|確定|発火数 平均|p10|中央|p90|決勝%|優勝%|夜逃げ%|解散%|10年目所持金(万)中央|最低種%|夏祭り%|年末%|3割未満の種数|6割超の種数|\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    detail = {}
    for cfg in CONFIGS:
        rs = by[cfg]; tot = sum(r["n"] for r in rs)
        fired = sorted(x for r in rs for x in r["fired"])
        q = lambda p: fired[min(len(fired) - 1, int(p * len(fired)))]
        seen = {k: sum(r["seen"][k] for r in rs) / tot for k in nm}
        detail[cfg] = seen
        m10 = [x for r in rs for x in r["m10"]]
        pc = lambda k: 100 * sum(r[k] for r in rs) / tot
        allv = list(seen.values())
        cap, rate, force = cfg
        print(f"|{cap or '無'}|{int(rate*100)}%|{'有' if force else '-'}|{statistics.mean(fired):.1f}|{q(.1)}|{q(.5)}|{q(.9)}|{pc('fin'):.1f}|{pc('win'):.1f}|{pc('bk'):.1f}|{pc('ds'):.1f}|{statistics.median(m10):.0f}|{100*min(allv):.0f}|{100*seen['festival']:.0f}|{100*seen['yearend']:.0f}|{sum(v<0.3 for v in allv)}|{sum(v>0.6 for v in allv)}|")
    print("\n## 表2 種ごとの見る確率%（全ボット合算）")
    print("|種|" + "|".join(f"{c[0] or '無'}/{int(c[1]*100)}%/{'確' if c[2] else '-'}" for c in CONFIGS) + "|")
    print("|---|" + "---|" * len(CONFIGS))
    for k in nm:
        print(f"|{k}|" + "|".join(f"{100*detail[c][k]:.0f}" for c in CONFIGS) + "|")
    print("\n## 表3 ボット別")
    for cfg, name, r in res:
        if cfg in [(15, .12, False), (25, .16, False), (None, .16, False), (25, .16, True)]:
            print(f"{cfg} {LBL[name]}: 発火平均{statistics.mean(r['fired']):.1f} 決勝{100*r['fin']/r['n']:.1f}% 優勝{100*r['win']/r['n']:.1f}% 夜逃げ{100*r['bk']/r['n']:.1f}% 解散{100*r['ds']/r['n']:.1f}% 所持金{(statistics.median(r['m10']) if r['m10'] else 0):.0f}")

if __name__ == "__main__": main()
