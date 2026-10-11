#!/usr/bin/env python3
"""usage: python3 run1.py <tools_dir> <n> <scenario> [builds...]"""
import sys, json
sys.path.insert(0, sys.argv[1])
sys.path.insert(0, ".")
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
import proto as P

n = int(sys.argv[2])
scen = sys.argv[3]
only = sys.argv[4:]

SCEN = {
    "now": dict(ctx_on=False),
    "ctx": dict(ctx_on=True),
    "ctx_eq": dict(ctx_on=True, equal_budget=True),
}
for k, v in json.loads(scen).items() if scen.startswith("{") else SCEN[scen].items():
    P.CFG[k] = v

P.install()
V.apply()
bots = []
for name, (ratios, port) in P.BUILDS.items():
    if only and name not in only:
        continue
    bots.append(P.BuildBot(name, ratios, port, read=True))
    if name == "均等" and (not only or "読まない" in only):
        bots.append(P.BuildBot("均等（読まない）", ratios, port, read=False))
if not only or "のんびり" in only:
    bots.append(P.CasualBot(PCasual2()))
for pol in bots:
    r = P.run(pol, n)
    yrs = sorted(r["years"])
    med = yrs[len(yrs) // 2] if yrs else "-"
    print(f"== {pol.name:<10} 優勝 {r['win']:5.2f}%（中央{med}年） 決勝到達 {r['fin']:5.1f}%")
    if pol.name in ("均等", "均等（読まない）", "のんびり改") or only:
        print(P.table(r))
V.reset()
