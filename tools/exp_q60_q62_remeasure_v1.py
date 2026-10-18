#!/usr/bin/env python3
"""キュー60(ネタの飽き)×キュー62(知名度)案の測り直し（docs/q60_q62_remeasure_v1.md）。
全部入り(部屋+アイテム+特技)・ネタ込み・EVENTS_APP False/True。exp_money_after_merge_v0.one を呼ぶ（本体の既定は変えない。上書きは子プロセス内だけ）。
usage: python3 exp_q60_q62_remeasure_v1.py [n=300] [cfg名,...]   cfg名を絞ると n=1000 の追い測りができる"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import exp_balance_snapshot_v0 as S
import exp_money_after_merge_v0 as M

OFF_OLD = [(20, 0.05), (50, 0.15), (80, 0.30), (999, 0.50)]
OFF_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
TIRED0 = dict(V2_TIRED_PEN=0.0)
TIREDD = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2)
TIREDE = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2, V2_TIRED_REST_YEARS=3)
FAME_OLD = dict(c=dict(FAME_V62=False, FAME_CHAMP=20), b=dict(FAME_OTHER_MULT=1.0, FAME_OTHER_CAP=1e9), off=OFF_OLD)
def fame_g(m, cap=80.0): return dict(c=dict(FAME_V62=True, FAME_FINALIST=30.0, FAME_CHAMP=10, FAME_CHAMP_FLAT=True), b=dict(FAME_OTHER_MULT=m, FAME_OTHER_CAP=cap), off=OFF_NEW)
FAME_V62 = dict(c=dict(FAME_V62=True, FAME_FINALIST=30.0, FAME_CHAMP=30, FAME_CHAMP_FLAT=False), b=dict(FAME_OTHER_MULT=0.6, FAME_OTHER_CAP=1e9), off=OFF_NEW)
CFGS = {
    "旧(飽き無・知名度旧)":      (TIRED0, FAME_OLD),
    "Dのみ":                     (TIREDD, FAME_OLD),
    "Gのみ(他x0.6)":             (TIRED0, fame_g(0.6)),
    "D+G他x0.6(現状=推奨)":      (TIREDD, fame_g(0.6)),
    "E3年+G他x0.6":              (TIREDE, fame_g(0.6)),
    "D+G他x1.0":                 (TIREDD, fame_g(1.0)),
    "D+v62(優勝+30鈍る)":        (TIREDD, FAME_V62),
}
BOTS = M.BOTS

def one(args):
    key, app, bot, n = args
    tired, fm = CFGS[key]
    C.EVENTS_APP = bool(app)
    log, fin, wf = {}, [], []
    o_install = S.install
    def inst(neta):
        o_install(neta)
        for k in ("V2_TIRED_PEN", "V2_TIRED_CAP", "V2_TIRED_REST_YEARS"):
            setattr(C, k, tired.get(k, {"V2_TIRED_CAP": 2, "V2_TIRED_REST_YEARS": 0}.get(k, 0.0)))
        for k, v in fm["c"].items(): setattr(C, k, v)
        for k, v in fm["b"].items(): setattr(B, k, v)
        B.OFFER_RATES = fm["off"]
        ry, rc = C.run_year, C.run_career
        def run_year(pol, s, year, rng, **kw):
            r = ry(pol, s, year, rng, **kw)
            log.setdefault(year, []).append(s.fame)
            if r[2] and not s.__dict__.get("_fl"):
                s.__dict__["_fl"] = True; fin.append(s.fame)
            return r
        def run_career(*a, **kw):
            r = rc(*a, **kw)
            if r[0] is not None: wf.append(r[1].fame)
            return r
        C.run_year, C.run_career = run_year, run_career
    S.install = inst
    r = M.one(("all", True, bot, n))[3]
    med = lambda v: statistics.median(v) if v else -1
    return key, app, bot, dict(win=r["win"], fin=r["fin"], ds=r["ds"], bk=r["bk"],
        fame={y: med(log.get(y)) for y in (1, 3, 5, 10)}, fin1=med(fin), winf=med(wf))

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    keys = sys.argv[2].split(",") if len(sys.argv) > 2 else list(CFGS)
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(k, a, b, n) for k in keys for a in (False, True) for b in BOTS])
    print(f"# n={n}/ボット・全部入り・ネタ込み。優勝%/決勝%/解散%/夜逃げ%｜知名度中央値 1年/3年/5年/10年末｜初決勝の年末｜優勝時")
    for key, app, bot, r in res:
        f = r["fame"]
        print(f"{key}|APP={int(app)}|{M.SHORT[BOTS.index(bot)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|"
              f"{f[1]:.0f}/{f[3]:.0f}/{f[5]:.0f}/{f[10]:.0f}|{r['fin1']:.0f}|{r['winf']:.0f}")

if __name__ == "__main__":
    main()
