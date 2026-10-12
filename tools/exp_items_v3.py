#!/usr/bin/env python3
"""アイテムを使う／使わないで帯と所持金を比べる（今の式・今のライン）。usage: python3 exp_items_v3.py [n]
item_design_v0 §4。購入は乱数を引かないので、同じ seed で「使わない」と1対1比較できる。数値は全て【仮】。"""
import sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

RESERVE = 300_000   # 家賃・遠征のために残す額【仮】
ORDER = ["中古のICレコーダー", "ネタ作家の勉強会", "ボイトレ短期集中", "新幹線回数券", "稽古場の年契約"]

class Shopper:
    """元の方針の choose の前に、使える時に使う（安い順の消耗品→投資）"""
    def __init__(self, base):
        self.base = base
        self.name = base.name + "＋買う"
        self.spent = 0
    def __getattr__(self, k):
        return getattr(self.base, k)
    def _buy(self, s, it):
        p = B.ITEMS[it][0]
        if B.buy_item(s, it):
            self.spent += p
    def choose(self, s, week, offer, rng):
        if s.stamina < 40 and s.money >= 3_000 + 50_000:
            self._buy(s, "栄養ドリンク")
        if not getattr(s, "sento_tickets", None) and s.money >= 10_000 + 100_000:
            self._buy(s, "銭湯の回数券")
        for it in ORDER:
            if s.money >= B.ITEMS[it][0] + RESERVE:
                self._buy(s, it)
        return self.base.choose(s, week, offer, rng)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    try:
        for mk in (PNeedV3, PRotate, PCasual2):
            for pol in (mk(), Shopper(mk())):
                wins = finals = 0; money = 0.0; yrs = []
                for i in range(n):
                    first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
                    wins += first is not None; finals += ever_final; money += s.money
                    if first is not None: yrs.append(first)
                yrs.sort()
                med = yrs[len(yrs)//2] if yrs else "-"
                extra = f" 購入計/人 {getattr(pol,'spent',0)/n/10000:6.1f}万" if hasattr(pol, "spent") else ""
                print(f"{pol.name:<12} 初回優勝 {100*wins/n:5.2f}%（中央{med}年） 決勝到達 {100*finals/n:5.1f}% 最終所持金 {money/n/10000:7.1f}万{extra}", flush=True)
    finally:
        V.reset()

if __name__ == "__main__":
    main()
