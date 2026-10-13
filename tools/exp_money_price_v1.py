#!/usr/bin/env python3
"""money_items_neta_v1 判断待ち「お金の吸い込み口」の材料：有料の行動の値段を f 倍にした時の帯と最終所持金（決定ではない・数値は全て【仮】）。
usage: python3 exp_money_price_v1.py [n] [倍率,...] [年の回数上限（0=なし）]
exp_money_cap_v1 と同じボット（全部あり）。値段だけ PLACE_TRAININGS の cost と REST_COST を f 倍にする（測った後に戻す）。"""
import sys
import copy
import balance_sim as B
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate
from exp_places_v1 import Cafe, run
from exp_rests_v1 import Spa
from exp_money_cap_v1 import Cap

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    fs = [float(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else [1, 3, 5]
    k = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    places0, rest0 = copy.deepcopy(B.PLACE_TRAININGS), dict(B.REST_COST)
    V.apply()
    try:
        for f in fs:
            for name, d in B.PLACE_TRAININGS.items():
                d["cost"] = int(places0[name]["cost"] * f)
            for name in B.REST_COST:
                B.REST_COST[name] = int(rest0[name] * f)
            B.enable_places(True); B.enable_paid_rests(True)
            bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
            pols = (Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), Spa(PNeedV3()))
            if k > 0:
                pols = tuple(Cap(p, k, 48) for p in pols)
            for pol in pols:
                w, fn, m = run(pol, n)
                print(f"値段{f:g}倍\t上限{k or 'なし'}\t{pol.name}\t初回優勝{w:.1f}%\t決勝到達{fn:.1f}%\t最終所持金{m:.0f}万", flush=True)
    finally:
        for name, d in B.PLACE_TRAININGS.items():
            d["cost"] = places0[name]["cost"]
        B.REST_COST.update(rest0)
        B.enable_places(False); B.enable_paid_rests(False)
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        V.reset()

if __name__ == "__main__":
    main()
