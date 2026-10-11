#!/usr/bin/env python3
"""ビルド別の優勝/決勝到達を、設定の上書きごとに比較。usage: python3 scan.py <tools> <n> '<base cfg json>' '<list of override json>'"""
import sys, json, copy
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, ".")
import balance_sim as B, sim_career as C, canon_v2 as V
from exp_human import PCasual2
import proto as P
from bots_v3 import PRotate
n = int(sys.argv[2]); base = json.loads(sys.argv[3]); overs = json.loads(sys.argv[4])
DEFAULT = copy.deepcopy(P.CFG)
P.install(); V.apply()
for ov in overs:
    P.CFG.clear(); P.CFG.update(copy.deepcopy(DEFAULT)); P.CFG.update(base); P.CFG.update(ov)
    if "lines" in P.CFG and P.CFG["lines"]:
        pass
    out = []
    bots = [(nm, P.BuildBot(nm, *P.BUILDS[nm])) for nm in P.BUILDS]
    bots += [("均等読まない", P.BuildBot("x", *P.BUILDS["均等"], read=False)), ("ふつう読む", P.CasualBot(PRotate(), read=True)), ("ふつう", P.CasualBot(PRotate())), ("のんびり読む", P.CasualBot(PCasual2(), read=True)), ("のんびり", P.CasualBot(PCasual2()))]
    for nm, pol in bots:
        if ov.get("_only") and nm not in ov["_only"]:
            continue
        r = P.run(pol, n)
        out.append(f"{nm} {r['win']:.1f}/{r['fin']:.0f}")
    tag = ov.get("_tag") or {k: v for k, v in ov.items() if k not in ("lines", "_only")}
    print(json.dumps(tag, ensure_ascii=False)[:80], "\n   ", " | ".join(out), flush=True)
