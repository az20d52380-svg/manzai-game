#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""終盤(6〜15年目)のイベント枠 3案の実測（2026-11-07）。本体の式・コード・golden は変えない（仮の値はこのスクリプト内だけ）。
使い方: python3 exp_late_event_cap_1107_v0.py [n=300]   → stdout（docs/late_game_content_v0.md §1 に要約）
設定: exp_event_cap_v0 と同じ（NETA込み・正典v2・EVENTS_ON・OTHERS_ON・EVENT_DRAW_FILTER・率12%）。ボット4種。
枠: 通算上限 = 15 + k×max(0, 年-5)（k=0 現行 / 2 / 3 / 4）。年初に C.EVENT_FIRE_CAP を差し替える（run_year を包む）。
新イベント20本の模型: 'late0'..'late19'＝6年目以降に発火帯。効果は5種の雛形×4（既存の幅＝能力±1・体力±5〜15・知名度+1・お金±1.5万以内）。
  方針は既存と同じ（体力50+なら A、無ければ B）。k=0 は新イベント無し（現行そのもの）。
集計: 15年内の初優勝%・決勝(1度でも)%・解散%・夜逃げ%・6〜15年目の年あたり発火数。"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_stuck_v0 import make

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
KS = [0, 2, 3, 4]
LATE = [f"late{i}" for i in range(20)]

def late_apply(s, i):
    t = i % 5
    A = s.stamina >= 50
    if t == 0:
        (_a(s, "fame", 1), _a(s, "stamina", -10)) if A else _a(s, "stamina", 5)
    elif t == 1:
        if A and s.money >= 20_000: _a(s, "mental", 1); s.money -= 8000
        else: _a(s, "mental", -1); _a(s, "stamina", 5)
    elif t == 2:
        if A: _a(s, "sense", 1); _a(s, "mental", -1)
        else: _a(s, "stamina", 10); _a(s, "mental", 1)
    elif t == 3:
        if A: s.money += 15_000; _a(s, "stamina", -12)
        else: _a(s, "expr", 1)
    else:
        _a(s, "compat", 1); _a(s, "stamina", -5) if A else None
def _a(s, k, v): C._ev_add(s, k, v)

def install(k):
    V.apply(); C.EVENTS_ON = True; C.OTHERS_ON = True
    C.NETA_ON = C.NETA_V2 = True; C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2
    B.enable_places(True); B.enable_paid_rests(True)
    C.EVENT_DRAW_FILTER = True; C.EVENT_RATE = 0.12; C.EVENT_FORCE = {}
    if k > 0:
        C.OTHERS_EVENTS.extend(LATE)
        of, oa = C._others_fireable, C._others_apply
        C._others_fireable = lambda n, s, w, y, h: (y >= 6 and s.money >= 1500) if n.startswith("late") else of(n, s, w, y, h)
        C._others_apply = lambda s, n: late_apply(s, int(n[4:])) if n.startswith("late") else oa(s, n)
    o = C.run_year
    def run_year(pol, s, year, rng, **kw):
        C.EVENT_FIRE_CAP = 15 + k * max(0, year - 5)
        b = len(C.RUN_EVENTS_FIRED)
        r = o(pol, s, year, rng, **kw)
        s.__dict__.setdefault("_evy", {})[year] = len(C.RUN_EVENTS_FIRED) - b
        s.__dict__["_finals"] = s.__dict__.get("_finals", 0) + (1 if r[2] else 0)
        return r
    C.run_year = run_year

def one(a):
    k, name, n = a
    install(k); pol = make(name)
    win = fin = ds = bk = 0; late = []; wy = []
    for i in range(n):
        first, s, st, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        win += first is not None; fin += bool(ever); ds += bool(d.get("_dissolved")); bk += bool(d.get("_bankrupt"))
        if first: wy.append(first)
        ev = d.get("_evy", {}); late.append(sum(v for y, v in ev.items() if y >= 6) / 10)
    return k, name, dict(n=n, win=win, fin=fin, ds=ds, bk=bk, late=late, wy=wy)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    jobs = [(k, b, n) for k in KS for b in BOTS]
    with Pool(8, maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)
    by = {}
    for k, name, r in res: by.setdefault(k, []).append((name, r))
    print(f"n={n}/ボット x4ボット。通算上限=15+k×(年-5)。")
    print("|枠(6年目以降/年)|6〜15年目の年あたり発火|優勝%|決勝%|解散%|夜逃げ%|優勝年 中央|")
    print("|---|---|---|---|---|---|---|")
    for k in KS:
        rs = [r for _, r in by[k]]; tot = sum(r["n"] for r in rs)
        pc = lambda f: 100 * sum(r[f] for r in rs) / tot
        wy = [y for r in rs for y in r["wy"]]
        print(f"|{'現行(0)' if k == 0 else k}|{statistics.mean(x for r in rs for x in r['late']):.2f}|{pc('win'):.1f}|{pc('fin'):.1f}|{pc('ds'):.1f}|{pc('bk'):.1f}|{statistics.median(wy) if wy else '-'}|")
    print("\n## ボット別 優勝%/決勝%/解散%")
    for k in KS:
        print(f"k={k}: " + " / ".join(f"{name[:6]} {100*r['win']/r['n']:.1f}/{100*r['fin']/r['n']:.1f}/{100*r['ds']/r['n']:.1f}" for name, r in by[k]))
if __name__ == "__main__": main()
