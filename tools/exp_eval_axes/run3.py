#!/usr/bin/env python3
"""ライン較正用。usage: python3 run3.py <tools_dir> <n> '<json cfg>' [lines json]"""
import sys, json
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, ".")
import balance_sim as B, sim_career as C, canon_v2 as V
from exp_human import PCasual2
import proto as P
from bots_v3 import PRotate
n = int(sys.argv[2])
cfg = json.loads(sys.argv[3])
for k, v in cfg.items():
    P.CFG[k] = v
if "burst" in cfg:
    B.BURST_P, B.BURST_BONUS = cfg["burst"]
P.install(); P.install_rec(); V.apply()
bots = [("やり込み(均等)", P.BuildBot("均等", *P.BUILDS["均等"])),
        ("やり込み(発想型)", P.BuildBot("発想型", *P.BUILDS["発想型"])),
        ("やり込み(華型)", P.BuildBot("華型", *P.BUILDS["華型"])),
        ("ふつう(ローテ)", P.CasualBot(PRotate(), read=False)),
        ("のんびり改", P.CasualBot(PCasual2(), read=False))]
show = set(cfg.get("_show", ["やり込み(均等)", "ふつう(ローテ)"]))
for label, pol in bots:
    P.YEAR_END.clear()
    r = P.run(pol, n)
    yrs = sorted(r["years"]); med = yrs[len(yrs)//2] if yrs else "-"
    print(f"== {label:<12} 優勝 {r['win']:5.2f}%（中央{med}年） 決勝到達 {r['fin']:5.1f}%")
    if label in show:
        print(P.table(r)); print(P.profile((1, 3, 10)))
V.reset()
