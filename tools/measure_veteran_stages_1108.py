#!/usr/bin/env python3
"""ベテラン向けの大会・仕事 V1〜V4 の実測（2026-11-08）。既存モジュールは変えず、実行時の差し替えだけで足す。
docs/late_game_content_v0.md §3。測り方は exp_late_events_tuning_1108_v0.py と同じ（EVENTS_APP・ネタ込・4ボット・15年・Pool(maxtasksperchild=1)+chunksize=1）。
V1(18週,6年目〜,ライン32,30万,FAME_SMALL)・V3(33週,11年目〜,ライン36,60万,FAME_MID)＝tournament_of を差し替えて通常の大会として足す。
V2(23週,知名度30+・体力40+,12万,fame+1)・V4(36週,8年目〜・ネタ2本+(sim のボットは最大2本＝3本は届かないので近似),売上10万+15万×知名度/100,fame+2)＝判定なしの仕事。
  その週の pol.choose を横取りして効果を足し、("offer",None)＝何もしない週として返す（稽古・休みの代わりに埋まる）。体力消費は入れない。
案: base=なし / v24=V2+V4 / v1234=4本全部。
usage: python3 measure_veteran_stages_1108.py n [out.json] [cases]"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import balance_sim as B
import exp_balance_snapshot_v0 as S2

CASES = {"base": (), "v24": ("V2", "V4"), "v1234": ("V1", "V2", "V3", "V4")}
BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり", "ローテ", "必要充足", "やり込み"]
YR = [0]

def job(a):
    case, bi, seeds = a
    st = CASES[case]
    S2.install(True)
    pol = S2.make2(BOTS[bi])
    C.NETA_ON = C.NETA_V2 = True
    C.EVENTS_APP = True
    C.APP_CAP_PER_YEAR = 0; C.APP_LATE_ON = False   # 比べる軸はV1〜V4だけ＝終盤イベント候補は入れない（本体の既定）
    if "V1" in st or "V3" in st:
        raw = C.tournament_of
        V1 = dict(name="V1春の賞レース", line=32, prize=300_000, fame=C.FAME_SMALL, osaka=False, ok=lambda y, s: y >= 6)
        V3 = dict(name="V3ベテラン杯", line=36, prize=600_000, fame=C.FAME_MID, osaka=False, ok=lambda y, s: y >= 11)
        def tournament_of(s, week):
            if week == 18 and "V1" in st: return V1
            if week == 33 and "V3" in st: return V3
            return raw(s, week)
        C.tournament_of = tournament_of
    cnt = {"v2": 0, "v4": 0}
    if "V2" in st or "V4" in st:
        oc = pol.choose
        def choose(s, week, offer, rng):
            y = YR[0]
            if week == 23 and "V2" in st and s.fame >= 30 and s.stamina >= 40:
                s.money += 120_000; B.add(s, "fame", 1); cnt["v2"] += 1
                return "offer", None
            if week == 36 and "V4" in st and y >= 8 and len(getattr(s, "netas", None) or []) >= 2:
                s.money += int(100_000 + 150_000 * min(100, s.fame) / 100.0); B.add(s, "fame", 2); cnt["v4"] += 1
                return "offer", None
            return oc(s, week, offer, rng)
        pol.choose = choose
    blank = [0]
    orest = B.do_rest
    def do_rest(s, *a, **k):
        if YR[0] == 12: blank[0] += 1
        return orest(s, *a, **k)
    B.do_rest = do_rest
    fin = []; y12 = []
    o = C.run_year
    def run_year(pol_, s, year, rng, **kw):
        YR[0] = year
        if year == 12: blank[0] = 0
        r = o(pol_, s, year, rng, **kw)
        if r[2]: fin.append(year)
        if year == 12 and not r[0] and not s.__dict__.get("_dissolved") and not s.__dict__.get("_bankrupt"):
            y12.append(blank[0])
        return r
    C.run_year = run_year
    out = []
    for i in seeds:
        fin.clear(); y12.clear(); cnt["v2"] = cnt["v4"] = 0
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        out.append(dict(win=bool(first), fin=bool(fin), ds=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt")),
                        money=s.money, full=(first is None and not d.get("_dissolved") and not d.get("_bankrupt")),
                        blank=(y12[0] if y12 else None), v2=cnt["v2"], v4=cnt["v4"]))
    return (case, bi), out

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    full = [r["money"] for r in rs if r["full"]]
    bl = [r["blank"] for r in rs if r["blank"] is not None]
    return dict(n=n, win=p(lambda r: r["win"]), fin=p(lambda r: r["fin"]), ds=p(lambda r: r["ds"]),
                money_full=statistics.median(full) if full else None, money_all=statistics.median([r["money"] for r in rs]),
                blank=statistics.mean(bl) if bl else None, nb=len(bl), v2=statistics.mean(r["v2"] for r in rs), v4=statistics.mean(r["v4"] for r in rs))

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
    print(f"n={n} 4ボット平均")
    print("|案|優勝%|決勝%|解散%|15年目所持金 中央(15年走り切り)|終了時所持金 中央(全員)|12年目の空白週 平均(n)|V2発火/V4発火(1キャリア平均)|")
    print("|---|---|---|---|---|---|---|---|")
    for cs in cases:
        rows = [summ(res[(cs, bi)]) for bi in range(4)]
        for bi in range(4): final[f"{cs}|{SHORT[bi]}"] = rows[bi]
        allr = [r for bi in range(4) for r in res[(cs, bi)]]
        # 4ボット平均＝ボットごとの値の平均（中央値は各ボットの中央値の平均）
        avg = lambda k: statistics.mean(r[k] for r in rows if r[k] is not None)
        final[f"{cs}|平均"] = dict(win=avg("win"), fin=avg("fin"), ds=avg("ds"), money_full=avg("money_full"), money_all=avg("money_all"), blank=avg("blank"), v2=avg("v2"), v4=avg("v4"))
        print(f"|{cs}|{avg('win'):.1f}|{avg('fin'):.1f}|{avg('ds'):.1f}|{avg('money_full'):,.0f}|{avg('money_all'):,.0f}|{avg('blank'):.1f}|{avg('v2'):.2f}/{avg('v4'):.2f}|", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
