#!/usr/bin/env python3
"""練習の場所（喫茶店・ファミレスで書く）の帯への効き。usage: python3 exp_places_v1.py [n]
money_items_neta_v1 §6。場所なし／あり を同じ seed で比べる。のんびり・ローテは「残高30万以上なら家→喫茶店」に差し替え、
v3やり込みは場所込みの ISSUE で自分で選ぶ。数値は全て【仮】。"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

RESERVE = 300_000

class Cafe:
    def __init__(self, base):
        self.base = base; self.name = base.name + "＋喫茶店"
    def __getattr__(self, k):
        return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        act, arg = self.base.choose(s, week, offer, rng)
        if act == "train" and arg == "ネタ作り" and s.money >= B.TRAININGS["喫茶店で書く"]["cost"] + RESERVE:
            return ("train", "喫茶店で書く")
        return (act, arg)

def run(pol, n):
    w = f = 0; money = 0.0
    for i in range(n):
        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
        w += first is not None; f += ever_final; money += s.money
    return 100 * w / n, 100 * f / n, money / n / 10000

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    try:
        for on in (False, True):
            B.enable_places(on)
            bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
            for pol in ((PCasual2(), PRotate(), PNeedV3()) if not on else (Cafe(PCasual2()), Cafe(PRotate()), PNeedV3())):
                w, f, m = run(pol, n)
                print(f"{'場所あり' if on else '場所なし'}\t{pol.name}\t初回優勝{w:.1f}%\t決勝到達{f:.1f}%\t最終所持金{m:.0f}万", flush=True)
    finally:
        B.enable_places(False)
        bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
        V.reset()

if __name__ == "__main__":
    main()
