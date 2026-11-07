#!/usr/bin/env python3
"""終盤イベント候補の「弱め方」比較（2026-11-08）。測るだけ・既定値は変えず実行時に上書きするだけ。
土台: exp_late_events_cand_1108_v0.py（EVENTS_APP=True・NETA_V2・4ボット・Pool(maxtasksperchild=1)+chunksize=1）。
案: before=変更前 / c0=候補そのまま / c1=40本の能力(感性・発想・表現・キャラ・相性・知名度)アップ全部なし /
  c2=同じ増分を半分 / c3=c1+お金の増分(40本)半分 / c4=枠 年2回(効果そのまま) / c5=c4+c1 /
  c6=c2+既存の週イベント全体の能力・知名度アップも半分(event_scale_options の②と同じ向き。減る側は据え置き)
usage: python3 exp_late_events_tuning_1108_v0.py n [out.json] [cases,カンマ区切り]"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import exp_balance_snapshot_v0 as S2

ABIL = ("sense", "idea", "expr", "chara", "compat", "fame")
# cap=年ごとの追加枠 / late / lab=40本の能力アップ倍率 / lmoney=40本のお金増分倍率 / allab=既存含む全イベントの能力アップ倍率
CASES = {
    "before": dict(cap=0, late=False, lab=1, lmoney=1, allab=1),
    "c0": dict(cap=3, late=True, lab=1, lmoney=1, allab=1),
    "c1": dict(cap=3, late=True, lab=0, lmoney=1, allab=1),
    "c2": dict(cap=3, late=True, lab=0.5, lmoney=1, allab=1),
    "c3": dict(cap=3, late=True, lab=0, lmoney=0.5, allab=1),
    "c4": dict(cap=2, late=True, lab=1, lmoney=1, allab=1),
    "c5": dict(cap=2, late=True, lab=0, lmoney=1, allab=1),
    "c6": dict(cap=3, late=True, lab=0.5, lmoney=1, allab=0.5),
}
BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり", "ローテ", "必要充足", "やり込み"]

def patch(cs):
    raw = C._ev_add
    if cs["allab"] != 1:
        m = cs["allab"]
        C._ev_add = lambda s, k, a: raw(s, k, a * m if (a > 0 and k in ABIL) else a)
    ev_add = C._ev_add
    def late_apply(s, k):
        c = C._late_pick(s, k)
        if c is None: return
        for st, v in C.LATE_EVENTS[k][c]["eff"]:
            if st == "money":
                s.money += v * cs["lmoney"] if v > 0 else v
            elif v > 0 and st in ABIL:
                if cs["lab"] > 0: raw(s, st, v * cs["lab"]) if cs["allab"] == 1 else ev_add(s, st, v * cs["lab"] / cs["allab"])
            else:
                ev_add(s, st, v)
    C._late_apply = late_apply

def job(a):
    case, bi, seeds = a
    cs = CASES[case]
    S2.install(True)
    pol = S2.make2(BOTS[bi])
    fin = []
    C.NETA_ON = C.NETA_V2 = True
    C.EVENTS_APP = True
    C.APP_CAP_PER_YEAR = cs["cap"]; C.APP_LATE_ON = cs["late"]
    patch(cs)
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
                        late=sum(v for y, v in per_year.items() if y >= 6) / 10.0))
    return (case, bi), out

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    w = [r["win"] for r in rs if r["win"]]
    return dict(n=n, late=statistics.mean(r["late"] for r in rs), win=p(lambda r: r["win"]), fin=p(lambda r: r["fin"]),
                ds=p(lambda r: r["ds"]), bk=p(lambda r: r["bk"]), wy=statistics.median(w) if w else None)

def main():
    n = int(sys.argv[1]); outp = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else None
    cases = sys.argv[3].split(",") if len(sys.argv) > 3 else list(CASES)
    chunk = 25
    jobs = [(cs, bi, list(range(i, min(i + chunk, n)))) for cs in cases for bi in range(4) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    print(f"n={n} 4ボット（今の sim 既定・ネタ込・EVENTS_APP）")
    print("|案|ボット|6〜15年目の年あたり発火|15年内の初優勝%|決勝%|解散%|夜逃げ%|優勝年 中央|")
    print("|---|---|---|---|---|---|---|---|")
    for cs in cases:
        allr = []
        for bi in range(4):
            rs = res[(cs, bi)]; allr += rs; r = summ(rs); final[f"{cs}|{SHORT[bi]}"] = r
            print(f"|{cs}|{SHORT[bi]}|{r['late']:.2f}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|{r['wy']}|")
        r = summ(allr); final[f"{cs}|平均"] = r
        print(f"|{cs}|**平均**|{r['late']:.2f}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|{r['wy']}|", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
