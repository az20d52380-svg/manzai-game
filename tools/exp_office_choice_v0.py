#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""事務所を選べる案の帯実測（docs/office_choice_v0.md §3）。usage: python3 exp_office_choice_v0.py [n]
本体は変えない：B/C のモジュール変数を実行中だけ差し替えて戻す。新しい乱数なし（既存の式の倍率だけ）。値は全て【仮】。
倍率：offer_income（取り分＝オファー収入）／offer_rate（オファー発生率）／offer_fame（オファーの知名度加算）／
butai_cost（ネタ見せ会の費用）／live_fame（フリーライブの知名度）／stipend（4週ごとの月給＝生活費の軽減）"""
import copy, statistics, sys
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

OFFICES = {
    "中堅(いまの基準)": {},
    "大手":   dict(offer_income=0.6, offer_rate=1.10, offer_fame=1, butai_cost=40_000, live_fame=1, stipend=20_000),
    "小":     dict(offer_income=1.2, offer_rate=0.90, butai_cost=60_000, stipend=0),
    "フリー": dict(offer_income=2.0, offer_rate=0.75, butai_cost=100_000, stipend=0),
    # 参考（極端側の感度）
    "参考:大手の月給0": dict(offer_income=0.6, offer_rate=1.10, offer_fame=1, butai_cost=40_000, live_fame=1, stipend=0),
    "参考:フリー率半減": dict(offer_income=2.0, offer_rate=0.50, butai_cost=100_000, stipend=0),
}

def apply(m):
    sv = dict(OM=dict(B.OFFER_MONEY), OE=dict(B.OFFER_EXP), OR=list(B.OFFER_RATES), TR=copy.deepcopy(B.TRAININGS), LC=B.LIVING_COST)
    for o in (B.OFFER_MONEY, B.OFFER_EXP):
        o["income"] = int(o["income"] * m.get("offer_income", 1.0))
        o["fame"] += m.get("offer_fame", 0)
    B.OFFER_RATES = [(c, r * m.get("offer_rate", 1.0)) for c, r in B.OFFER_RATES]
    if "butai_cost" in m: B.TRAININGS["ネタ見せ会"]["cost"] = m["butai_cost"]
    if "live_fame" in m: B.TRAININGS["フリーライブ"]["fame"] += m["live_fame"]
    B.LIVING_COST -= m.get("stipend", 0)
    return sv

def restore(sv):
    B.OFFER_MONEY, B.OFFER_EXP, B.OFFER_RATES, B.TRAININGS, B.LIVING_COST = sv["OM"], sv["OE"], sv["OR"], sv["TR"], sv["LC"]

def run(pol, n):
    w = f = bk = ds = 0; money = []; wy = []
    for i in range(n):
        first, s, _st, ef = C.run_career(pol, C.BASE_SEED + i)
        w += first is not None; f += ef
        bk += bool(getattr(s, "_bankrupt", False)); ds += bool(getattr(s, "_dissolved", False))
        money.append(s.money)
        if first: wy.append(first)
    return 100*w/n, 100*f/n, 100*bk/n, 100*ds/n, statistics.median(money)/10000

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    V.apply()
    sn, sv2 = C.NETA_ON, C.NETA_V2
    try:
        for neta in (False, True):
            C.NETA_ON = C.NETA_V2 = neta
            for name, m in OFFICES.items():
                sv = apply(m)
                try:
                    for pol in (PCasual2(), PRotate(), PNeedV3()):
                        w, f, bk, ds, mo = run(pol, n)
                        print(f"{'ネタ込み' if neta else 'ネタ無し'}\t{name}\t{pol.name}\t優勝{w:.1f}\t決勝{f:.1f}\t夜逃げ{bk:.1f}\t解散{ds:.1f}\t所持金中央{mo:.0f}万", flush=True)
                finally:
                    restore(sv)
    finally:
        V.reset(); C.NETA_ON, C.NETA_V2 = sn, sv2

if __name__ == "__main__":
    main()
