#!/usr/bin/env python3
"""王者編：式案 cfg（評価軸）の上で「全員N年」と「10年＋王者だけ延長」を比べる。
usage: python3 exp_dynasty_v3.py [n] [cfg.json]  例: python3 exp_dynasty_v3.py 300 exp_eval_axes/cfg_r2.json
exp_dynasty_v2.career を流用。決定ではなく材料（docs/dynasty_v2_research_v0.md）。数値は全て【仮】。"""
import sys, os, json, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "exp_eval_axes"))
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
import exp_dynasty_v2 as D

def table(n, label, years, extend):
    C.YEARS = years
    for mode in ("予選から", "決勝シード", "シード+王者ライン"):
        pol = PNeedV3(); firsts = 0; tw = collections.Counter(); bs = collections.Counter()
        for i in range(n):
            f, w, b = D.career(pol, C.BASE_SEED + i, mode, extend)
            firsts += f is not None; tw[w] += 1; bs[b] += 1
        ch = max(firsts, 1)
        avg = sum(k * v for k, v in tw.items() if k >= 1) / ch
        s2 = 100 * sum(v for k, v in bs.items() if k >= 2) / ch
        s3 = 100 * sum(v for k, v in bs.items() if k >= 3) / ch
        print(f"{label}\t{mode}\t初回優勝{100*firsts/n:.1f}%\t王者平均{avg:.2f}回\t2連+{s2:.0f}%\t3連+{s3:.0f}%\t最長{max(bs)}", flush=True)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    if len(sys.argv) > 2:
        import proto as P
        P.CFG.update(json.load(open(sys.argv[2]))); P.install(); P.install_rec()
    V.apply()
    try:
        base = C.YEARS
        table(n, "全員15年", 15, None)
        table(n, "10年＋王者延長", base, (3, 25))
    finally:
        C.YEARS = 10
        V.reset()

if __name__ == "__main__":
    main()
