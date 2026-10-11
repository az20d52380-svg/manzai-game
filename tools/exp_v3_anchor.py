#!/usr/bin/env python3
"""v3 経済での帯の基準線（今の式・今のライン）。usage: python3 exp_v3_anchor.py [n]
eval_axes_design_v0 §1-1／§8-1。数値は全て【仮】。"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    V.apply()
    try:
        for pol in (PNeedV3(), PRotate(), PCasual2()):
            wins = finals = 0
            for i in range(n):
                first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
                wins += first is not None
                finals += ever_final
            print(f"{pol.name:<8} 初回優勝 {100*wins/n:5.2f}% 決勝到達 {100*finals/n:5.1f}%", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
