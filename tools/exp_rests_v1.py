#!/usr/bin/env python3
"""お金を払う休み（サウナ・温泉）の帯への効き。usage: python3 exp_rests_v1.py [n] [サウナ回復 温泉回復 サウナ値段 温泉値段]
money_items_neta_v1 §6。休むを選んだ時、残高に余裕があれば サウナ（体力30未満なら温泉）に差し替える。数値は全て【仮】。"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

RESERVE = 300_000

class Spa:
    def __init__(self, base):
        self.base = base; self.name = base.name + "＋有料休み"
    def __getattr__(self, k):
        return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        act, arg = self.base.choose(s, week, offer, rng)
        if act == "rest" and arg == "完全休養":
            if s.stamina < 30 and s.money >= B.REST_COST["温泉に一泊"] + RESERVE:
                return ("rest", "温泉に一泊")
            if s.money >= B.REST_COST["サウナ"] + RESERVE:
                return ("rest", "サウナ")
        return (act, arg)

def run(pol, n):
    w = f = 0; money = 0.0
    for i in range(n):
        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
        w += first is not None; f += ever_final; money += s.money
    return 100 * w / n, 100 * f / n, money / n / 10000

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    if len(sys.argv) > 5:   # 値の案を試す（既定値は balance_sim の PAID_RESTS/REST_COST）
        sr, orc, sc, oc = (int(x) for x in sys.argv[2:6])
        B.PAID_RESTS["サウナ"] = (sr, B.PAID_RESTS["サウナ"][1]); B.PAID_RESTS["温泉に一泊"] = (orc, B.PAID_RESTS["温泉に一泊"][1])
        B.REST_COST.update({"サウナ": sc, "温泉に一泊": oc})
    V.apply()
    try:
        for on in ((True,) if len(sys.argv) > 5 else (False, True)):
            B.enable_paid_rests(on)
            for mk in (PCasual2, PRotate, PNeedV3):
                pol = Spa(mk()) if on else mk()
                w, f, m = run(pol, n)
                print(f"{'有料休みあり' if on else 'なし'}\t{pol.name}\t初回優勝{w:.1f}%\t決勝到達{f:.1f}%\t最終所持金{m:.0f}万", flush=True)
    finally:
        B.enable_paid_rests(False)
        V.reset()

if __name__ == "__main__":
    main()
