#!/usr/bin/env python3
"""イベント効果の強さ案の比較（docs/event_scale_options_v0.md）。usage: python3 exp_event_scale_v0.py [n=300]
案: raw=素の加減算x1.0(今) / half=正の増分x0.5 / decay=能力5種の正の増分にx(1-現在値/D)(知名度・予算は通さない) / badd=直す前のB.add(参考)。
ボット・全部入り・ネタ込みは exp_events_app_v0.py の one() と同じ。上書きはプロセス内のみ。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M

ABIL = ("sense", "expr", "idea", "chara", "compat")

def patch(mode):
    C.EVENTS_APP = True
    raw = C._ev_add
    B = C.B
    if mode == "raw":
        return
    if mode == "badd":
        C._ev_add = lambda s, k, a: B.add(s, k, a); return
    if mode == "half":
        C._ev_add = lambda s, k, a: raw(s, k, a * 0.5 if a > 0 else a); return
    if mode == "decay":
        D = B.GROWTH_DECAY_D
        def f(s, k, a):
            if a > 0 and k in ABIL:
                a = a * max(0.0, 1 - getattr(s, k) / D)
            return raw(s, k, a)
        C._ev_add = f; return

def one(args):
    mode, name, n = args
    patch(mode)
    r = M.one(("all", True, name, n))
    return mode, name, r[3]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    modes = sys.argv[2].split(",") if len(sys.argv) > 2 else ["raw", "half", "decay", "badd"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(m, b, n) for m in modes for b in M.BOTS], chunksize=1)
    print(f"# n={n}/ボット 所持金は万円 Q1/中央/Q3")
    print("案|ボット|優勝%|決勝%|10年目所持金(n10)")
    for m, name, r in res:
        print(f"{m}|{M.SHORT[M.BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|" + "/".join(f"{x:.0f}" for x in r["y10"]) + f"({r['n10']})")

if __name__ == "__main__":
    main()
