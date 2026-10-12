#!/usr/bin/env python3
"""アイテムの内訳：1品ずつ外す／1品だけ使う で帯を比べる。usage: python3 exp_items_v4.py [n]
exp_items_v3 の Shopper を流用。1行=1条件。数値は全て【仮】。"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3
import exp_items_v3 as E

ALL = E.ORDER + ["栄養ドリンク", "銭湯の回数券"]

class Limited(E.Shopper):
    def __init__(self, base, allowed):
        super().__init__(base); self.allowed = set(allowed)
    def _buy(self, s, it):
        if it in self.allowed: super()._buy(s, it)

def run(pol, n):
    wins = finals = 0
    for i in range(n):
        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
        wins += first is not None; finals += ever_final
    return 100*wins/n, 100*finals/n, pol.spent/n/10000

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    try:
        for mk in (PCasual2, PNeedV3):
            conds = [("全部", ALL)] + [(f"−{it}", [x for x in ALL if x != it]) for it in ALL] + [(f"{it}だけ", [it]) for it in ALL]
            for label, allowed in conds:
                w, f, sp = run(Limited(mk(), allowed), n)
                print(f"{mk().name}\t{label}\t優勝{w:.1f}%\t決勝{f:.1f}%\t購入{sp:.0f}万", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
