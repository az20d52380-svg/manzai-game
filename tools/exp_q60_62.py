#!/usr/bin/env python3
# 【動かない・10/19 確認】知名度の式が balance_sim に移り C.FAME_OTHER_MULT が無い。結果は当時の docs に記録済み＝再実行するなら直してから。
# -*- coding: utf-8 -*-
"""
【注 2026-10-15】ブランチ q60-62-impl 以降は知名度の逓減が balance_sim.add に移り、ここの C.FAME_OTHER_MULT 等の差し替えは効かない（結果は docs/q60_q62_proposal_v0.md に記録済み）。
キュー60（ネタの年またぎの飽き）×キュー62（知名度 v62）の組み合わせ試算（2026-10-15）。
使い方: python3 exp_q60_62.py [キャリア数]（既定1000）。全てネタ込み（アプリ同式 NETA_V2）・数値は全て【仮】。
飽き＝案D：大会で掛けた年の数×1点を補正から引く・上限2点・寝かせても戻らない（新ネタは0から）。
"""
import statistics, sys
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

OFFER_NOW = list(B.OFFER_RATES)
OFFER_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
D = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2)
CONFIGS = [
    (f"飽きD＋知名度G 他×{m}・頭打ち{cap}・決勝+30・優勝+{c}（逓減なし）",
     dict(D, FAME_V62=True, FAME_OTHER_MULT=m, FAME_OTHER_CAP=float(cap), FAME_FINALIST=30.0, FAME_CHAMP=c, FAME_CHAMP_FLAT=True), OFFER_NEW)
    for m, cap, c in ((0.6, 80, 10), (1.0, 80, 10), (0.6, 70, 15))]

KEYS = ("V2_TIRED_PEN", "V2_TIRED_CAP", "V2_TIRED_NEW", "FAME_V62", "FAME_OTHER_MULT", "FAME_FINALIST", "FAME_CHAMP", "FAME_OTHER_CAP", "FAME_CHAMP_FLAT")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    saved = {k: getattr(C, k) for k in KEYS}
    orig = C.run_year
    log, fin = {}, []
    def run_year(pol, s, year, rng, **kw):
        r = orig(pol, s, year, rng, **kw)
        log.setdefault(year, []).append(s.fame)
        if r[2] and not getattr(s, "_fin_logged", False):   # 初めて決勝に出た年の年末の知名度
            s._fin_logged = True
            fin.append((year, s.fame))
        return r
    C.run_year = run_year
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    print(f"=== キュー60×62 | {n}キャリア | ネタ込み | 全て【仮】| 知名度=年末中央値 ===")
    try:
        for label, flags, offer in CONFIGS:
            for k in KEYS:
                setattr(C, k, flags.get(k, saved[k]))
            B.OFFER_RATES = offer
            for pol in (PCasual2(), PRotate(), PNeedV3()):
                log.clear(); fin.clear()
                wins, finals, wf = 0, 0, []
                for i in range(n):
                    first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i)
                    if first is not None:
                        wins += 1; wf.append(s.fame)
                    finals += ever
                med = lambda v: f"{statistics.median(v):.0f}" if v else "-"
                y1 = [f for y, f in fin if y == 1]
                print(f"{label}｜{pol.name}｜優勝 {100*wins/n:.1f}% 決勝 {100*finals/n:.1f}%｜知名度 1年{med(log.get(1))} 3年{med(log.get(3))} 5年{med(log.get(5))} 10年{med(log.get(10))}｜初決勝の年末 {med([f for _, f in fin])}（1年目で決勝 {len(y1)}組 {med(y1)}）｜優勝時 {med(wf)}")
    finally:
        V.reset(); C.run_year = orig; B.OFFER_RATES = OFFER_NOW
        for k, v in saved.items(): setattr(C, k, v)

if __name__ == "__main__":
    main()
