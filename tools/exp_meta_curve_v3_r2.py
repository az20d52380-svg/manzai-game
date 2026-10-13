#!/usr/bin/env python3
"""周回曲線（exp_meta_curve_v3 と同じ）を式案 cfg_r2 の上で測る。既存スクリプト・既定値は触らない。
usage: python3 exp_meta_curve_v3_r2.py [n] [cfg.json] [m,m,...]。決定ではなく材料（docs/dynasty_v2_research_v0.md §5-2）。数値は全て【仮】。"""
import sys, os, json, statistics
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "exp_eval_axes"))
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import career

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    cfg = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "exp_eval_axes", "cfg_r2.json")
    ms = [float(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0, 0.33, 0.5, 0.67, 0.83, 0.89, 0.93, 1.0]
    import proto as P
    P.CFG.update(json.load(open(cfg))); P.install(); P.install_rec()
    V.apply()
    base = C.CAP_CURVE
    try:
        for m in ms:
            J0 = 44 * m ** 2.6
            C.CAP_CURVE = (base[0] + 0.02 * 30 * m, base[1], base[2])
            out = {}
            for mode in ("予選から", "決勝シード"):
                pol = PNeedV3(); res = [career(pol, C.BASE_SEED + i, J0, mode) for i in range(n)]
                fy = [f for f, w, b in res if f]; ch = max(len(fy), 1)
                out[mode] = dict(in10=100*sum(1 for f in fy if f <= C.YEARS)/n, y1=100*sum(1 for f in fy if f == 1)/n,
                    med=statistics.median(fy) if fy else "-", aw=sum(w for f, w, b in res if f)/ch,
                    c3=100*sum(1 for f, w, b in res if b >= 3)/ch, mx=max((b for f, w, b in res), default=0))
            a, b = out["予選から"], out["決勝シード"]
            print(f"| {m:.2f} | {30*m:.0f} | {J0:.1f} | {a['in10']:.1f}% | {a['y1']:.1f}% | {a['med']}年 | {a['aw']:.1f}／{b['aw']:.1f} | {a['c3']:.0f}% | {a['mx']} |", flush=True)
    finally:
        C.CAP_CURVE = base; V.reset()

if __name__ == "__main__":
    main()
