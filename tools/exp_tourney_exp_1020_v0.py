#!/usr/bin/env python3
"""大会の結果で経験点（5通貨）を配る案の実測（オーナー決定 2026-10-20・測るだけ）。本体の式・Swift・golden は触らない（スクリプト内のフックで足す）。数値は全て【仮】。
usage: python3 exp_tourney_exp_1020_v0.py [n=300] [variants=stage1|all|a,b,..] [out.json]
案 "{配り方}{量}[@最初の帯の倍率]"  例 "bm" "cl@0.85" "A@0.7"（A=今・配らない）
  配り方 a=5通貨に均等(各1/5) / b=不足しやすい語彙・胆力・存在感に厚く(各0.3・閃き間合い各0.05) / c=均等だが大会の種類で量を変える(道中大会×0.5・GP予選×1・GP復活/決勝×2)
  量 s/m/l = k=1/2/4。単位U=稽古1回分（主+副=生4点・供給スケールは稽古と同じ credit_currency 経由）
  配る量(U×k)：出場 0.25／道中大会の勝ち +0.75（出場込みで勝ち計1.0）／GP回戦 i(1〜5)の通過 +0.25×i／敗者復活の通過 +1.25／GP決勝の優勝 +3.0
  p1/p2/p4 = パワプロ準拠（5通貨均等）：量=U×縮め率(1・1/2・1/4)×［道中大会 勝1.0・負0.5／GP回戦i 通過 1+0.35(i-1)・敗退はその半分／復活通過2.4／決勝 優勝3.0・敗退1.5］
  +L{d} = GPの全回戦・復活・決勝のラインを +d（予選・決勝ライン補正）
  @k = RANK_COST_BANDS の最初の帯(能力0〜15・G→F)の倍率を ×k（k=1.0/0.85/0.7）
測定R：1年目だけ（各能力の最初の昇格週の中央値・全能力/演技4・年末全G%・センスF以上%・1年目に配った経験点(U)）
測定B：全キャリア（優勝/決勝/解散%）。ボット4種×ネタ無/込。ボットは差し替えの後に作る・Pool(maxtasksperchild=1)"""
import sys, json, os
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
import exp_first_rankup_v0 as R

BAND_BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
BAND_SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]
AB = R.AB
ABJ = {"sense": "センス", "idea": "発想", "expr": "表現", "chara": "華", "mental": "メンタル"}
_BANDS0 = list(B.RANK_COST_BANDS)
U = 4.0   # 稽古1回分（主+副の生の合計。例 ネタ作り 3+1）
LEVEL = {"s": 1.0, "m": 2.0, "l": 4.0, "q": 0.25, "t": 0.1, "v": 0.05, "1": 1.0, "2": 0.5, "4": 0.25}   # 1/2/4 は p（パワプロ準拠）の縮め率 ×1/×1/2/×1/4   # q/t/v = 小の1/4・1/10・1/20（2回目の追加測定）
_GP0 = (list(C.GP_ROUNDS), C.GP_REVIVAL_LINE, C.GP_FINAL_LINE)
DIST = {"a": {c: 0.2 for c in B.CURRENCIES},
        "b": {"hirameki": 0.05, "goi": 0.3, "maai": 0.05, "sonzaikan": 0.3, "tanryoku": 0.3},
        "c": {c: 0.2 for c in B.CURRENCIES}, "p": {c: 0.2 for c in B.CURRENCIES}}
TYPEW_C = {"road": 0.5, "round": 1.0, "final": 2.0}
STAGE1 = ["A", "A@0.85", "A@0.7"] + [d + l for d in "abc" for l in "sml"]

_SC0 = B.EXP_SUPPLY_SCALE
EXPACC = dict(train=0.0, tour=0.0, inside=False)   # 総量を保つ案（10/20）：稽古/大会で積んだ経験点(スケール後)の累計

def parse(var):
    k = 1.0; dl = 0.0
    sm = 1.0
    if "~" in var: var, ss = var.split("~"); sm = float(ss)   # ~s = 稽古の供給スケール(expSupplyScale)を ×s（大会の経験点は元のスケールのまま）
    if "+L" in var: var, ls = var.split("+L"); dl = float(ls)   # +L{d}: GPの全回戦・復活・決勝のラインを +d
    if "@" in var: var, ks = var.split("@"); k = float(ks)
    return var, k, dl, sm

def apply(var):
    v, k, dl, sm = parse(var)
    B.EXP_SUPPLY_SCALE = _SC0 * sm
    C.GP_ROUNDS[:] = [(w, ln + dl, lb) for (w, ln, lb) in _GP0[0]]; C.GP_REVIVAL_LINE = _GP0[1] + dl; C.GP_FINAL_LINE = _GP0[2] + dl
    B.RANK_COST_BANDS[:] = [(t, m * k if i == 0 else m) for i, (t, m) in enumerate(_BANDS0)]
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    return v

def install_exp(v, acc):
    """大会の結果処理（enter_tournament／_gp_perform）の後ろに経験点を足すフック。v=="A" は何もしない。acc["tot"]=配った累計(U)"""
    if v == "A": return
    dist, k = DIST[v[0]], LEVEL[v[1]]
    st = dict(i=0, rev=False)
    def give(units, typ, pw=None):
        if v[0] == "p": units = pw   # パワプロ準拠は下で U 倍率を直接渡す（負けは半分）
        w = TYPEW_C[typ] if v[0] == "c" else 1.0
        tot = units * k * w
        acc["tot"] += tot
        EXPACC["inside"] = True; sc = B.EXP_SUPPLY_SCALE; B.EXP_SUPPLY_SCALE = _SC0   # 大会分は元のスケール
        for c, f in dist.items(): B.credit_currency(s_ref[0], c, tot * U * f)
        B.EXP_SUPPLY_SCALE = sc; EXPACC["inside"] = False
    s_ref = [None]
    o_enter, o_gp, o_run = C.enter_tournament, C._gp_perform, C.run_year
    def enter(s, pol, t, rng):
        acted, won = o_enter(s, pol, t, rng)
        if acted:
            s_ref[0] = s; give(0.25 + (0.75 if won else 0), "road", 1.0 if won else 0.5)
        return acted, won
    def gp(s, line, rng, final):
        ok, sc = o_gp(s, line, rng, final)
        s_ref[0] = s
        if not final:
            st["i"] += 1; i = st["i"]
            give(0.25 + (0.25 * i if ok else 0), "round", (1 + 0.35 * (i - 1)) * (1.0 if ok else 0.5))
            if not ok and i == 5: st["rev"] = True
        elif st["rev"]:
            st["rev"] = False; give(0.25 + (1.25 if ok else 0), "final", 2.4 * (1.0 if ok else 0.5))
        else:
            give(0.25 + (3.0 if ok else 0), "final", 3.0 if ok else 1.5)
        return ok, sc
    def run_year(pol, s, year, rng, **kw):
        st["i"] = 1 if kw.get("gp_seed") else 0; st["rev"] = False
        return o_run(pol, s, year, rng, **kw)
    C.enter_tournament, C._gp_perform, C.run_year = enter, gp, run_year

class Stop(Exception): pass

def rank_job(args):
    var, bi, neta, seeds = args
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = bool(neta)
    for k, v in R.PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = R.OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    v = apply(var)   # ボットは差し替えの後に作る
    acc = dict(tot=0.0)
    install_exp(v, acc)
    bot = [R.Spa(R.Cafe(R.PCasual2())), R.Spa(R.Cafe(R.PRotate())), C.CareerBalanced(), C.CareerSmart()][bi]
    st = dict(wk=0, f={a: None for a in AB})
    o_pour, o_run = B.pour_all, C.run_year
    def pour(s):
        o_pour(s); st["wk"] += 1
        for a in AB:
            if st["f"][a] is None and getattr(s, a) >= 15: st["f"][a] = st["wk"]
    B.pour_all = pour
    out = []
    for sd in seeds:
        st["wk"] = 0; st["f"] = {a: None for a in AB}; acc["tot"] = 0.0; box = {}
        def run_year(pol, s, year, rng, **kw):
            r = o_run(pol, s, year, rng, **kw); box["s"] = s; raise Stop
        C.run_year = run_year
        try: C.run_career(bot, C.BASE_SEED + sd)
        except Stop: pass
        s = box["s"]; f = st["f"]
        fw = lambda xs: min([x for x in xs if x is not None], default=None)
        out.append(dict(f=dict(f), first=fw(f.values()), first4=fw([f[a] for a in AB[:4]]),
                        allG=all(getattr(s, a) < 15 for a in AB), allG4=all(getattr(s, a) < 15 for a in AB[:4]),
                        senseF=s.sense >= 15, tot=acc["tot"]))
    B.pour_all = o_pour; C.run_year = o_run
    return ("R", var, bi, neta), out

def band_job(args):
    var, bi, neta, seeds = args
    import exp_balance_snapshot_v0 as S2
    S2.install(bool(neta))
    v = apply(var)
    o_cc = B.credit_currency
    def cc(s, currency, val):
        if val > 0: EXPACC["tour" if EXPACC["inside"] else "train"] += val * B.EXP_SUPPLY_SCALE
        o_cc(s, currency, val)
    B.credit_currency = cc
    install_exp(v, dict(tot=0.0))
    pol = S2.make2(BAND_BOTS[bi])
    out = []
    for i in seeds:
        EXPACC["train"] = EXPACC["tour"] = 0.0
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        out.append(dict(win=first is not None, fin=bool(ever), ds=bool(s.__dict__.get("_dissolved")), et=EXPACC["train"], eo=EXPACC["tour"]))
    return ("B", var, bi, neta), out

def job(a): return rank_job(a[1:]) if a[0] == "R" else band_job(a[1:])

def med(vals):
    v = sorted(x if x is not None else 99 for x in vals)
    m = v[len(v) // 2]
    return ">48" if m == 99 else m

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    a2 = sys.argv[2] if len(sys.argv) > 2 else "stage1"
    variants = STAGE1 if a2 in ("stage1", "all") else a2.split(",")
    outp = sys.argv[3] if len(sys.argv) > 3 else None
    chunk = 25
    jobs = [(m, v, bi, neta, list(range(i, min(i + chunk, n))))
            for m in os.environ.get("MODES", "RB") for v in variants for bi in range(4) for neta in ((True,) if os.environ.get("NETA_ONLY") else (False, True)) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for key, out in p.imap_unordered(job, jobs):
            res.setdefault(key, []).extend(out)
    pct = lambda rs, f: 100.0 * sum(1 for r in rs if f(r)) / len(rs)
    final = {}
    for (m, v, bi, neta), rs in sorted(res.items()):
        nt = "ネタ込" if neta else "ネタ無"
        if m == "R":
            r = dict(n=len(rs), med=med([x["first"] for x in rs]), med4=med([x["first4"] for x in rs]),
                     per={ABJ[a]: med([x["f"][a] for x in rs]) for a in AB},
                     allG=pct(rs, lambda x: x["allG"]), allG4=pct(rs, lambda x: x["allG4"]), senseF=pct(rs, lambda x: x["senseF"]),
                     tot=sum(x["tot"] for x in rs) / len(rs))
            print(f"R|{v}|{R.BOTNAMES[bi]}|{nt}|n={r['n']}|med={r['med']}|med4={r['med4']}|per={r['per']}|allG={r['allG']:.1f}|allG4={r['allG4']:.1f}|senseF={r['senseF']:.1f}|tot={r['tot']:.2f}", flush=True)
            final[f"R|{v}|{R.BOTNAMES[bi]}|{nt}"] = r
        else:
            r = dict(n=len(rs), win=pct(rs, lambda x: x["win"]), fin=pct(rs, lambda x: x["fin"]), ds=pct(rs, lambda x: x["ds"]),
                     et=sum(x["et"] for x in rs) / len(rs), eo=sum(x["eo"] for x in rs) / len(rs))
            print(f"B|{v}|{BAND_SHORT[bi]}|{nt}|n={r['n']}|win={r['win']:.1f}|fin={r['fin']:.1f}|ds={r['ds']:.1f}|et={r['et']:.1f}|eo={r['eo']:.1f}", flush=True)
            final[f"B|{v}|{BAND_SHORT[bi]}|{nt}"] = r
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
