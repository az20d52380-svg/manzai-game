#!/usr/bin/env python3
"""交換（案D・正典 recommended_plan 内）＋供給の再較正の実測。usage: python3 exp_ability_exchange_v0.py [n=1000]
式は変えない（EXCHANGE_ON / EXP_SUPPLY_SCALE をワーカー内で差し替えるだけ）。数値は全て【仮】。
①詰まり: exp_ability_stall_v0 の measure（auto＝おまかせ・NETA込みの「今」案）
②帯: exp_balance_snapshot_v0 の one（NETA込み・10年・エンディング）＝docs/balance_snapshot_2026-10-16.md と同条件"""
import sys
from multiprocessing import Pool
BASE = 0.48
CONFIGS = [("今(交換なし)×1.0", False, 1.0), ("交換×0.5", True, 0.5), ("交換×0.55", True, 0.55), ("交換×0.6", True, 0.6), ("交換×0.7(参考)", True, 0.7)]

def setp(ex, sc):
    import balance_sim as B
    B.EXCHANGE_ON = ex; B.EXP_SUPPLY_SCALE = BASE * sc

def stall_job(args):
    tag, ex, sc, bi, n = args
    setp(ex, sc)
    import exp_ability_stall_v0 as X, balance_sim as B, sim_career as C, canon_v2 as V, bots_v3
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    for k, v in X.PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = X.OFFER_NEW; B.enable_places(True); B.enable_paid_rests(True)
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    bots = [X.Spa(X.Cafe(X.PCasual2())), X.Spa(X.Cafe(X.PRotate())), C.CareerBalanced(), C.CareerSmart()]
    r = X.measure(bots[bi], n, "auto", "A")
    return tag, bots[bi].name, r

def band_job(args):
    tag, ex, sc, name, n = args
    setp(ex, sc)
    import exp_balance_snapshot_v0 as S
    neta, nm, R_, jw = S.one((True, name, n))
    k = len(R_)
    return tag, nm, dict(fin=100*sum(r["fin"] for r in R_)/k, win=100*sum(r["win"] is not None for r in R_)/k,
                         bk=100*sum(r["bk"] for r in R_)/k, ds=100*sum(r["ds"] for r in R_)/k)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    sj = [(t, e, s, b, n) for t, e, s in CONFIGS for b in range(4)]
    bj = [(t, e, s, nm, n) for t, e, s in CONFIGS for nm in ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]]
    with Pool(10) as p:
        rs = p.map(stall_job, sj); rb = p.map(band_job, bj)
    print(f"# n={n} 詰まり=週末に経験点>=5・伸び余地あり・押せる＋0（おまかせ・NETA込み）")
    for tag, nm, r in rs:
        print(f"STALL|{tag}|{nm}|st_y1={r['st_y1']:.1f}|st_y13={r['st_y13']:.1f}|slen={r['slen']:.1f}|j1={r['j1']:.1f}|j3={r['j3']:.1f}|"
              f"bal={'/'.join(f'{x:.1f}' for x in r['bal'])}|ab3={'/'.join(f'{x:.0f}' for x in r['ab3'])}|fin={r['fin']:.1f}|win={r['win']:.1f}|ds={r['ds']:.1f}")
    for tag, nm, r in rb:
        print(f"BAND|{tag}|{nm}|fin={r['fin']:.1f}|win={r['win']:.1f}|bk={r['bk']:.1f}|ds={r['ds']:.1f}")

if __name__ == "__main__":
    main()
