#!/usr/bin/env python3
"""M0: 成長予算と経験点のどちらが律速か（年末時点）。正典ツールは書き換えない（monkeypatchのみ）。
usage: python3 m0_budget.py <tools_dir> [n]"""
import sys, statistics, time
sys.path.insert(0, sys.argv[1])
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread
sys.path.insert(0, ".")
from bots_v3 import PNeedV3, PRotate

n = int(sys.argv[2]) if len(sys.argv) > 2 else 300
REC = []
_orig = C.run_year

def run_year_wrapped(pol, s, year, rng, **kw):
    r = _orig(pol, s, year, rng, **kw)
    cap = B.YEAR_GROWTH_CAP
    used = getattr(s, "_yg", 0.0)
    cur = s.exp_hirameki + s.exp_goi + s.exp_maai + s.exp_sonzaikan + s.exp_tanryoku
    REC.append(dict(year=year, cap=cap, used=used, slack=cap - used, cur=cur, J=B.jitsuryoku(s),
                    ab=(s.sense, s.idea, s.expr, s.chara, s.mental), compat=s.compat, won=r[0], stage=r[1], fin=r[2]))
    return r

C.run_year = run_year_wrapped
V.apply()
for cls in (PNeedV3, PRotate, PCasual2):
    pol = cls()
    REC.clear()
    t0 = time.time()
    wins = finals = 0
    for i in range(n):
        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
        wins += first is not None
        finals += ever_final
    dt = time.time() - t0
    print(f"== {pol.name} n={n} 優勝{100*wins/n:.1f}% 決勝到達{100*finals/n:.1f}% ({dt:.1f}s)")
    for y in (1, 2, 3, 5, 7, 10):
        rows = [r for r in REC if r["year"] == y]
        if not rows:
            continue
        bound = sum(1 for r in rows if r["slack"] < 0.5) / len(rows)
        print(f"  {y:2d}年末 n={len(rows):4d} 予算律速(残<0.5)={100*bound:5.1f}%  予算残 中央{statistics.median(r['slack'] for r in rows):5.2f}"
              f"  通貨残 中央{statistics.median(r['cur'] for r in rows):6.1f}  J中央{statistics.median(r['J'] for r in rows):5.1f}"
              f"  能力(S,I,E,C,M)中央 " + ",".join(f"{statistics.median(r['ab'][k] for r in rows):.0f}" for k in range(5))
              + f"  相性{statistics.median(r['compat'] for r in rows):.1f}")
V.reset()
