#!/usr/bin/env python3
"""王者編：「全員15年」で決勝ライン（＋敗者復活）を何点上げれば初回優勝が帯（2〜4%）に戻るか。
usage: python3 exp_dynasty_v4.py [n] [cfg.json] [offsets]  例: python3 exp_dynasty_v4.py 300 exp_eval_axes/cfg_r2.json 0,4,8,12
予選から・延長なし。決勝と敗者復活を同じ点数だけ上げる（復活=決勝-4 の関係を保つ）。
決定ではなく材料（docs/dynasty_v2_research_v0.md §2-3）。数値は全て【仮】。"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "exp_eval_axes"))
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
import exp_dynasty_v2 as D

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    tag = "今の式"
    if len(sys.argv) > 2 and sys.argv[2] != "-":
        import proto as P
        P.CFG.update(json.load(open(sys.argv[2]))); P.install(); P.install_rec(); tag = "式案"
    offs = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0, 4, 8, 12]
    V.apply()
    f0, r0 = C.GP_FINAL_LINE, C.GP_REVIVAL_LINE
    try:
        for years in (10, 15):
            C.YEARS = years
            for d in (offs if years == 15 else [0]):
                C.GP_FINAL_LINE, C.GP_REVIVAL_LINE = f0 + d, r0 + d
                pol = PNeedV3(); firsts = 0; yrs = []
                for i in range(n):
                    f, w, b = D.career(pol, C.BASE_SEED + i, "予選から", None)
                    if f is not None:
                        firsts += 1; yrs.append(f)
                med = sorted(yrs)[len(yrs) // 2] if yrs else "-"
                print(f"{tag}\t{years}年\t決勝+{d}\t初回優勝{100*firsts/n:.1f}%\t初優勝の年(中央){med}", flush=True)
    finally:
        C.GP_FINAL_LINE, C.GP_REVIVAL_LINE = f0, r0
        C.YEARS = 10
        V.reset()

if __name__ == "__main__":
    main()
