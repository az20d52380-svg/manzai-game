#!/usr/bin/env python3
"""usage: python3 run2.py <tools_dir> <n> '<json cfg>' [tables: 均等,のんびり,...] """
import sys, json
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, ".")
import balance_sim as B, sim_career as C, canon_v2 as V
from exp_human import PCasual2
import proto as P
n = int(sys.argv[2])
cfg = json.loads(sys.argv[3])
show = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else {"均等", "のんびり改"}
for k, v in cfg.items():
    P.CFG[k] = v
if "burst" in cfg:
    B.BURST_P, B.BURST_BONUS = cfg["burst"]
P.install(); P.install_rec(); V.apply()
bots = [P.BuildBot(nm, *P.BUILDS[nm]) for nm in P.BUILDS]
bots.insert(1, P.BuildBot("均等（読まない）", *P.BUILDS["均等"], read=False))
bots.append(P.CasualBot(PCasual2()))
for pol in bots:
    P.YEAR_END.clear()
    r = P.run(pol, n)
    yrs = sorted(r["years"]); med = yrs[len(yrs)//2] if yrs else "-"
    print(f"== {pol.name:<10} 優勝 {r['win']:5.2f}%（中央{med}年） 決勝到達 {r['fin']:5.1f}%")
    if pol.name in show:
        print(P.table(r)); print(P.profile((3, 10)))
V.reset()
