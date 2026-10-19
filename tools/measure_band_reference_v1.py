#!/usr/bin/env python3
"""基準の帯1枚（docs/band_reference_1019_v1.md）。usage: python3 measure_band_reference_v1.py [n=1000]
exp_events_app_v0.py の one() と同じ（M.one 全部入り）に、1年目決勝到達%・初優勝年の中央を足す。ボット4種×{ネタ無し,込}×{EVENTS_APP False,True}。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M
import exp_balance_snapshot_v0 as S

def one(args):
    app, neta, name, n = args
    C.EVENTS_APP = bool(app)
    y1, wy = [], []
    o_inst = S.install
    def inst(ne):
        o_inst(ne)
        o = C.run_year
        def ry(pol, s, year, rng, **kw):
            r = o(pol, s, year, rng, **kw)
            if year == 1: y1.append(bool(r[2]))
            return r
        C.run_year = ry
        orc = C.run_career
        def rc(*a, **k):
            r = orc(*a, **k)
            if r[0] is not None: wy.append(r[0])
            return r
        C.run_career = rc
    S.install = inst
    r = M.one(("all", neta, name, n))[3]
    wy.sort()
    r["y1fin"] = 100.0 * sum(y1) / max(1, len(y1))
    r["wy"] = wy[len(wy) // 2] if wy else float("nan")
    return app, neta, name, r

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(a, ne, b, n) for a in (False, True) for ne in (False, True) for b in M.BOTS], chunksize=1)
    print(f"# n={n}/ボット・全部入り。所持金は万円 Q1/中央/Q3。10年目=10年目まで続いた人のみ(n10)")
    print("EVENTS_APP|ネタ|ボット|1年目決勝%|初優勝年中央|10年優勝%|決勝%|解散%|夜逃げ%|10年目所持金(n10)")
    for a, ne, name, r in res:
        print(f"{a}|{'込' if ne else '無'}|{M.SHORT[M.BOTS.index(name)]}|{r['y1fin']:.1f}|{r['wy']}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|"
              + "/".join(f"{x:.0f}" for x in r["y10"]) + f"({r['n10']})")

if __name__ == "__main__":
    main()
