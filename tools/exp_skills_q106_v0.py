#!/usr/bin/env python3
"""キュー106：特技（パワプロの特殊能力）＝余った経験点の使い道 の実測。usage: python3 exp_skills_q106_v0.py [n=1000] [variants=all]
能力の伸びの式は動かさない。おまかせ注ぎ（pour_all）の後に残った経験点で、特技を1つずつ覚える（各1回きり・覚えたらずっと効く）。
特技（値は全て【仮】・費用は内部の単位＝画面では×10）：
  間の取り方   間合い6・胆力2   本番の「ハマった夜」の確率 +2pt（0.10→0.12）
  体が資本     胆力4・存在感3   体調ダウンの確率 ×0.7
  愛され芸人   存在感6          知名度の伸び ×1.1
  やりくり上手 語彙2・間合い4   月末の生活費 −5%
  相方思い     存在感3・間合い4 すれ違いの増え ×0.8
ボットは覚えられる物を上から順に覚える（人は選べる）。案 "none"＝特技なし／"all"＝全部／"no_burst"＝間の取り方を除く。
体調ダウンは §97 推奨（体力50未満・0.005）を入れた状態。ネタ込み。式・既定値は変えない（スクリプト内の差し替えだけ）。"""
import sys
from multiprocessing import Pool
import balance_sim as B
import sim_career as C

SKILLS = [
    ("間の取り方", {"maai": 6, "tanryoku": 2}),
    ("体が資本", {"tanryoku": 4, "sonzaikan": 3}),
    ("愛され芸人", {"sonzaikan": 6}),
    ("やりくり上手", {"goi": 2, "maai": 4}),
    ("相方思い", {"sonzaikan": 3, "maai": 4}),
]

def run(var, grp, bi, n):
    if grp == "A":
        import canon_v2 as V
        import exp_ability_stall_v0 as S
        import bots_v3
        from exp_human import PCasual2
        from bots_v3 import PRotate
        from exp_places_v1 import Cafe
        from exp_rests_v1 import Spa
        V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
        for k, v in S.PRE.items(): setattr(C, k, v)
        B.OFFER_RATES = S.OFFER_NEW
        B.enable_places(True); B.enable_paid_rests(True)
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        pol = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()][bi]
        name = pol.name
    else:
        import exp_balance_snapshot_v0 as S2
        S2.install(True)
        name = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"][bi]
        pol = S2.make2(name)
    C.INJURY_TH, C.INJURY_P_PER = 50.0, 0.005
    allowed = [] if var == "none" else [k for k, _ in SKILLS if not (var == "no_burst" and k == "間の取り方")]
    st = {"sk": set(), "w": 0, "years": {}}
    o_pour, o_perform, o_add, o_rw, o_ry = B.pour_all, B.perform, B.add, C.rift_weekend, C.run_year
    p_inj0, burst0 = C.INJURY_P_PER, B.BURST_P
    def pour(s):
        o_pour(s)
        for k, cost in SKILLS:
            if k in allowed and k not in st["sk"] and all(getattr(s, B.CURRENCY_ATTR[c]) >= v for c, v in cost.items()):
                for c, v in cost.items():
                    setattr(s, B.CURRENCY_ATTR[c], getattr(s, B.CURRENCY_ATTR[c]) - v)
                st["sk"].add(k); st["years"].setdefault(k, getattr(s, "_yr_now", 0))
        C.INJURY_P_PER = p_inj0 * (0.7 if "体が資本" in st["sk"] else 1.0)
    def perform(s, line, rng):
        B.BURST_P = burst0 + (0.02 if "間の取り方" in st["sk"] else 0.0)
        try:
            return o_perform(s, line, rng)
        finally:
            B.BURST_P = burst0
    def add(s, key, v):
        if key == "fame" and v > 0 and "愛され芸人" in st["sk"]:
            v = v * 1.1
        return o_add(s, key, v)
    def rw(s, year, c0):
        st["w"] += 1
        if st["w"] % 4 == 0 and "やりくり上手" in st["sk"]:
            s.money += B.LIVING_COST * 0.05
        r0 = getattr(s, "rift", 0.0)
        out = o_rw(s, year, c0)
        if "相方思い" in st["sk"] and getattr(s, "rift", 0.0) > r0 and not out:
            s.rift = r0 + (s.rift - r0) * 0.8
        return out
    def ry(pol_, s, year, rng, **kw):
        s._yr_now = year
        return o_ry(pol_, s, year, rng, **kw)
    B.pour_all, B.perform, B.add, C.rift_weekend, C.run_year = pour, perform, add, rw, ry
    win = fin = ds = 0; nsk = 0; first_year = []
    for i in range(n):
        st.update(sk=set(), w=0, years={})
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
        nsk += len(st["sk"])
        if st["years"]: first_year.append(min(st["years"].values()))
    fy = sum(first_year) / len(first_year) if first_year else 0
    return var, grp, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n, nsk=nsk / n, fy=fy)

def job(a): return run(*a)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else ["none", "all", "no_burst"]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(job, [(v, g, b, n) for v in variants for g in ("A", "B") for b in range(4)], chunksize=1)
    print(f"# n={n}/ボット ネタ込み・体調ダウン§97入り。特技=10年で覚えた数・最初に覚えた年")
    for var, grp, name, r in res:
        print(f"{var}|{grp}|{name}|決={r['fin']:.1f}|優={r['win']:.1f}|散={r['ds']:.1f}|特技={r['nsk']:.1f}|初={r['fy']:.1f}年")

if __name__ == "__main__":
    main()
