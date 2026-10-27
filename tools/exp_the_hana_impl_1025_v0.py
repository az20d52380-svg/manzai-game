#!/usr/bin/env python3
"""THE HANA を sim_career に正式に足した形（set_hana(True)）で、実験版（exp_the_hana_1025_v0.install）と同じ帯になるかの確認（【仮】）。
usage: python3 exp_the_hana_impl_1025_v0.py [n=300] [out.json]
exp_the_hana_1025_v0 の集計・ボット・条件をそのまま使い、差し込みだけを C.set_hana(True) に替える（案は「難/賞250万」＝HANA_ROUNDS の既定）。
Pool(maxtasksperchild=1)・chunksize=1。結果は docs/the_hana_measure_1025_v0.md §6。"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import exp_the_hana_1025_v0 as E

E.install = lambda lines, prize, fame: C.set_hana(True)   # 正式実装の口に差し替え（spawn の子でも同じく差し替わる）

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    outp = sys.argv[2] if len(sys.argv) > 2 else None
    vars_ = ["男", "難/賞250万"]
    jobs = [((v, bi, ne), bi, ne, v, ch) for v in vars_ for bi in range(4) for ne in (False, True) for ch in E.chunks(n)]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(E.job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    agg = {}
    for v in vars_:
        S = [E.summ(res[(v, bi, ne)]) for bi in range(4) for ne in (False, True)]
        agg[v] = {k: round(statistics.mean(x[k] for x in S if x[k] is not None), 1) for k in S[0] if k != "n"}
    for v, a in agg.items():
        print(v, " ".join(f"{k}={a[k]}" for k in ("w10", "fin", "bk", "f3", "m10", "hw", "hf")))
    if outp:
        json.dump(dict(n=n, agg=agg), open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
