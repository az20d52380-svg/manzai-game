#!/usr/bin/env python3
"""終盤イベント候補（枠 15+3×(年−5)＋E1〜E20＋N1〜N16）の実測（2026-11-08）。測るだけ・本体は触らない。
測り方: 今の sim 既定（15年・較正A・大会の経験点・11年目以降の伸び緩め＝すべて sim_career の既定に入っている）・周回の点0・
  ネタ込 NETA_ON=NETA_V2=True（exp_balance_snapshot_v0.install）＋ EVENTS_APP=True。
  ボット4種＝帯の組（のんびり改／ローテ／必要充足／やり込み）。Pool(maxtasksperchild=1)＋imap(chunksize=1)。同じ種で比べる。
  変更前＝枠15固定（APP_CAP_PER_YEAR=0）・新イベントなし（APP_LATE_ON=False）／変更後＝枠 15+3×(年−5)・新イベントあり。
  N17〜N20（優勝経験者向け）は sim が初優勝でキャリアを閉じるので出ない（アプリでは出る）。
usage: python3 exp_late_events_cand_1108_v0.py n [out.json]    → 表を stdout。
指標: 6〜15年目の年あたり発火（週次ランダム抽選の発火数の合計÷10）・15年内の初優勝・決勝(1度でも)・解散・夜逃げ・優勝年の中央値。"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import exp_balance_snapshot_v0 as S2

CASES = {"before": dict(cap=0, late=False), "after": dict(cap=3, late=True)}
BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり", "ローテ", "必要充足", "やり込み"]

def job(a):
    case, bi, seeds = a
    cs = CASES[case]
    S2.install(True)                               # ネタ込・正典v2・EVENTS_ON/OTHERS_ON
    pol = S2.make2(BOTS[bi])                       # ボットは差し替えの後に作る
    fin = []
    C.NETA_ON = C.NETA_V2 = True
    C.EVENTS_APP = True
    C.APP_CAP_PER_YEAR = cs["cap"]; C.APP_LATE_ON = cs["late"]
    per_year = {}
    o = C.run_year
    def run_year(pol_, s, year, rng, **kw):
        a_ = s.__dict__.get("_app"); b = a_["count"] if a_ else 0
        r = o(pol_, s, year, rng, **kw)
        if r[2]: fin.append(year)
        a_ = s.__dict__.get("_app"); per_year[year] = (a_["count"] if a_ else 0) - b
        return r
    C.run_year = run_year
    out = []
    for i in seeds:
        fin.clear(); per_year.clear()
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        out.append(dict(win=first, fin=bool(fin), ds=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt")),
                        late=sum(v for y, v in per_year.items() if y >= 6) / 10.0, py=dict(per_year),
                        lateids=sorted(k for k in (d.get("_app") or {}).get("fired", ()) if k.startswith("late"))))
    return (case, bi), out

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    w = [r["win"] for r in rs if r["win"]]
    return dict(n=n, late=statistics.mean(r["late"] for r in rs), win=p(lambda r: r["win"]), fin=p(lambda r: r["fin"]),
                ds=p(lambda r: r["ds"]), bk=p(lambda r: r["bk"]), wy=statistics.median(w) if w else None,
                nlate=statistics.mean(len(r["lateids"]) for r in rs))

def main():
    n = int(sys.argv[1]); outp = sys.argv[2] if len(sys.argv) > 2 else None
    chunk = 25
    jobs = [(cs, bi, list(range(i, min(i + chunk, n)))) for cs in CASES for bi in range(4) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    print(f"n={n}/ボット x4ボット（今の sim 既定・周回の点0・ネタ込・EVENTS_APP）")
    print("|案|ボット|6〜15年目の年あたり発火|終盤イベント(種)|15年内の初優勝%|決勝%|解散%|夜逃げ%|優勝年 中央|")
    print("|---|---|---|---|---|---|---|---|---|")
    for cs in CASES:
        allr = []
        for bi in range(4):
            rs = res[(cs, bi)]; allr += rs; r = summ(rs); final[f"{cs}|{SHORT[bi]}"] = r
            print(f"|{cs}|{SHORT[bi]}|{r['late']:.2f}|{r['nlate']:.1f}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|{r['wy']}|")
        r = summ(allr); final[f"{cs}|平均"] = r
        print(f"|{cs}|**4ボット平均**|{r['late']:.2f}|{r['nlate']:.1f}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|{r['wy']}|", flush=True)
    for cs in CASES:   # 年ごとの発火回数（キャリア平均・解散後は0で数える）
        allr = [r for bi in range(4) for r in res[(cs, bi)]]
        ys = {y: statistics.mean(r["py"].get(y, 0) for r in allr) for y in range(1, 16)}
        final[f"{cs}|年別"] = ys
        print(f"年別発火 {cs}: " + " ".join(f"{y}:{v:.1f}" for y, v in ys.items()))
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
