#!/usr/bin/env python3
"""年次別の回戦通過率・道中大会の優勝率（今の式・正典は書き換えない）。
usage: python3 passrate.py <tools_dir> [n]"""
import sys, collections
sys.path.insert(0, sys.argv[1])
sys.path.insert(0, ".")
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

n = int(sys.argv[2]) if len(sys.argv) > 2 else 500
TRY = collections.Counter()
OK = collections.Counter()
GP_NAMES = {18: "GP1回戦", 26: "GP2回戦", 34: "GP3回戦", 45: "準々", 74: "準決勝"}

_perf = B.perform
_gp = C._gp_perform

def _year():
    f = sys._getframe(2)
    while f and "year" not in f.f_locals:
        f = f.f_back
    return f.f_locals["year"] if f else 0

def perf_wrapped(s, line, rng):
    r = _perf(s, line, rng)
    y = _year()
    name = f"大会{int(line)}"
    TRY[(y, name)] += 1
    OK[(y, name)] += r[0]
    return r

def gp_wrapped(s, line, rng, final):
    r = _gp(s, line, rng, final)
    y = _year()
    if final:
        name = "決勝" if line >= 77.5 else "敗者復活"
    else:
        name = GP_NAMES.get(int(round(line)), f"GP?{line}")
    TRY[(y, name)] += 1
    OK[(y, name)] += r[0]
    return r

B.perform = perf_wrapped
C._gp_perform = gp_wrapped
V.apply()
cols = ["GP1回戦", "GP2回戦", "GP3回戦", "準々", "準決勝", "決勝", "大会22", "大会28", "大会30", "大会33"]
for cls in (PNeedV3, PRotate, PCasual2):
    TRY.clear(); OK.clear()
    pol = cls()
    for i in range(n):
        C.run_career(pol, C.BASE_SEED + i)
    print(f"== {pol.name} n={n}  （通過率%／挑戦数）")
    print("年  " + "  ".join(f"{c:>9}" for c in cols))
    for y in (1, 2, 3, 4, 5, 7, 10):
        cells = []
        for c in cols:
            t = TRY[(y, c)]
            cells.append(f"{100*OK[(y,c)]/t:5.0f}/{t:<4d}" if t else f"{'-':>9}")
        print(f"{y:2d}  " + "  ".join(cells))
V.reset()
