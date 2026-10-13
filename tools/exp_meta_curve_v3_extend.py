#!/usr/bin/env python3
"""dynasty_v2_research §8 の残り「延長年の上限」を実測：式案 cfg_r2 ＋(A) の上で、延長の型（無冠k年で勇退・上限Y年）を変える。決定ではない・数値は全て【仮】。
usage: python3 exp_meta_curve_v3_extend.py [n] [m,m,...]
設定は exp_meta_curve_v3_opts（予選から・トロフィー上限カーブ +0.02·T）と同じ。式・GameCore は触らない。"""
import sys, os, json, statistics
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3_opts import career

EXTENDS = ((3, 25), (2, 20), (1, 15), (3, 15), (0, 10))  # (0,10)＝延長なし（全員10年）

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    ms = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else (0.67, 1.0)
    here = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, os.path.join(here, "exp_eval_axes"))
    import proto as P
    P.CFG.update(json.load(open(os.path.join(here, "exp_eval_axes", "cfg_r2.json")))); P.install(); P.install_rec()
    V.apply()
    base_curve = C.CAP_CURVE
    try:
        for m in ms:
            J0 = 44 * m ** 2.6
            C.CAP_CURVE = (base_curve[0] + 0.02 * 30 * m, base_curve[1], base_curve[2])
            for ext in EXTENDS:
                pol = PNeedV3(); res = [career(pol, C.BASE_SEED + i, J0, "A", extend=ext) for i in range(n)]
                fy = [r[0] for r in res if r[0]]
                ch = max(len(fy), 1)
                aw = sum(r[1] for r in res if r[0]) / ch
                ew = sum(r[3] for r in res if r[0]) / ch
                c3 = sum(1 for r in res if r[2] >= 3) / ch
                mx = max((r[2] for r in res), default=0)
                print(f"m={m:.2f} 延長 無冠{ext[0]}年で勇退・上限{ext[1]}年 | 王者の平均優勝 {aw:.2f}（うち延長年 {ew:.2f}） 3連覇+ {100*c3:.0f}% 最長 {mx}", flush=True)
    finally:
        C.CAP_CURVE = base_curve
        V.reset()

if __name__ == "__main__":
    main()
