#!/usr/bin/env python3
"""イベント効果の原因切り分け（docs/event_scale_options_v0.md §原因の切り分け）。usage: python3 exp_event_scale_v1.py [n=300] [modes]
素の加減算(raw)に B.add の部品を「1つだけ」通す: yearcap=年の予算 / fame=知名度の鈍化 / compat=相性の凍結 / allbutfame=知名度だけ素・他は B.add。
decay(成長の鈍り)のみ・badd・raw は v0 と同じ。上書きはプロセス内のみ。ボット・全部入り・ネタ込みは exp_events_app_v0.py の one() と同じ。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M

ABIL = ("sense", "expr", "idea", "chara", "compat")
STATS4 = ("sense", "expr", "idea", "chara")

def patch(mode):
    C.EVENTS_APP = True
    raw = C._ev_add
    B = C.B
    if mode == "raw":
        return
    if mode == "badd":
        C._ev_add = lambda s, k, a: B.add(s, k, a); return
    if mode == "decay":
        D = B.GROWTH_DECAY_D
        def f(s, k, a):
            if a > 0 and k in ABIL:
                a = a * max(0.0, 1 - getattr(s, k) / D)
            return raw(s, k, a)
        C._ev_add = f; return
    if mode == "yearcap":  # 年の予算のみ（鈍りは一時的に切る）
        def f(s, k, a):
            if k in STATS4 and a > 0:
                d = B.GROWTH_DECAY_D; B.GROWTH_DECAY_D = 0
                try: return B.add(s, k, a)
                finally: B.GROWTH_DECAY_D = d
            return raw(s, k, a)
        C._ev_add = f; return
    if mode == "fame":  # 知名度の鈍化のみ
        C._ev_add = lambda s, k, a: B.add(s, k, a) if k == "fame" else raw(s, k, a); return
    if mode == "compat":  # 相性の凍結のみ
        C._ev_add = lambda s, k, a: B.add(s, k, a) if k == "compat" else raw(s, k, a); return
    if mode == "allbutfame":  # 知名度だけ素・他は B.add
        C._ev_add = lambda s, k, a: raw(s, k, a) if k == "fame" else B.add(s, k, a); return
    raise SystemExit("unknown mode " + mode)

def one(args):
    mode, name, n = args
    patch(mode)
    r = M.one(("all", True, name, n))
    return mode, name, r[3]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    modes = sys.argv[2].split(",") if len(sys.argv) > 2 else ["raw", "yearcap", "fame", "compat", "allbutfame", "badd"]
    bots = M.BOTS
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(m, b, n) for m in modes for b in bots], chunksize=1)
    print(f"# n={n}/ボット")
    print("案|ボット|優勝%|決勝%|10年目所持金中央")
    for m, name, r in res:
        print(f"{m}|{M.SHORT[M.BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['y10'][1]:.0f}")

if __name__ == "__main__":
    main()
