#!/usr/bin/env python3
# 【動かない・10/19 確認】知名度の式が balance_sim に移り C.FAME_OTHER_MULT が無い。結果は当時の docs に記録済み＝再実行するなら直してから。
# -*- coding: utf-8 -*-
"""
【注 2026-10-15】ブランチ q60-62-impl 以降は知名度の逓減が balance_sim.add に移り、ここの C.FAME_OTHER_MULT 等の差し替えは効かない（結果は docs/q60_q62_proposal_v0.md に記録済み）。
キュー62 知名度（2026-10-15 オーナー決定）の試算：徐々に上がる＋決勝で一気に＋他は小さく逓減。
使い方: python3 exp_fame62.py [キャリア数]（既定300）。数値は全て【仮】。ネタ無し／ネタ込み（NETA_V2）を併記。
"""
import statistics, sys
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

OFFER_NOW = list(B.OFFER_RATES)
OFFER_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
CONFIGS = [("今", dict(), OFFER_NOW)] + [
    (f"v62 他×{m}・決勝+{f}・優勝+{c}・区切り10/30/55", dict(FAME_V62=True, FAME_OTHER_MULT=m, FAME_FINALIST=f, FAME_CHAMP=c), OFFER_NEW)
    for m, f, c in ((1.0, 30, 30), (0.6, 30, 30), (0.6, 40, 40), (0.4, 40, 40))]
KEYS = ("FAME_V62", "FAME_OTHER_MULT", "FAME_FINALIST", "FAME_CHAMP")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    saved = {k: getattr(C, k) for k in KEYS}
    saved_neta = (C.NETA_ON, C.NETA_V2)
    orig_run_year = C.run_year
    log = {}
    def run_year(pol, s, year, rng, **kw):
        r = orig_run_year(pol, s, year, rng, **kw)
        log.setdefault(year, []).append(s.fame)
        return r
    C.run_year = run_year
    V.apply(); C.EVENTS_ON = True
    print(f"=== 知名度 v62 | {n}キャリア | 全て【仮】| 知名度は年末の中央値（80以上の割合）・優勝時の知名度 ===")
    try:
        for neta in (False, True):
            C.NETA_ON = C.NETA_V2 = neta
            for label, flags, offer in CONFIGS:
                for k in KEYS:
                    setattr(C, k, flags.get(k, saved[k]))
                B.OFFER_RATES = offer
                for pol in (PCasual2(), PRotate(), PNeedV3()):
                    log.clear()
                    wins, finals, wfame = 0, 0, []
                    for i in range(n):
                        first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i)
                        if first is not None:
                            wins += 1; wfame.append(s.fame)
                        finals += ever
                    def yr(y):
                        v = log.get(y, [])
                        return f"{statistics.median(v):.0f}({100*sum(x>=80 for x in v)/len(v):.0f}%)" if v else "-"
                    wf = f"{statistics.median(wfame):.0f}" if wfame else "-"
                    print(f"{'ネタ込み' if neta else 'ネタ無し'}｜{label}｜{pol.name}｜優勝 {100*wins/n:.1f}% 決勝 {100*finals/n:.1f}%｜知名度 1年{yr(1)} 2年{yr(2)} 3年{yr(3)} 5年{yr(5)} 10年{yr(10)}｜優勝時 {wf}")
    finally:
        V.reset(); C.run_year = orig_run_year; B.OFFER_RATES = OFFER_NOW
        for k, v in saved.items(): setattr(C, k, v)
        C.NETA_ON, C.NETA_V2 = saved_neta

if __name__ == "__main__":
    main()
