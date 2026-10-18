#!/usr/bin/env python3
"""キュー93 の合わせ直し：経験点の配り方の案を、ボット2組で同時に測る。usage: python3 exp_q93_retune_v0.py [n=500] [variants=all]
組A（exp_ability_stall_v0 の組・人の手配り hand）：のんびり改＋喫茶店／ローテ＋喫茶店／バランス型／調整型 → 1〜3年の詰まり週%・決勝%
組B（exp_balance_snapshot の組・本番ボット）：のんびり改／ローテ／必要充足／やり込み／放置 → 優勝%・決勝%・解散%
案 "{配合}{M?}@{全体量の倍率}"：配合 A=今 / R2=供給比に合わせる / RH=今とR2の中間。M=間合いの供給減（ネタ見せ会 6→4・ネタ合わせ 3→2）。
目標：両方の組で帯（決勝・優勝）が今とほぼ同じ・解散が残る・詰まりが減る。式・既定値は変えない。ネタ込み。数値は全て【仮】。"""
import sys, copy
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import bots_v3

RECIPES = {
    "R2": {
        "sense": [("hirameki", 0.35), ("maai", 0.40), ("tanryoku", 0.25)],
        "idea": [("hirameki", 0.60), ("goi", 0.25), ("maai", 0.15)],
        "expr": [("goi", 0.20), ("maai", 0.60), ("tanryoku", 0.20)],
        "chara": [("sonzaikan", 0.50), ("hirameki", 0.20), ("maai", 0.30)],
        "mental": [("sonzaikan", 0.20), ("tanryoku", 0.80)],
    },
    "RH": {
        "sense": [("hirameki", 0.40), ("maai", 0.375), ("tanryoku", 0.225)],
        "idea": [("hirameki", 0.625), ("goi", 0.30), ("maai", 0.075)],
        "expr": [("goi", 0.275), ("maai", 0.625), ("tanryoku", 0.10)],
        "chara": [("sonzaikan", 0.60), ("hirameki", 0.25), ("maai", 0.15)],
        "mental": [("sonzaikan", 0.225), ("tanryoku", 0.775)],
    },
}
SUPPLY_M = {"ネタ見せ会": ("cur:maai", 4), "ネタ合わせ": ("cur:maai", 2)}

def parse(v):
    base, _, sc = v.partition("@")
    m = base.endswith("M")
    rec = base[:-1] if m else base
    return rec, m, float(sc) if sc else 1.0

def apply(v):
    rec, m, sc = parse(v)
    if rec in RECIPES:
        B.ABILITY_RECIPE.update(copy.deepcopy(RECIPES[rec]))
    if m:
        for name, main in SUPPLY_M.items():
            for tbl in (B.TRAININGS, B.PLACE_TRAININGS):
                if name in tbl: tbl[name]["main"] = main
    B.EXP_SUPPLY_SCALE = B.EXP_SUPPLY_SCALE * sc
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}

def job(args):
    var, grp, bi, n = args
    if grp == "A":
        import canon_v2 as V
        import exp_ability_stall_v0 as S
        from exp_human import PCasual2
        from bots_v3 import PRotate
        from exp_places_v1 import Cafe
        from exp_rests_v1 import Spa
        V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
        for k, v in S.PRE.items(): setattr(C, k, v)
        B.OFFER_RATES = S.OFFER_NEW
        B.enable_places(True); B.enable_paid_rests(True)
        apply(var)
        bot = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()][bi]
        r = S.measure(bot, n, "hand", "A")
        return var, grp, bot.name, dict(st=r["st_y13"], st1=r["st_y1"], fin=r["fin"], win=r["win"], ds=r["ds"])
    import exp_balance_snapshot_v0 as S2
    S2.install(True)
    apply(var)
    names = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
    pol = S2.make2(names[bi])
    win = fin = ds = 0
    for i in range(n):
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
    return var, grp, names[bi], dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["A", "R2M@0.8", "RHM@0.9", "RHM@0.8", "RH@0.9", "R2M@0.7"]
    jobs = [(v, g, b, n) for v in variants for g in ("A", "B") for b in range(4)]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(job, jobs)
    print(f"# n={n}/ボット ネタ込み。組A=hand（詰まり1年目/1〜3年・決勝・優勝・解散）／組B=本番ボット（優勝・決勝・解散）")
    for var, grp, name, r in res:
        if grp == "A":
            print(f"{var}|A|{name}|詰1={r['st1']:.0f}|詰13={r['st']:.0f}|決={r['fin']:.1f}|優={r['win']:.1f}|散={r['ds']:.1f}")
        else:
            print(f"{var}|B|{name}|決={r['fin']:.1f}|優={r['win']:.1f}|散={r['ds']:.1f}")

if __name__ == "__main__":
    main()
