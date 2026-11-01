#!/usr/bin/env python3
"""周回で「伸びしろの天井」も上がる形の実測（オーナー決定 11/02）。測るだけ・数値は全て【仮】。
本体の式・GameCore・Swift・golden は触らない（exp_calib_all_1101_v0 の差し替えの上に、このスクリプトの中で足すだけ）。
土台＝推奨 A（k=0.5・準決勝+6・決勝/復活+1・M2・D0.6）＋周回ボーナス 型1（経験 4/点・上限160／所持金 3万/点・上限100万）。
足す天井のつまみ（周回の点 P）：
  ja,jp : 成長予算（キャリア累計）の上乗せ J0 = ja·P^jp（dynasty_v2_research §5 の J0 曲線の形・前倒しで一度に足す）
  cb    : 年の成長上限 CAP_CURVE の基準と下限に +cb·P（canon_v2.apply の才能解放 +0.02/pt と同じ形・累計予算が毎年少しずつ厚くなる）
  dd    : 演技系の上限 ABILITY_CAP と逓減 GROWTH_DECAY_D を 120+dd·P（trophy_design_v1 の「D=120+pt」の形）
  cp    : 初期の相性 +cp·P（上限6・exp_calib_all_1101 と同じ）
  ca,cam: 初期の相性 +ca·P（上限 cam・既定10）。解散の原因側（相性が低いとすれ違いがたまる）を直す案。cp と同じ物で上限だけ違う
  cpw   : 相性の曲線の形（+ca·P^cpw・上限 cam）。0.5 なら前寄せ（2周目から効く）
  ex2,exq: 型1 の上に足す初期経験点 ex2·(P/38)^exq（上限なし・配分は型1と同じ）。頂点寄せ（集めきった時の1年目用）
  sm    : 型1の初期経験点のうち「間」（ネタ合わせの通貨）に入れる割合（既定 0.27）。0 にすると残りを比で配り直す
          ＝原因側の案（初期経験点で間が足りてしまい、ボットが相性の上がるネタ合わせを選ばなくなるのを防ぐ）
  cg    : 相性の上限 COMPAT_CAP を +cg·P（参考）
優勝した後も15年目まで続ける（連覇を数えるため。初優勝までの乱数列は 1101 と同じ＝初優勝の率は 1101 と一致する）。
usage: python3 exp_calib_meta_1102_v0.py n variants P(例 0,8,10,20,38) [neta=both|on|off] [out.json]
  variants は "名前" か "名前@k=v;k=v"（下の VAR と exp_calib_all_1101_v0.BASE のキー）。
指標：win 15年内の初優勝／y1 1年目の優勝／w10 10年内／streak 最長連覇の平均（優勝した組の中）／s3 3連覇以上％／s15 15連覇％／
  wins 15年の優勝回数の平均（全体）／fin 決勝に1回でも／ds 初優勝前の解散（1101 と同じ定義）／dsa 15年のどこかで解散／c3 3年目末の相性（平均）"""
import sys, json, inspect, textwrap
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import exp_calib_all_1101_v0 as E

A = dict(k=0.5, sf=6.0, fn=1.0, M=2.0, D=0.6)
EXTRA = dict(ja=0.0, jp=1.0, cb=0.0, dd=0.0, cg=0.0, ca=0.0, cam=10.0, cpw=1.0, ex2=0.0, exq=1.0, sm=0.27)
VAR = {
    "A":   dict(),                                   # 型1だけ（1101 の推奨 A そのまま）
}
SHORT = E.SHORT
P2 = 8   # 2周目相当の点：trophy_design_v1 §3 v1.1 の初回収量 6〜11pt の中ほど（図鑑は1周目では0〜1件）

def cfg_of(name):
    base, _, ov = name.partition("@")
    c = dict(E.BASE); c.update(A); c.update(EXTRA); c.update(VAR.get(base, {}))
    if base not in VAR:
        ov = base if not ov else base + ";" + ov
    for kv in filter(None, ov.split(";")):
        k, v = kv.split("=")
        c[k] = v if k == "w" else float(v)
    return c

def patch_career():
    """run_career を初優勝で止めず15年目まで続ける形に（優勝の判定・乱数はそのまま）"""
    src = textwrap.dedent(inspect.getsource(C.run_career))
    old = "        if won:\n            return year, s, best_stage, ever_final\n"
    assert old in src
    src = src.replace(old, "")
    exec(src, C.__dict__)

def setup(c, P):
    if c["sm"] != 0.27:
        rest = {k: v for k, v in E.SPLIT.items() if k != "maai"}; t = sum(rest.values())
        E.SPLIT.clear(); E.SPLIT.update({k: v * (1 - c["sm"]) / t for k, v in rest.items()}); E.SPLIT["maai"] = c["sm"]
    # 予算の上乗せ J0 は E.setup の patch_growth に bud·P で渡す（その他のつまみは setup_after）
    J0 = c["ja"] * (P ** c["jp"]) if P > 0 else 0.0
    c["bud"] = J0 / P if P > 0 else 0.0          # E.setup は gb = bud·P を累計予算に足す
    patch_career()
    return J0

def setup_after(c, P):
    """E.setup（canon_v2.apply が CAP_CURVE を戻す）の後に入れるつまみ"""
    base = C.CAP_CURVE
    C.CAP_CURVE = (base[0] + c["cb"] * P, base[1], base[2] + c["cb"] * P)   # canon_v2.apply の才能解放と同じ形（基準と下限）
    if c["dd"]:
        B.ABILITY_CAP = 120 + c["dd"] * P
        B.GROWTH_DECAY_D = 120 + c["dd"] * P
    if c["cg"]:
        B.COMPAT_CAP = B.COMPAT_CAP + c["cg"] * P

def job(a):
    var, P, bi, neta, seeds = a
    c = cfg_of(var)
    J0 = setup(c, P)
    rec, st = E.setup(c, P, neta, False)
    setup_after(c, P)
    if (c["ca"] > 0 or c["ex2"] > 0) and P > 0:
        add = min(c["cam"], c["ca"] * P ** c["cpw"]); ex2 = c["ex2"] * (P / 38.0) ** c["exq"]; on = C.new_state
        def new_state(*a_, **kw):
            s = on(*a_, **kw); s.compat = min(float(B.COMPAT_CAP), s.compat + add)
            for cur, r in E.SPLIT.items(): setattr(s, "exp_" + cur, getattr(s, "exp_" + cur) + ex2 * r)
            return s
        C.new_state = new_state
    pol = E.S2.make2(E.BOTS[bi])     # ボットは差し替えの後に作る
    w = dict(wins=[], ds=None, c3=None)
    o = C.run_year
    def run_year(pol_, s, year, rng, **kw):
        r = o(pol_, s, year, rng, **kw)
        if r[0]: w["wins"].append(year)
        if year == 3: w["c3"] = s.compat
        if w["ds"] is None and getattr(s, "_dissolved", False): w["ds"] = year
        return r
    C.run_year = run_year
    out = []
    for i in seeds:
        rec["fin"] = []; rec["allG"] = None; st.update(wk=0, first=None)
        w.update(wins=[], ds=None, c3=None)
        C.run_career(pol, C.BASE_SEED + i)
        ws = w["wins"]; first = ws[0] if ws else None
        best = cur = 0; prev = None
        for y in ws:
            cur = cur + 1 if prev == y - 1 else 1; best = max(best, cur); prev = y
        out.append(dict(win=first, n=len(ws), best=best, fin=bool(rec["fin"]),
                        ds=w["ds"] is not None and (first is None or w["ds"] < first), dsa=w["ds"] is not None,
                        c3=w["c3"]))
    return (var, P, bi, neta), out, J0

def summ(rs):
    n = len(rs); p = lambda f: 100.0 * sum(1 for r in rs if f(r)) / n
    ch = [r for r in rs if r["win"]]
    c3 = [r["c3"] for r in rs if r["c3"] is not None]
    return dict(n=n, win=p(lambda r: r["win"]), y1=p(lambda r: r["win"] == 1), w10=p(lambda r: r["win"] and r["win"] <= 10),
                streak=(sum(r["best"] for r in ch) / len(ch)) if ch else 0.0, s3=p(lambda r: r["best"] >= 3),
                s15=p(lambda r: r["best"] >= 15), smax=max((r["best"] for r in rs), default=0),
                wins=sum(r["n"] for r in rs) / n, fin=p(lambda r: r["fin"]), ds=p(lambda r: r["ds"]),
                dsa=p(lambda r: r["dsa"]), c3=sum(c3) / len(c3) if c3 else 0.0)

def main():
    n = int(sys.argv[1]); variants = sys.argv[2].split(",")
    Ps = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0]
    nm = sys.argv[4] if len(sys.argv) > 4 else "both"
    netas = {"both": (False, True), "on": (True,), "off": (False,)}[nm]
    outp = sys.argv[5] if len(sys.argv) > 5 else None
    chunk = 25
    jobs = [(v, P, bi, ne, list(range(i, min(i + chunk, n))))
            for v in variants for P in Ps for bi in range(4) for ne in netas for i in range(0, n, chunk)]
    res, j0 = {}, {}
    with Pool(maxtasksperchild=1) as pool:
        for key, out, J0 in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(key, []).extend(out); j0[(key[0], key[1])] = J0
    final = {}
    for key, rs in sorted(res.items(), key=lambda kv: (variants.index(kv[0][0]), kv[0][1], kv[0][3], kv[0][2])):
        v, P, bi, ne = key
        r = summ(rs); r["J0"] = j0[(v, P)]; final[json.dumps(key, ensure_ascii=False)] = r
        print(f"{v}|P{P}|J0={r['J0']:.1f}|{SHORT[bi]}|{'込' if ne else '無'}|n={r['n']}|win={r['win']:.1f}|y1={r['y1']:.1f}"
              f"|w10={r['w10']:.1f}|streak={r['streak']:.2f}|s3={r['s3']:.1f}|s15={r['s15']:.1f}|smax={r['smax']}"
              f"|wins={r['wins']:.2f}|fin={r['fin']:.1f}|ds={r['ds']:.1f}|dsa={r['dsa']:.1f}|c3={r['c3']:.1f}", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
