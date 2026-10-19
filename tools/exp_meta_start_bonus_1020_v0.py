#!/usr/bin/env python3
"""周回ボーナス（初期の経験点・所持金）の2つの型を実測（オーナー決定 10/20 の材料・数値は全て【仮】）。
usage: python3 exp_meta_start_bonus_1020_v0.py [n=300] [out.json] [tiers=all]
型1（全部加算）：周回の点 P に比例して 初期経験点 e·P（上限 EXP_CAP・E0 の 35/27/18/10/10% で5通貨）と初期所持金 g·P（上限 MONEY_CAP）を足す。e,g∈小/中/大 のうち5組（経験を変える3＋お金を変える2の十字・中中を中心）。
型2（初期装備）：点で解放される装備 GEAR（8個）から周の頭に最大 SLOTS[P] 個（同種は重ねない）を選んで足す。選び方 2通り：
  best＝ボットごとに別シード(10万番台)の小実測 PILOT_N で「10年内初優勝＋決勝0.5−夜逃げ」が最大の組を選ぶ／fit＝ボットの遊び方に合う優先順（FIT）で先頭から。
式・GameCore・golden は触らない（new_state の差し替えだけ）。ボットは差し替えの後に作る・Pool(maxtasksperchild=1)。
指標：1年目の初優勝・10年内の初優勝・決勝進出（10年で1回でも）・夜逃げ・借金（所持金<0を一度でも）・最初の昇格（能力G→F＝15以上）の週（1年目48週内）・10年目の所持金（10年目の年末まで残った人の中央値）。
ボット4種(のんびり改/ローテ/必要充足/やり込み)×ネタ無/込(NETA_ON=NETA_V2=True)。"""
import sys, json, itertools, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import canon_v2 as V
import exp_first_rankup_v0 as R

POINTS = [0, 5, 10, 15, 20, 30]
SPLIT = dict(hirameki=.35, maai=.27, goi=.18, sonzaikan=.10, tanryoku=.10)
EXP_TIER = {"小": 2.0, "中": 4.0, "大": 8.0, "特": 12.0}                 # 点1あたりの経験点（5通貨の合計）
MONEY_TIER = {"小": 10_000, "中": 30_000, "大": 50_000}        # 点1あたりの所持金
EXP_CAP_T = {"小": 160.0, "中": 160.0, "大": 160.0, "特": 360.0}   # 型1の上限（段ごと）
EXP_CAP, MONEY_CAP = 360.0, 1_000_000                        # 型2の上限（EXP_CAP_ENV で 160 に変えて前回相当）
import os
EXP_CAP = float(os.environ.get("EXP_CAP_ENV", EXP_CAP))
# 型2
def sp(h=.2, m=.2, g=.2, s=.2, t=.2):
    x = dict(hirameki=h, maai=m, goi=g, sonzaikan=s, tanryoku=t); z = sum(x.values()); return {k: v / z for k, v in x.items()}
GEAR = {  # 名前: (経験点合計, 配分, 所持金, 相性)
    "経験袋":   (90, SPLIT, 0, 0),
    "財布":     (0, SPLIT, 600_000, 0),
    "バランス": (45, SPLIT, 250_000, 3),
    "相性":     (20, SPLIT, 0, 6),
    "ひらめき偏": (60, sp(h=.7, m=.075, g=.075, s=.075, t=.075), 0, 0),
    "語彙偏":   (60, sp(g=.7, h=.075, m=.075, s=.075, t=.075), 0, 0),
    "間偏":     (60, sp(m=.7, h=.075, g=.075, s=.075, t=.075), 0, 0),
    "度胸偏":   (60, sp(s=.4, t=.4, h=.067, m=.067, g=.066), 0, 0),
}
ORDER = list(GEAR)                     # 解放順（先頭から）
UNLOCK = {0: 0, 5: 2, 10: 4, 15: 6, 20: 7, 30: 8}
SLOTS = {0: 0, 5: 1, 10: 1, 15: 2, 20: 2, 30: 3}
FIT = [["財布", "相性", "バランス", "経験袋"], ["バランス", "経験袋", "相性", "財布"],
       ["経験袋", "バランス", "財布", "相性"], ["経験袋", "度胸偏", "ひらめき偏", "財布"]]
PILOT_N = 60
BOTNAMES = R.BOTNAMES

def spec_add(exp, money, compat, split):
    return dict(exp=exp, money=money, compat=compat, split=split)

def spec_t1(P, et, mt):
    return spec_add(min(EXP_CAP_T[et], EXP_TIER[et] * P), min(MONEY_CAP, MONEY_TIER[mt] * P), 0, SPLIT)

def spec_gear(names):
    e = {c: 0.0 for c in SPLIT}; mo = cp = 0
    for n in names:
        t, spl, m, c = GEAR[n]
        for k in e: e[k] += t * spl[k]
        mo += m; cp += c
    return dict(exp=0, money=min(MONEY_CAP, mo), compat=cp, split=None, byc=e)

def install(neta, spec):
    bots = R.setup(neta)
    on = C.new_state
    def new_state(*a, **k):
        s = on(*a, **k)
        if spec:
            byc = spec.get("byc") or {c: spec["exp"] * r for c, r in spec["split"].items()}
            tot = sum(byc.values())
            f = min(1.0, EXP_CAP / tot) if tot > 0 else 1.0
            for c, v in byc.items():
                setattr(s, "exp_" + c, getattr(s, "exp_" + c) + v * f)
            s.money += spec["money"]
            if spec["compat"]: s.compat = min(float(B.COMPAT_CAP), s.compat + spec["compat"])
        return s
    C.new_state = new_state
    return bots, on

def run_cell(bi, neta, spec, seeds):
    bots, on = install(neta, spec)
    bot = bots[bi]
    st = {"wk": 0, "first": None}
    o_pour = B.pour_all
    def pour(s):
        o_pour(s); st["wk"] += 1
        if st["first"] is None and st["wk"] <= 48 and max(getattr(s, a) for a in R.AB) >= 15: st["first"] = st["wk"]
    B.pour_all = pour
    out = []
    try:
        for sd in seeds:
            st.update(wk=0, first=None); ml = [[] for _ in range(C.YEARS)]
            first, s, stage, ever = C.run_career(bot, C.BASE_SEED + sd, money_log=ml)
            d = s.__dict__
            out.append(dict(y1=first == 1, w10=first is not None, fin=bool(ever), bk=bool(d.get("_bankrupt")),
                            debt=getattr(s, "min_money", 0) < 0, rk=st["first"], m10=(ml[9][0] if ml[9] else None)))
    finally:
        B.pour_all = o_pour; C.new_state = on
    return out

def job(a):
    key, bi, neta, spec, seeds = a
    V.apply(); C.EVENTS_ON = True
    return key, run_cell(bi, neta, spec, seeds)

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    rk = sorted(r["rk"] if r["rk"] else 99 for r in rs); m10 = [r["m10"] / 10000 for r in rs if r["m10"] is not None]
    return dict(n=n, y1=p(lambda r: r["y1"]), w10=p(lambda r: r["w10"]), fin=p(lambda r: r["fin"]), bk=p(lambda r: r["bk"]),
                debt=p(lambda r: r["debt"]), rk=rk[n // 2], m10=statistics.median(m10) if m10 else None)

def chunks(n, size=25): return [list(range(i, min(i + size, n))) for i in range(0, n, size)]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    outp = sys.argv[2] if len(sys.argv) > 2 else None
    only = sys.argv[3] if len(sys.argv) > 3 else "all"
    cells = [(bi, ne) for bi in range(4) for ne in (False, True)]
    jobs = []
    # 型1
    for et, mt in [("小","中"),("中","中"),("大","中"),("中","小"),("中","大"),("特","中")]:
        if only != "all" and f"{et}{mt}" not in only.split(","): continue
        for P in POINTS:
            if P == 0 and (et, mt) != ("小", "中"): continue   # 点0は全組共通
            spec = spec_t1(P, et, mt)
            for bi, ne in cells:
                for ch in chunks(n): jobs.append((("T1", f"経{et}金{mt}" if P else "共通", P, bi, ne), bi, ne, spec, ch))
    # 型2：best の選択（単品を小実測→解放済みの上位 SLOTS 個を足す＝重ねは足し算で近似）
    pilot = {}
    pj = [(("PI", g, bi, ne), bi, ne, spec_gear((g,)), list(range(100000, 100000 + PILOT_N))) for g in ORDER for bi, ne in cells]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(job, pj, chunksize=1):
            pilot.setdefault(key, []).extend(out)
        sc1 = {}
        for (_, g, bi, ne), rs in pilot.items():
            sc1[(g, bi, ne)] = sum(r["w10"] + .5 * r["fin"] - r["bk"] for r in rs) / len(rs)
        best = {}
        for P in POINTS[1:]:
            un = ORDER[:UNLOCK[P]]
            for bi, ne in cells:
                best[(P, bi, ne)] = (0, tuple(sorted(un, key=lambda g: -sc1[(g, bi, ne)])[:SLOTS[P]]))
        for P in POINTS:
            for bi, ne in cells:
                if P == 0:
                    sets = {"best": ()}
                else:
                    un = ORDER[:UNLOCK[P]]
                    fit = tuple([g for g in FIT[bi] if g in un][:SLOTS[P]])
                    sets = {"best": best[(P, bi, ne)][1], "fit": fit}
                for mode, c in sets.items():
                    for ch in chunks(n): jobs.append((("T2" + mode if P else "共通", "+".join(c), P, bi, ne), bi, ne, spec_gear(c), ch))
        for key, out in p.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    for key, rs in sorted(res.items(), key=lambda kv: str(kv[0])):
        final[json.dumps(key, ensure_ascii=False)] = summ(rs)
    # 組×点で8セル平均
    agg = {}
    for (typ, lab, P, bi, ne), rs in res.items():
        if typ == "共通": continue
        agg.setdefault((typ, lab if typ == "T1" else "", P), []).append(summ(rs))
    base = [summ(rs) for (typ, lab, P, bi, ne), rs in res.items() if typ == "共通"]
    def mean(L, k):
        v = [x[k] for x in L if x[k] is not None]; return sum(v) / len(v) if v else float("nan")
    rows = {}
    for key, L in [(("共通", "", 0), base)] + sorted(agg.items(), key=lambda kv: str(kv[0])):
        r = {k: mean(L, k) for k in ("y1", "w10", "fin", "bk", "debt", "rk", "m10")}
        rows[json.dumps(key, ensure_ascii=False)] = r
        print(f"AGG|{key}|y1={r['y1']:.1f}|w10={r['w10']:.1f}|fin={r['fin']:.1f}|bk={r['bk']:.1f}|debt={r['debt']:.1f}|rk={r['rk']:.1f}|m10={r['m10']:.0f}", flush=True)
    for (P, bi, ne), (sc, c) in sorted(best.items()):
        print(f"BEST|P={P}|{BOTNAMES[bi]}|{'込' if ne else '無'}|{'+'.join(c)}", flush=True)
    if outp: json.dump(dict(cells=final, agg=rows, best={f"{k}": v[1] for k, v in best.items()}), open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
