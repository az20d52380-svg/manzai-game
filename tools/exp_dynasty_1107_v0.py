#!/usr/bin/env python3
"""優勝後も続ける場合の連覇の実測（2026-11-07・測るだけ・数値は【仮】）。
正典 sim_career（周回=META_POINTS を new_state が読む・段1〜3 の式が入っている）に、点だけ渡す。式・golden・sim_career は触らない。
run_career の「優勝で止まる」だけを、このスクリプトの中で外す（exp_calib_meta_1102_v0.patch_career と同じ）。
土台＝exp_calib_all_1101_v0 の「何も差し替えない」変種（新正典と一致）。ボット4種（のんびり/ローテ/必要充足/やり込み）・ネタ込（NETA_ON/NETA_V2）。
usage: python3 exp_dynasty_1107_v0.py n [out.json]   （周回の点: やり込みは 0,10,20,30,36／他は 0,36）
指標：win 15年内の初優勝／y1 1年目／wins 生涯の優勝回数の平均／best 最多連覇の平均・最大／s15 15連覇／
  ds 途中解散／lost 優勝後の年（優勝しなかった年）の内訳＝到達した段（0〜5回戦通過）・決勝まで行って負け・解散で打ち切り"""
import sys, json, inspect, textwrap
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import exp_calib_all_1101_v0 as E

VARIANT = "yrs=15;M=0;D=1;k=0;band=1;ex=0;mo=0;onsen=0"
YEARS = 15

def patch_career():
    src = textwrap.dedent(inspect.getsource(C.run_career))
    old = "        if won:\n            return year, s, best_stage, ever_final\n"
    assert old in src
    exec(src.replace(old, ""), C.__dict__)

def job(a):
    P, bi, seeds = a
    c = E.cfg_of(VARIANT)
    rec, st = E.setup(c, P, True, False)
    C.META_POINTS = P
    patch_career()
    pol = E.S2.make2(E.BOTS[bi])
    yr = []
    o = C.run_year
    def run_year(pol_, s, year, rng, **kw):
        r = o(pol_, s, year, rng, **kw); yr.append((year, bool(r[0]), r[1], bool(r[2]))); return r
    C.run_year = run_year
    out = []
    for i in seeds:
        rec["fin"] = []; rec["allG"] = None; st.update(wk=0, first=None); yr.clear()
        _, s, _, _ = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        out.append(dict(yr=list(yr), ds=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt"))))
    return (P, bi), out

def stats(rs):
    n = len(rs); R = dict(n=n)
    wins = []; bests = []; first = []; ds = 0; lost = {}
    for r in rs:
        ws = [y for (y, w, _, _) in r["yr"] if w]
        best = cur = 0; prev = None
        for y in ws:
            cur = cur + 1 if prev == y - 1 else 1; best = max(best, cur); prev = y
        wins.append(len(ws)); bests.append(best); first.append(ws[0] if ws else None)
        ds += r["ds"] or r["bk"]
        if ws:
            for (y, w, stg, fn) in r["yr"]:
                if y > ws[0] and not w:
                    k = "決勝敗退" if fn else f"{stg}回戦通過"
                    lost[k] = lost.get(k, 0) + 1
            played = r["yr"][-1][0] if r["yr"] else 0
            if played < YEARS: lost["解散・夜逃げで打切"] = lost.get("解散・夜逃げで打切", 0) + (YEARS - played)
    p = lambda f: 100.0 * sum(1 for x in f) / n
    ch = [b for b in bests if b]
    R.update(win=p([f for f in first if f]), y1=p([f for f in first if f == 1]), wins=sum(wins) / n,
             best=sum(ch) / len(ch) if ch else 0.0, bmax=max(bests), s3=p([b for b in bests if b >= 3]),
             s15=p([b for b in bests if b >= 15]), ds=100.0 * ds / n, lost=lost)
    return R

def main():
    n = int(sys.argv[1]); outp = sys.argv[2] if len(sys.argv) > 2 else None
    cells = [(P, bi) for bi in range(4) for P in ((0, 10, 20, 30, 36, 38) if bi == 3 else (0, 36, 38))]
    chunk = 25
    jobs = [(P, bi, list(range(i, min(i + chunk, n)))) for (P, bi) in cells for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    for key in sorted(res, key=lambda k: (k[1], k[0])):
        P, bi = key; r = stats(res[key]); final[f"{P}|{E.SHORT[bi]}"] = r
        print(f"P{P}|{E.SHORT[bi]}|n={r['n']}|win={r['win']:.1f}|y1={r['y1']:.1f}|wins={r['wins']:.2f}|best={r['best']:.2f}/{r['bmax']}"
              f"|s3={r['s3']:.1f}|s15={r['s15']:.1f}|ds={r['ds']:.1f}|lost={json.dumps(r['lost'], ensure_ascii=False)}", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
