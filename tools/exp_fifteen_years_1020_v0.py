#!/usr/bin/env python3
"""結成15年化（オーナー決定 2026-10-20）の実測：決勝ライン上げ／11年目以降の成長予算の減衰／その組み合わせ。測るだけ。
本体の式・GameCore・Swift・golden は触らない（スクリプト内の差し替えだけ）。数値は全て【仮】。
usage: python3 exp_fifteen_years_1020_v0.py [n=300] [variants=all|a,b,..] [out.json]
案名 "L{d}D{f}"  d=決勝＋敗者復活のライン上げ幅（復活=決勝-4を保つ・exp_dynasty_v4 と同じ）／f=11年目以降の成長予算の年ごとの掛け率
  年 k(>10) の成長予算の加算 = max(下限, 基準-傾き(k-1)) × f^(k-10)（f=1 は今のまま）。10年目までは触らない。
  "T10" = 今（10年制）の基準。"L0D1" = 何もしない15年。
ボット4種(のんびり改/ローテ/必要充足/やり込み)×ネタ無/込(NETA_ON=NETA_V2=True)。ボットは差し替えの後に作る・Pool(maxtasksperchild=1)。
測定：15年内の初優勝率／初優勝年の中央値と分布(1-5/6-10/11-15)／決勝進出年の分布(のべ決勝進出組の割合)／夜逃げ・解散"""
import sys, json, inspect, textwrap
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import canon_v2 as V
import exp_balance_snapshot_v0 as S2

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]
ALL = ["T10", "L0D1", "L12D1", "L14D1", "L16D1", "L0D0.8", "L0D0.6", "L0D0.4",
       "L8D0.6", "L12D0.8", "L12D0.6", "L14D0.8", "L14D0.6", "L12D0.4", "L8D0.4", "L16D0.8"]

def parse(v):
    if v == "T10": return 10, 0, 1.0
    a, b = v[1:].split("D"); return 15, float(a), float(b)   # "M{d}D{f}"＝ライン上げを11年目以降だけ（10/25 追加）

def patch_growth(f):
    """run_year の成長予算の合計式に 11年目以降の掛け率フックを差し込む（ソースを置換して再定義）"""
    src = textwrap.dedent(inspect.getsource(C.run_year))
    old = "sum(max(floor, base - slope * (k - 1))"
    assert old in src
    src = src.replace(old, "sum(_gf(k) * max(floor, base - slope * (k - 1))")
    C._gf = lambda k: (f ** (k - 10)) if k > 10 else 1.0
    exec(src, C.__dict__)

def job(a):
    var, bi, neta, seeds = a
    years, d, f = parse(var)
    if f != 1.0: patch_growth(f)   # 先に差し替え（install が run_year を包むため）
    S2.install(bool(neta))
    C.YEARS = years
    late = var.startswith("M")
    fl0, rl0 = C.GP_FINAL_LINE, C.GP_REVIVAL_LINE
    if not late:
        C.GP_FINAL_LINE += d; C.GP_REVIVAL_LINE += d
    rec = []
    o2 = C.run_year
    def run_year2(pol, s, year, rng, **kw):
        if late:
            up = d if year > 10 else 0
            C.GP_FINAL_LINE, C.GP_REVIVAL_LINE = fl0 + up, rl0 + up
        r = o2(pol, s, year, rng, **kw)
        if r[2]: rec.append(year)
        return r
    C.run_year = run_year2
    pol = S2.make2(BOTS[bi])
    out = []
    for i in seeds:
        del rec[:]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        dd = s.__dict__
        out.append(dict(win=first, fin=list(rec), ds=bool(dd.get("_dissolved")), bk=bool(dd.get("_bankrupt"))))
    return (var, bi, neta), out

def dist(ys):
    n = len(ys)
    return [sum(1 for y in ys if lo <= y <= hi) for lo, hi in ((1, 5), (6, 10), (11, 15))]

def summarize(rs):
    n = len(rs); ws = sorted(r["win"] for r in rs if r["win"])
    fy = [min(r["fin"]) for r in rs if r["fin"]]
    p = lambda x: 100.0 * x / n
    return dict(n=n, win=p(len(ws)), wmed=(ws[len(ws) // 2] if ws else None),
                wd=[p(x) for x in dist(ws)],
                fin=p(len(fy)), fd=[p(x) for x in dist(fy)],
                fyears=[p(sum(1 for r in rs if y in r["fin"])) for y in range(1, 16)],
                ds=p(sum(r["ds"] for r in rs)), bk=p(sum(r["bk"] for r in rs)))

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    a2 = sys.argv[2] if len(sys.argv) > 2 else "all"
    variants = ALL if a2 == "all" else a2.split(",")
    outp = sys.argv[3] if len(sys.argv) > 3 else None
    chunk = 25
    jobs = [(v, bi, neta, list(range(i, min(i + chunk, n))))
            for v in variants for bi in range(4) for neta in (False, True) for i in range(0, n, chunk)]
    res = {}
    with Pool(10, maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(job, jobs):
            res.setdefault(key, []).extend(out)
    final = {}
    for (v, bi, neta), rs in sorted(res.items()):
        r = summarize(rs); nt = "込" if neta else "無"
        print(f"{v}|{SHORT[bi]}|{nt}|n={r['n']}|win={r['win']:.1f}|wmed={r['wmed']}|wd={'/'.join(f'{x:.1f}' for x in r['wd'])}"
              f"|fin={r['fin']:.1f}|fd={'/'.join(f'{x:.1f}' for x in r['fd'])}|ds={r['ds']:.1f}|bk={r['bk']:.1f}", flush=True)
        final[f"{v}|{SHORT[bi]}|{nt}"] = r
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
