#!/usr/bin/env python3
"""総合の較正（オーナー決定 10/20〜11/01 を全部同時に入れた状態）の実測。測るだけ・数値は全て【仮】。
本体の式・GameCore・Swift・golden は触らない（このスクリプトの中で定数とフックを差し替えるだけ）。
入れる変更：
 1. 結成15年（YEARS=15）＋11年目以降だけ 決勝・敗者復活のライン +M ＋ 11年目以降の成長予算の加算 ×D^(年-10)
    （exp_fifteen_years_1020_v0 と同じ差し替え）
 2. 大会の経験点（パワプロ式 p・量 k＝p1 なら1.0・p2 なら0.5）。配り方 w=c なら種類で量を変える（道中大会×0.5・GP回戦×1・復活/決勝×2）、
    w=p はそのまま。最初の帯 G→F の倍率 0.7。稽古の経験点は減らさない。難しさは GP の 3回戦/準々決勝/準決勝/決勝(+復活) の
    ラインを段ごとに +r3/+qf/+sf/+fn（敗者復活は +fn+rv）で戻す（exp_tourney_exp_1020_v0 のフックと同じ配り方）
 3. 周回ボーナス 型1（全部加算）：周回の点 P × ex（経験点・上限 excap・5通貨 35/27/18/10/10%）と P × mo万円（上限100万）を初期に足す
    （exp_meta_start_bonus_1020_v0 と同じ）
 4. 温泉に一泊の効果を体力回復だけに（メンタル+2 も外す。相性の効果は今すでに無い）
 5. THE HANA（女性コンビだけ）：週 32/37/42/44（1回戦=動画審査→2回戦→準決勝→決勝・敗者復活なし）・ライン「難」22/38/56/70・
    優勝 手元250万/知名度+8（exp_the_hana_1025_v0 の install を使う）。女性の系列（g=F）の時だけ入れる。
usage: python3 exp_calib_all_1101_v0.py n variants P(例 0,10,30) [neta=both|on|off] [g=M|F|MF] [out.json]
  variants: 下の VAR の名前をカンマ区切り。"名前@k=v;k=v" で上書きも可（例 "B1@sf=6;fn=8"）。
ボット4種：bs=0（既定）＝帯の組（のんびり改/ローテ/必要充足/やり込み・exp_balance_snapshot_v0.make2）／
  bs=1＝アプリ相当の組（のんびり改+カフェ温泉/ローテ+カフェ温泉/CareerBalanced/CareerSmart・exp_first_rankup_v0.setup）。
  rr=1＝すれ違いの予告に応えるボット（感度用）、cp=周回の点1あたりの初期相性（参考・上限6）、bud=周回の点1あたりにキャリア累計の成長予算へ足す量（参考）。ボットは差し替えの後に作る・Pool(maxtasksperchild=1)。
指標：15年内の初優勝 win／初優勝の年 1年目・1-5/6-10/11-15／10年内の初優勝 w10／決勝に1回でも fin／最初の昇格週 rk（中央値・1年目48週）／
  1年目末に全能力G allG／夜逃げ bk／途中解散 ds／10年目の所持金 m10（10年目末まで残った人の中央値・万）／HANA 優勝 hw・決勝 hf"""
import sys, json, inspect, textwrap, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S2
import exp_first_rankup_v0 as R

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり", "ローテ", "必要充足", "やり込み"]
AB = R.AB
U = 4.0
SPLIT = dict(hirameki=.35, maai=.27, goi=.18, sonzaikan=.10, tanryoku=.10)
TYPEW_C = {"road": 0.5, "round": 1.0, "final": 2.0}
HANA_LINES = (22, 38, 56, 70)
HANA_PRIZE = (2_500_000, 8)

# 既定＝全部入り（M8D0.6・p 中間 k=0.75・配り方c・帯0.7・ライン補正なし・周回 経験中/所持金中・温泉は体力だけ）
BASE = dict(yrs=15, M=8.0, D=0.6, k=0.75, w="c", band=0.7, r3=0.0, qf=0.0, sf=0.0, fn=0.0,
            ex=4.0, excap=160.0, mo=3.0, onsen=1, rr=0, wr=0.5, wg=1.0, wf=2.0, rv=0.0, bs=0, cp=0.0, bud=0.0)
VAR = {
    "T10":  dict(yrs=10, M=0, D=1.0, k=0, band=1.0, ex=0, mo=0, onsen=0),   # 今（10年制・何も入れない）
    "F15":  dict(k=0, band=1.0, ex=0, mo=0, onsen=0),                        # 15年(M8D0.6)だけ
    "X0":   dict(),                                                          # 全部入り・ライン補正なし
}

def cfg_of(name):
    base, _, ov = name.partition("@")
    c = dict(BASE); c.update(VAR.get(base, {}))
    if base not in VAR:   # 名前そのものを "k=v;k=v" と読む
        ov = base if not ov else base + ";" + ov
    for kv in filter(None, ov.split(";")):
        k, v = kv.split("=")
        c[k] = v if k == "w" else float(v)
    return c

def patch_growth(f, gb=0.0):
    """11年目以降の成長予算の加算 ×f^(年-10)（exp_fifteen_years と同じ）＋参考：累計予算に定数 gb を足す（周回の点で予算も足す案）"""
    src = textwrap.dedent(inspect.getsource(C.run_year))
    old = "sum(max(floor, base - slope * (k - 1))"
    assert old in src
    src = src.replace(old, "_gb + sum(_gf(k) * max(floor, base - slope * (k - 1))")
    C._gf = lambda k: (f ** (k - 10)) if k > 10 else 1.0
    C._gb = gb
    exec(src, C.__dict__)

def install_exp(c, s_ref):
    """大会の結果処理の後ろに経験点を足す（exp_tourney_exp_1020_v0 の p 準拠と同じ量・k 倍・w=c なら種類で重み）"""
    k = c["k"]
    if k <= 0: return
    st = dict(i=0, rev=False)
    def give(pw, typ):
        tot = pw * k * (dict(road=c["wr"], round=c["wg"], final=c["wf"])[typ] if c["w"] == "c" else 1.0)
        for cur in B.CURRENCIES: B.credit_currency(s_ref[0], cur, tot * U * 0.2)
    o_enter, o_gp, o_run = C.enter_tournament, C._gp_perform, C.run_year
    def enter(s, pol, t, rng):
        acted, won = o_enter(s, pol, t, rng)
        if acted: s_ref[0] = s; give(1.0 if won else 0.5, "road")
        return acted, won
    def gp(s, line, rng, final):
        ok, sc = o_gp(s, line, rng, final)
        s_ref[0] = s
        if not final:
            st["i"] += 1; i = st["i"]
            give((1 + 0.35 * (i - 1)) * (1.0 if ok else 0.5), "round")
            if not ok and i == 5: st["rev"] = True
        elif st["rev"]:
            st["rev"] = False; give(2.4 * (1.0 if ok else 0.5), "final")
        else:
            give(3.0 if ok else 1.5, "final")
        return ok, sc
    def run_year(pol, s, year, rng, **kw):
        st["i"] = 1 if kw.get("gp_seed") else 0; st["rev"] = False
        return o_run(pol, s, year, rng, **kw)
    C.enter_tournament, C._gp_perform, C.run_year = enter, gp, run_year

def install_meta(c, P):
    tot_e = min(c["excap"], c["ex"] * P); mo = min(1_000_000, c["mo"] * 10_000 * P)
    cp = min(6.0, c["cp"] * P)   # 参考：周回ボーナスに初期の相性も足す案（決定ではない・decision_brief §13 A の材料）
    if tot_e <= 0 and mo <= 0 and cp <= 0: return
    on = C.new_state
    def new_state(*a, **kw):
        s = on(*a, **kw)
        for cur, r in SPLIT.items(): setattr(s, "exp_" + cur, getattr(s, "exp_" + cur) + tot_e * r)
        s.money += mo
        if cp: s.compat = min(float(B.COMPAT_CAP), s.compat + cp)
        return s
    C.new_state = new_state

def setup(c, P, neta, female):
    gb = c["bud"] * P
    if (c["yrs"] > 10 and c["D"] != 1.0) or gb: patch_growth(c["D"] if c["yrs"] > 10 else 1.0, gb)   # 先に（install が run_year を包むため）
    if c["bs"]: R.setup(bool(neta))   # bs=1：アプリ相当のボット組（exp_first_rankup_v0.setup・周回/THE HANA の文書と同じ条件）
    else: S2.install(bool(neta))      # bs=0：帯のボット組（exp_balance_snapshot_v0・15年/大会の経験点の文書と同じ条件）
    C.YEARS = int(c["yrs"])
    C.RIFT_RESPOND = bool(c["rr"])   # 感度用：すれ違いの予告に「向き合う」で応えるボット（既定0＝応えない・今までの測定と同じ）
    b0 = list(B.RANK_COST_BANDS)
    B.RANK_COST_BANDS[:] = [(t, m * c["band"] if i == 0 else m) for i, (t, m) in enumerate(b0)]
    import bots_v3
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    if c["onsen"] and "温泉に一泊" in B.RESTS:
        rec, _ = B.RESTS["温泉に一泊"]; B.RESTS["温泉に一泊"] = (rec, ("mental", 0))   # 体力回復だけ
    add = {2: c["r3"], 3: c["qf"], 4: c["sf"]}
    C.GP_ROUNDS[:] = [(w, ln + add.get(i, 0.0), lb) for i, (w, ln, lb) in enumerate(C.GP_ROUNDS)]
    fl0, rl0 = C.GP_FINAL_LINE + c["fn"], C.GP_REVIVAL_LINE + c["fn"] + c["rv"]
    if female:
        import exp_the_hana_1025_v0 as H
        H.install(HANA_LINES, *HANA_PRIZE)
    s_ref = [None]
    install_exp(c, s_ref)
    install_meta(c, P)
    rec = dict(fin=[], allG=None)
    o2 = C.run_year
    def run_year(pol, s, year, rng, **kw):
        s._cur_year = year
        up = c["M"] if year > 10 else 0.0
        C.GP_FINAL_LINE, C.GP_REVIVAL_LINE = fl0 + up, rl0 + up
        r = o2(pol, s, year, rng, **kw)
        if r[2]: rec["fin"].append(year)
        if year == 1: rec["allG"] = all(getattr(s, a) < 15 for a in AB)
        return r
    C.run_year = run_year
    st = dict(wk=0, first=None)
    o_pour = B.pour_all
    def pour(s):
        o_pour(s); st["wk"] += 1
        if st["first"] is None and st["wk"] <= 48 and max(getattr(s, a) for a in AB) >= 15: st["first"] = st["wk"]
    B.pour_all = pour
    return rec, st

def job(a):
    var, P, bi, neta, female, seeds = a
    c = cfg_of(var)
    rec, st = setup(c, P, neta, female)
    if c["bs"]: pol = [R.Spa(R.Cafe(R.PCasual2())), R.Spa(R.Cafe(R.PRotate())), C.CareerBalanced(), C.CareerSmart()][bi]
    else: pol = S2.make2(BOTS[bi])   # ボットは差し替えの後に作る
    out = []
    for i in seeds:
        rec["fin"] = []; rec["allG"] = None; st.update(wk=0, first=None)
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
        d = s.__dict__
        out.append(dict(win=first, fin=bool(rec["fin"]), fin10=any(y <= 10 for y in rec["fin"]),
                        ds=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt")), rk=st["first"], allG=bool(rec["allG"]),
                        m10=(ml[9][0] if len(ml) > 9 and ml[9] else None),
                        hw=bool(d.get("_hana_win")), hf=bool(d.get("_hana_fin"))))
    return (var, P, bi, neta, female), out

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    w = [r["win"] for r in rs if r["win"]]
    rk = sorted(r["rk"] or 99 for r in rs); m10 = [r["m10"] / 10000 for r in rs if r["m10"] is not None]
    return dict(n=n, win=p(lambda r: r["win"]), y1=p(lambda r: r["win"] == 1),
                wd=[100.0 * sum(1 for y in w if lo <= y <= hi) / n for lo, hi in ((1, 5), (6, 10), (11, 15))],
                w10=p(lambda r: r["win"] and r["win"] <= 10), fin=p(lambda r: r["fin"]), fin10=p(lambda r: r["fin10"]),
                rk=rk[n // 2], allG=p(lambda r: r["allG"]), bk=p(lambda r: r["bk"]), ds=p(lambda r: r["ds"]),
                m10=statistics.median(m10) if m10 else None, hw=p(lambda r: r["hw"]), hf=p(lambda r: r["hf"]))

def main():
    n = int(sys.argv[1]); variants = sys.argv[2].split(",")
    Ps = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0]
    nm = sys.argv[4] if len(sys.argv) > 4 else "both"
    netas = {"both": (False, True), "on": (True,), "off": (False,)}[nm]
    g = sys.argv[5] if len(sys.argv) > 5 else "M"
    fems = [x == "F" for x in g]
    outp = sys.argv[6] if len(sys.argv) > 6 else None
    chunk = 25
    jobs = [(v, P, bi, ne, fe, list(range(i, min(i + chunk, n))))
            for v in variants for P in Ps for fe in fems for bi in range(4) for ne in netas for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out)
    final = {}
    for key, rs in sorted(res.items(), key=lambda kv: str(kv[0])):
        v, P, bi, ne, fe = key
        r = summ(rs); final[json.dumps(key, ensure_ascii=False)] = r
        print(f"{v}|P{P}|{'F' if fe else 'M'}|{SHORT[bi]}|{'込' if ne else '無'}|n={r['n']}|win={r['win']:.1f}|y1={r['y1']:.1f}"
              f"|wd={'/'.join(f'{x:.1f}' for x in r['wd'])}|w10={r['w10']:.1f}|fin={r['fin']:.1f}|fin10={r['fin10']:.1f}|rk={r['rk']}"
              f"|allG={r['allG']:.1f}|bk={r['bk']:.1f}|ds={r['ds']:.1f}|m10={r['m10'] if r['m10'] is None else round(r['m10'])}"
              + (f"|hw={r['hw']:.1f}|hf={r['hf']:.1f}" if fe else ""), flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
