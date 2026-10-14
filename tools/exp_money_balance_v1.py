#!/usr/bin/env python3
"""キュー61 お金の使い道の釣り合い（バイト vs ネタ・練習）の実測。数値は全て【仮】・決定ではない。
usage: python3 exp_money_balance_v1.py [n] [案名,...]   既定値は変えず、実験の中だけで値を差し替えて戻す。
前提＝ネタ込み(NETA_V2・飽きD)＋知名度案G＋EVENTS_ON＋お金の使い道 全部あり(回数上限なし)。
出力: 優勝％/決勝％/10年目の所持金中央値(10年目まで残った人)/最終所持金中央値/バイトの週の割合/有料の行動の週の割合/アイテム支出"""
import sys, copy, statistics
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate
from exp_places_v1 import Cafe
from exp_rests_v1 import Spa

OFFER_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
PRE = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2, FAME_V62=True, FAME_OTHER_MULT=0.6, FAME_OTHER_CAP=80.0,
           FAME_FINALIST=30.0, FAME_CHAMP=10, FAME_CHAMP_FLAT=True)
KEYS = list(PRE) + ["V2_TIRED_NEW"]
RESERVE_DEFAULT = 300_000

# 案: job=バイト収入倍率, price=有料の行動の値段倍率, living=生活費倍率, eff=有料の効果倍率, offer=オファー収入倍率, items=アイテム支出リスト
SCEN = {
    "今": dict(),
    "A バイト収入×0.6": dict(job=0.6, offer=0.6),
    "A2 バイト収入×0.75": dict(job=0.75, offer=0.75),
    "B 値段×3": dict(price=3),
    "B2 値段×5": dict(price=5),
    "C 生活費×1.5": dict(living=1.5),
    "C2 生活費×2": dict(living=2.0),
    "D 有料効果×0.6": dict(eff=0.6),
    "E バイト×0.75＋値段×3": dict(job=0.75, offer=0.75, price=3),
    "F 生活費×1.5＋値段×3": dict(living=1.5, price=3),
    "G バイト×0.75＋生活費×1.5": dict(job=0.75, offer=0.75, living=1.5),
}
# アイテム案(吸い込み口・帯に効かない見た目/人気/物語): (名前, 値段, 買う条件の残高余裕)
ITEMS = [("衣装(ステージ)", 300_000), ("小道具セット", 150_000), ("単独ライブ(小箱)", 800_000),
         ("単独ライブ(中箱)", 2_000_000), ("劇場の会場費(大ホール)", 5_000_000), ("作家への依頼(読み物)", 1_000_000)]
SCEN["J バイト×0.75＋生活費×1.5＋値段×3"] = dict(job=0.75, offer=0.75, living=1.5, price=3)
SCEN["K G＋アイテム6種"] = dict(job=0.75, offer=0.75, living=1.5, items=ITEMS)
SCEN["L バイト×0.8＋生活費×1.4＋アイテム6種"] = dict(job=0.8, offer=0.8, living=1.4, items=ITEMS)
SCEN["H アイテム6種(支出のみ)"] = dict(items=ITEMS)
SCEN["I バイト×0.75＋値段×3＋アイテム6種"] = dict(job=0.75, offer=0.75, price=3, items=ITEMS)

class Buy:
    """アイテムを順に買う(残高が値段＋余裕を超えたら1つ。能力には効かせない＝支出のみ)"""
    def __init__(self, base, items):
        self.base = base; self.name = base.name; self.items = items; self.sid = None; self.i = 0
    def __getattr__(self, k):
        return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        if self.sid != id(s):
            self.sid = id(s); self.i = 0
        if self.i < len(self.items) and week % 4 == 0:
            nm, pr = self.items[self.i]
            if s.money >= pr + RESERVE_DEFAULT:
                s.money -= pr; self.i += 1; s._item_spent = getattr(s, "_item_spent", 0) + pr
        return self.base.choose(s, week, offer, rng)

CNT = dict(job=0, train=0, rest=0, offer=0, paid=0)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    names = sys.argv[2].split(",") if len(sys.argv) > 2 else list(SCEN)
    saved = {k: getattr(C, k) for k in KEYS}
    jobs0, offer0 = dict(B.JOBS), (dict(B.OFFER_MONEY), dict(B.OFFER_EXP))
    places0, rest0, living0 = copy.deepcopy(B.PLACE_TRAININGS), dict(B.REST_COST), B.LIVING_COST
    pr0, tr0 = dict(B.PAID_RESTS), copy.deepcopy(B.TRAININGS)
    offr0 = list(B.OFFER_RATES)
    o_job, o_tr, o_rest, o_off = B.do_job, B.do_training, B.do_rest, B.do_offer
    def d_job(s, nm): CNT["job"] += 1; return o_job(s, nm)
    def d_tr(s, nm):
        r = o_tr(s, nm)
        if r: CNT["train"] += 1; CNT["paid"] += B.TRAININGS[nm]["cost"] > 0
        return r
    def d_rest(s, nm): CNT["rest"] += 1; CNT["paid"] += B.REST_COST.get(nm, 0) > 0; return o_rest(s, nm)
    def d_off(s, o): CNT["offer"] += 1; return o_off(s, o)
    B.do_job, B.do_training, B.do_rest, B.do_offer = d_job, d_tr, d_rest, d_off
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    for k, v in PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = OFFER_NEW
    try:
        for nm in names:
            sc = SCEN[nm]
            f = sc.get("job", 1); fo = sc.get("offer", 1); fp = sc.get("price", 1); fl = sc.get("living", 1); fe = sc.get("eff", 1)
            B.JOBS.clear(); B.JOBS.update({k: (int(v[0] * f), v[1]) for k, v in jobs0.items()})
            B.OFFER_MONEY["income"] = int(offer0[0]["income"] * fo); B.OFFER_EXP["income"] = int(offer0[1]["income"] * fo)
            B.LIVING_COST = int(living0 * fl)
            B.enable_places(True); B.enable_paid_rests(True)
            for k, v in B.PLACE_TRAININGS.items():
                d = copy.deepcopy(places0[k]); d["cost"] = int(d["cost"] * fp)
                d["main"] = (d["main"][0], d["main"][1] * fe)
                if d["sub"]: d["sub"] = (d["sub"][0], d["sub"][1] * fe)
                B.PLACE_TRAININGS[k] = d; B.TRAININGS[k] = d
            for k in B.REST_COST:
                B.REST_COST[k] = int(rest0[k] * fp)
                rec, eff = pr0[k]; B.PAID_RESTS[k] = (rec * fe if fe != 1 else rec, eff); B.RESTS[k] = B.PAID_RESTS[k]
            bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
            items = sc.get("items")
            pols = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), Spa(PNeedV3())]
            if items: pols = [Buy(p, items) for p in pols]
            for pol in pols:
                for k in CNT: CNT[k] = 0
                w = fin = 0; m10 = []; mf = []; sp = []
                for i in range(n):
                    ml = [[] for _ in range(C.YEARS)]
                    first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
                    w += first is not None; fin += ever; mf.append(s.money); sp.append(getattr(s, "_item_spent", 0))
                    m10 += ml[9]
                tot = CNT["job"] + CNT["train"] + CNT["rest"] + CNT["offer"]
                med = lambda v: f"{statistics.median(v)/10000:.0f}万" if v else "-"
                print(f"{nm}\t{pol.name}\t優勝{100*w/n:.1f}%\t決勝{100*fin/n:.1f}%\t10年目所持金{med(m10)}\t最終{med(mf)}\tバイト{100*CNT['job']/tot:.0f}%\t有料{100*CNT['paid']/tot:.0f}%\tアイテム{statistics.mean(sp)/10000:.0f}万", flush=True)
    finally:
        B.do_job, B.do_training, B.do_rest, B.do_offer = o_job, o_tr, o_rest, o_off
        B.JOBS.clear(); B.JOBS.update(jobs0)
        B.OFFER_MONEY.update(offer0[0]); B.OFFER_EXP.update(offer0[1])
        B.LIVING_COST = living0
        B.enable_places(False); B.enable_paid_rests(False)
        for k, v in places0.items(): B.PLACE_TRAININGS[k] = v
        B.REST_COST.update(rest0); B.PAID_RESTS.update(pr0)
        B.OFFER_RATES = offr0
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        V.reset()
        for k, v in saved.items(): setattr(C, k, v)

if __name__ == "__main__":
    main()
