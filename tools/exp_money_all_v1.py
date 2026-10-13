#!/usr/bin/env python3
"""お金の使い道を全部有効にした時の帯（練習の場所・教室・有料の休み）。usage: python3 exp_money_all_v1.py [n] [喫茶店の値段 サウナの値段]
money_items_neta_v1 §6。のんびり・ローテは「喫茶店＋有料休み」に差し替え、やり込みは場所・教室を自分で選び有料休みも使う。【仮】"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate
from exp_places_v1 import Cafe, run
from exp_rests_v1 import Spa

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    if len(sys.argv) > 3:   # 値段の案（既定は balance_sim の値）
        B.PLACE_TRAININGS["喫茶店で書く"] = dict(B.PLACE_TRAININGS["喫茶店で書く"], cost=int(sys.argv[2]))
        B.REST_COST["サウナ"] = int(sys.argv[3])
    V.apply()
    try:
        for on in ((True,) if len(sys.argv) > 3 else (False, True)):
            B.enable_places(on); B.enable_paid_rests(on)
            bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
            bots = (PCasual2(), PRotate(), PNeedV3()) if not on else (Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), Spa(PNeedV3()))
            for pol in bots:
                w, f, m = run(pol, n)
                print(f"{'全部あり' if on else 'なし'}\t{pol.name}\t初回優勝{w:.1f}%\t決勝到達{f:.1f}%\t最終所持金{m:.0f}万", flush=True)
    finally:
        B.enable_places(False); B.enable_paid_rests(False)
        bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
        V.reset()

if __name__ == "__main__":
    main()
