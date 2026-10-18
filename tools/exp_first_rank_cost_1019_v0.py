#!/usr/bin/env python3
"""最初の昇格コスト案比べ（オーナー判断の材料・2026-10-19）。sim 側のパラメータ差し替えだけ（Swift・golden・本体の式は触らない）。数値は全て【仮】。
usage: python3 exp_first_rank_cost_1019_v0.py [n=300] [variants=all] [out.json]
案 "{q93の記法}[+SE{倍率}]"：q93の記法は exp_q93_retune_v0 と同じ（A=今／R2M@0.8／RHM@0.9…）。
  +SE1.5 = センス・表現の1段あたりの通貨コストを 1/1.5 に（＝この2能力の経験点の供給を1.5倍）。
測定R：1年目だけ走らせて最初の昇格の週・年末全G・センスF以上（exp_first_rankup_v0 と同じ前提・ボット4種）
測定B：全キャリアを走らせて優勝/決勝/解散%（exp_q93_retune_v0 組B＝combined7_bands_v0 の帯と同じ指標・ボット4種）。ネタ無/ネタ込の両方。"""
import sys, json, copy, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
import exp_q93_retune_v0 as Q
import exp_first_rankup_v0 as R

BAND_BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
BAND_SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]
VARIANTS = ["A", "GF0.7", "GF0.5", "GF0.3", "GFE0.7", "GFE0.5", "GFE0.3"]
_BANDS0 = list(B.RANK_COST_BANDS)

def apply(var):
    # GF{k}: 能力値0〜15（G→F）帯の通貨コスト倍率だけ×k／GFE{k}: さらに15〜25（F→E）帯も×k。他は無変更
    B.RANK_COST_BANDS[:] = _BANDS0
    if var != "A":
        k = float(var[2:]) if var.startswith("GF") and not var.startswith("GFE") else float(var[3:])
        n = 1 if not var.startswith("GFE") else 2
        B.RANK_COST_BANDS[:] = [(t, m * k if i < n else m) for i, (t, m) in enumerate(_BANDS0)]
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}

class Stop(Exception): pass

def rank_job(args):
    var, bi, neta, seeds = args
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = bool(neta)
    for k, v in R.PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = R.OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    apply(var)   # ボットは差し替えの後に作る
    bot = [R.Spa(R.Cafe(R.PCasual2())), R.Spa(R.Cafe(R.PRotate())), C.CareerBalanced(), C.CareerSmart()][bi]
    AB = R.AB
    st = {"wk": 0, "first": None, "first4": None}
    o_pour, o_run = B.pour_all, C.run_year
    def pour(s):
        o_pour(s); st["wk"] += 1
        if st["first"] is None and max(getattr(s, a) for a in AB) >= 15: st["first"] = st["wk"]
        if st["first4"] is None and max(getattr(s, a) for a in AB[:4]) >= 15: st["first4"] = st["wk"]
    B.pour_all = pour
    out = []
    for sd in seeds:
        st.update(wk=0, first=None, first4=None); box = {}
        def run_year(pol, s, year, rng, **kw):
            r = o_run(pol, s, year, rng, **kw); box["s"] = s; raise Stop
        C.run_year = run_year
        try: C.run_career(bot, C.BASE_SEED + sd)
        except Stop: pass
        s = box["s"]
        out.append(dict(first=st["first"], first4=st["first4"], allG=all(getattr(s, a) < 15 for a in AB),
                        allG4=all(getattr(s, a) < 15 for a in AB[:4]), senseF=s.sense >= 15))
    B.pour_all = o_pour; C.run_year = o_run
    return ("R", var, bi, neta), out

def band_job(args):
    var, bi, neta, seeds = args
    import exp_balance_snapshot_v0 as S2
    S2.install(bool(neta))
    apply(var)
    pol = S2.make2(BAND_BOTS[bi])
    out = []
    for i in seeds:
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        out.append(dict(win=first is not None, fin=bool(ever), ds=bool(s.__dict__.get("_dissolved"))))
    return ("B", var, bi, neta), out

def job(a): return rank_job(a[1:]) if a[0] == "R" else band_job(a[1:])

def med(vals):
    v = sorted(x if x is not None else 99 for x in vals)
    m = v[len(v) // 2]
    return ">48" if m == 99 else m

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else VARIANTS
    outp = sys.argv[3] if len(sys.argv) > 3 else None
    chunk = 25
    jobs = [(m, v, bi, neta, list(range(i, min(i + chunk, n))))
            for m in "RB" for v in variants for bi in range(4) for neta in (False, True) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(job, jobs):
            res.setdefault(key, []).extend(out)
    pct = lambda rs, f: 100.0 * sum(1 for r in rs if f(r)) / len(rs)
    final = {}
    for (m, v, bi, neta), rs in sorted(res.items()):
        nt = "ネタ込" if neta else "ネタ無"
        if m == "R":
            r = dict(n=len(rs), med=med([x["first"] for x in rs]), med4=med([x["first4"] for x in rs]), allG=pct(rs, lambda x: x["allG"]),
                     allG4=pct(rs, lambda x: x["allG4"]), senseF=pct(rs, lambda x: x["senseF"]))
            print(f"R|{v}|{R.BOTNAMES[bi]}|{nt}|n={r['n']}|med={r['med']}|med4={r['med4']}|allG={r['allG']:.1f}|allG4={r['allG4']:.1f}|senseF={r['senseF']:.1f}", flush=True)
            final[f"R|{v}|{R.BOTNAMES[bi]}|{nt}"] = r
        else:
            r = dict(n=len(rs), win=pct(rs, lambda x: x["win"]), fin=pct(rs, lambda x: x["fin"]), ds=pct(rs, lambda x: x["ds"]))
            print(f"B|{v}|{BAND_SHORT[bi]}|{nt}|n={r['n']}|win={r['win']:.1f}|fin={r['fin']:.1f}|ds={r['ds']:.1f}", flush=True)
            final[f"B|{v}|{BAND_SHORT[bi]}|{nt}"] = r
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
