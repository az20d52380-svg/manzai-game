#!/usr/bin/env python3
"""試作の最終計測：ビルド別の帯・大会（審査員）別の勝率・年次表。usage: python3 final_measure.py <tools> <n> <cfg.json>"""
import sys, json, copy
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, ".")
import balance_sim as B, sim_career as C, canon_v2 as V
from exp_human import PCasual2
import proto as P
from bots_v3 import PRotate
n = int(sys.argv[2]); cfg = json.load(open(sys.argv[3]))
P.CFG.update(cfg); P.install(); P.install_rec(); V.apply()
TN = list(P.TOURN_CTX)
bots = [(nm, P.BuildBot(nm, *P.BUILDS[nm])) for nm in P.BUILDS]
bots += [("均等・読まない", P.BuildBot("x", *P.BUILDS["均等"], read=False)),
         ("ふつう（読む）", P.CasualBot(PRotate(), read=True)), ("ふつう（読まない）", P.CasualBot(PRotate())),
         ("のんびり（読む）", P.CasualBot(PCasual2(), read=True)), ("のんびり（読まない）", P.CasualBot(PCasual2()))]
rows = []
for nm, pol in bots:
    P.YEAR_END.clear()
    r = P.run(pol, n)
    st = r["stats"]
    def pooled(key, ys):
        t = sum(st.get((y, key, "try"), 0) for y in ys); o = sum(st.get((y, key, "ok"), 0) for y in ys)
        return 100 * o / t if t else float("nan")
    tw = " ".join(f"{pooled(k, range(3, 8)):3.0f}" for k in TN)
    semi = pooled("GP4", range(1, 11))
    print(f"{nm:<12} 優勝{r['win']:5.1f}% 決勝到達{r['fin']:5.1f}% | 道中3-7年の優勝率 {tw} | 準決通過{semi:4.1f}%", flush=True)
    if nm in ("均等", "ふつう（読む）", "のんびり（読む）"):
        rows.append((nm, P.table(r), P.profile((1, 3, 5, 10))))
print("道中の並び:", " / ".join(TN))
for nm, t, p in rows:
    print(f"--- {nm}\n{t}\n{p}")
V.reset()
