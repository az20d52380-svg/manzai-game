#!/usr/bin/env python3
"""女性コンビだけの大会「THE HANA」（オーナー決定 10/20・キュー112）を足した時の差を実測（材料・数値は全て【仮】）。
usage: python3 exp_the_hana_1025_v0.py [n=300] [out.json]
THE HANA＝1回戦（動画審査）→2回戦→準決勝→決勝・敗者復活なし・芸歴の制限なし・東京（遠征なし）。
週は空き週 32/37/42/44（決勝＝12月上旬・GP 準々決勝43と準決勝45の間）。通過で知名度+GP_ROUND_FAME、優勝で賞金と知名度。
式・GameCore・golden は触らない（実験の中で TOURNAMENTS/EVENT_WEEKS と enter_tournament を差し替えるだけ）。
男コンビ（今の作り）＝基準。ボット4種×ネタ無/込（exp_first_rankup_v0.setup＝今のアプリ相当の条件）。Pool(maxtasksperchild=1)・chunksize=1。
指標：10年内のGP初優勝・GP決勝進出・夜逃げ・3年目末の知名度の中央値・10年目の所持金の中央値・THE HANA の優勝（10年で1回でも）・決勝進出。"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import exp_first_rankup_v0 as R

WEEKS = (32, 37, 42, 44)
NAMES = ("HANA1回戦", "HANA2回戦", "HANA準決勝", "HANA決勝")
# 案：ライン4段 × 優勝の手元賞金・知名度（GP 優勝＝手元500万・知名度+10 より少し下）
LINES = {"中": (18, 30, 44, 60), "難": (22, 38, 56, 70), "極": (26, 44, 64, 76)}   # 1回目 n=4 で旧「中」が決勝到達94%＝易しすぎ→上へずらした
PRIZES = {"賞250万": (2_500_000, 8), "賞100万": (1_000_000, 6)}

def install(lines, prize, fame):
    T = dict(C.TOURNAMENTS)
    for i, (w, nm, ln) in enumerate(zip(WEEKS, NAMES, lines)):
        last = i == len(WEEKS) - 1
        T[w] = dict(name=nm, line=ln, prize=prize if last else 0, fame=fame if last else C.GP_ROUND_FAME,
                    osaka=False, hana=i, ok=(lambda i: lambda year, s: getattr(s, "_hana", (0, 0)) == (year, i) or (i == 0))(i))
    C.TOURNAMENTS = T
    C.EVENT_WEEKS = set(T) | {w for w, _, _ in C.GP_ROUNDS} | {C.GP_FINAL_WEEK}
    o_enter = C.enter_tournament
    def enter(s, pol, t, rng):
        acted, ok = o_enter(s, pol, t, rng)
        i = t.get("hana")
        if i is not None and acted:
            s._hana_y = s._cur_year
            if ok and i < len(WEEKS) - 1:
                s._hana = (s._cur_year, i + 1)
            elif ok:
                s._hana_win = True
            if ok and i == len(WEEKS) - 2:
                s._hana_fin = True
        return acted, ok
    C.enter_tournament = enter

def run_cell(bi, neta, var, seeds):
    bots = R.setup(neta)
    if var != "男":
        lk, pk = var.split("/")
        install(LINES[lk], *PRIZES[pk])
    bot = bots[bi]
    o_year = C.run_year
    def run_year(pol, s, year, rng, **k):
        s._cur_year = year
        r = o_year(pol, s, year, rng, **k)
        if year == 3: s._fame3 = s.fame
        return r
    C.run_year = run_year
    out = []
    for sd in seeds:
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(bot, C.BASE_SEED + sd, money_log=ml)
        d = s.__dict__
        out.append(dict(w10=first is not None, fin=bool(ever), bk=bool(d.get("_bankrupt")),
                        f3=d.get("_fame3"), m10=(ml[9][0] if ml[9] else None),
                        hw=bool(d.get("_hana_win")), hf=bool(d.get("_hana_fin"))))
    return out

def job(a):
    key, bi, neta, var, seeds = a
    return key, run_cell(bi, neta, var, seeds)

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    f3 = [r["f3"] for r in rs if r["f3"] is not None]; m10 = [r["m10"] / 10000 for r in rs if r["m10"] is not None]
    return dict(n=n, w10=p(lambda r: r["w10"]), fin=p(lambda r: r["fin"]), bk=p(lambda r: r["bk"]),
                f3=statistics.median(f3) if f3 else None, m10=statistics.median(m10) if m10 else None,
                hw=p(lambda r: r["hw"]), hf=p(lambda r: r["hf"]))

def chunks(n, size=25): return [list(range(i, min(i + size, n))) for i in range(0, n, size)]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    outp = sys.argv[2] if len(sys.argv) > 2 else None
    vars_ = ["男"] + [f"{l}/{p}" for l in LINES for p in PRIZES]
    if len(sys.argv) > 3: vars_ = ["男"] + sys.argv[3].split(",")
    jobs = [((v, bi, ne), bi, ne, v, ch) for v in vars_ for bi in range(4) for ne in (False, True) for ch in chunks(n)]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    cells = {json.dumps(k, ensure_ascii=False): summ(v) for k, v in sorted(res.items(), key=lambda kv: str(kv[0]))}
    agg = {}
    for v in vars_:
        S = [summ(res[(v, bi, ne)]) for bi in range(4) for ne in (False, True)]
        agg[v] = {k: (round(statistics.mean(x[k] for x in S if x[k] is not None), 1)) for k in S[0] if k != "n"}
    for v, a in agg.items():
        print(v, " ".join(f"{k}={a[k]}" for k in ("w10", "fin", "bk", "f3", "m10", "hw", "hf")))
    if outp:
        json.dump(dict(n=n, agg=agg, cells=cells), open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
