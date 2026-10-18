#!/usr/bin/env python3
"""知名度の「その他の伸び」係数 ×0.6 vs ×1.0 で決勝到達が逆転する理由の診断（docs/diag_fame_mult_v0.md）。式・既定値は変えない（子プロセス内の上書きのみ）。
exp_q60_q62_remeasure_v1.one を包んで 行動の内訳・テレビ慣れ・能力・知名度・イベント・回戦通過を集計。
usage: python3 diag_fame_mult_v0.py [n=300] [variants=base,nofat,nooff,nofinal,noweird,clampfame]"""
import sys, statistics, collections
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import exp_money_after_merge_v0 as M
import exp_q60_q62_remeasure_v1 as R

KEYS = {"0.6": "D+G他x0.6(現状=推奨)", "1.0": "D+G他x1.0"}
ABIL = ("sense", "idea", "expr", "chara", "mental", "compat")

def one(args):
    mult, app, bot, n, var = args
    cnt = collections.Counter(); ev = collections.Counter()
    careers = []; cur = {}
    # --- 仮説ごとの上書き（子プロセス内だけ） ---
    fl = set(var.split("+"))
    if "nofat" in fl: B.OFFER_FATIGUE_K = 10**6
    if "nofinal" in fl: C.FAME_FINAL_BONUS = 0.0
    if "nostam" in fl: B.STAM_PEN = []          # 体力ペナルティ無し（本番時の体力の影響を切る）
    if "stamfull" in fl: pass
    ro = B.roll_offer
    def roll(s, rng):
        o = ro(s, rng)
        if o is not None:
            cnt["offer_rolled"] += 1
            if s.fame < 20 and C.EVENTS_ON: cnt["weird_conv"] += 1
        if "nooff" in fl: return None
        return o
    B.roll_offer = roll
    if "noweird" in fl:   # 変な仕事への置換を無効化＝fame<20 でも本物のオファーが出る：run_year内の閾値を見せかけで外す
        def roll2(s, rng):
            o = roll(s, rng)
            if o is not None and s.fame < 20:
                s.__dict__["_fk"] = s.fame; s.fame = 20.0   # 直後の判定だけ 20 に見せ、すぐ戻す（下のラッパで復元）
            return o
        B.roll_offer = roll2
    def fix(s):
        if "_fk" in s.__dict__: s.fame = s.__dict__.pop("_fk")
    po = B.pour_all
    def pour(s): fix(s); return po(s)
    B.pour_all = pour
    do = B.do_offer
    def d_offer(s, o):
        if "_fk" in s.__dict__: s.fame = s.__dict__.pop("_fk")
        cnt["offer_taken"] += 1
        wk = getattr(s, "_wk", None)
        if wk is not None and B.offer_fatigued(s, wk): cnt["fatigue_hit"] += 1
        return do(s, o)
    B.do_offer = d_offer
    # noweird: オファーを受けなかった週でも fame を復元する
    ry_ = C.run_year
    def run_year(pol, s, year, rng, **kw):
        s.__dict__.pop("_fk", None)
        r = ry_(pol, s, year, rng, **kw)
        s.__dict__.pop("_fk", None)
        cur.setdefault("years", []).append(dict(y=year, stage=r[1], fin=bool(r[2]), won=bool(r[0]), fame=s.fame,
                                                ab={k: getattr(s, k) for k in ABIL}))
        return r
    C.run_year = run_year
    rc = C.run_career
    def run_career(*a, **kw):
        cur.clear(); cur["acts"] = collections.Counter()
        r = rc(*a, **kw)
        s = r[1]; cur["app"] = dict(s.__dict__.get("_app", {}).get("counts", {}))
        careers.append(dict(cur)); return r
    C.run_career = run_career
    # 行動の内訳：Policy.choose を包む（M.one が make2 で作る前にクラスを包む）
    import exp_balance_snapshot_v0 as S
    mk = S.make2
    def make2(name):
        p = mk(name); ch = p.choose
        def choose(s, week, offer, rng):
            fix(s)
            act, arg = ch(s, week, offer, rng)
            cur["acts"][act + ("+offer可" if offer else "")] += 1
            return act, arg
        p.choose = choose; return p
    S.make2 = make2
    gp = collections.defaultdict(lambda: [0, 0, 0.0, 0.0, 0.0, 0.0])   # 回戦(ライン近似)別: 本数,通過,jitsu,体力,相性,ライン
    gpf = C._gp_perform
    def gpp(s, line, rng, final):
        ok, sc = gpf(s, line, rng, final)
        k = min((16, 24, 32, 43, 72, 74), key=lambda L: abs(L - line)) if not final else 99
        g = gp[k]; g[0] += 1; g[1] += bool(ok); g[2] += B.jitsuryoku(s); g[3] += s.stamina; g[4] += s.compat; g[5] += line
        return ok, sc
    C._gp_perform = gpp
    oa, oe = C._others_apply, C._apply_event
    def oa_(s, k): ev["o:" + k] += 1; return oa(s, k)
    def oe_(s, e): ev["table"] += 1; return oe(s, e)
    C._others_apply, C._apply_event = oa_, oe_
    key, _, _, r = R.one((KEYS[mult], app, bot, n))
    # --- 集計 ---
    N = len(careers)
    acts = collections.Counter()
    for c in careers: acts.update(c.get("acts", {}))
    wk = sum(acts.values())
    yrs = collections.defaultdict(list)
    for c in careers:
        for y in c.get("years", []): yrs[y["y"]].append(y)
    ev_app = collections.Counter()
    for c in careers: ev_app.update(c.get("app", {}))
    out = dict(mult=mult, app=app, bot=bot, n=N, win=r["win"], fin=r["fin"], weeks=wk, acts=dict(acts),
               offer_rolled=cnt["offer_rolled"], offer_taken=cnt["offer_taken"], fatigue_hit=cnt["fatigue_hit"], weird=cnt["weird_conv"],
               yrs={}, stage={}, ev=dict(ev_app if app else ev))
    for y in (1, 2, 3, 5, 7, 10):
        L = yrs.get(y, [])
        if not L: continue
        out["yrs"][y] = dict(m=len(L), fame=statistics.median(v["fame"] for v in L),
                             ab={k: sum(v["ab"][k] for v in L) / len(L) for k in ABIL},
                             fin=100.0 * sum(v["fin"] for v in L) / len(L))
    py = sum(len(v) for v in yrs.values())
    for k in range(1, 6):
        out["stage"][k] = 100.0 * sum(1 for v in yrs.values() for y in v if y["stage"] >= k) / max(1, py)
    out["years_played"] = py
    out["gp"] = {str(k): dict(n=v[0], pass_=100.0 * v[1] / v[0], jitsu=v[2] / v[0], stam=v[3] / v[0], compat=v[4] / v[0], line=v[5] / v[0]) for k, v in gp.items() if v[0]}
    return out

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    vars_ = sys.argv[2].split(",") if len(sys.argv) > 2 else ["base"]
    jobs = [(m, a, b, n, v) for v in vars_ for m in KEYS for a in (False, True) for b in M.BOTS]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, jobs, chunksize=1)   # chunksize=1 必須：同じ子プロセスに複数案が載ると上書きが漏れる
    import json
    for _ in range(3):   # 原因不明で稀に1年目で全員終わる異常実行（週数/キャリアが極端に少ない）が出る＝検出して撮り直す
        bad = [i for i, r in enumerate(res) if r["weeks"] < 200 * r["n"]]
        if not bad: break
        print(f"# 異常実行 {len(bad)} 件を再実行", file=sys.stderr)
        with Pool(maxtasksperchild=1) as pool:
            for i, r in zip(bad, pool.map(one, [jobs[i] for i in bad], chunksize=1)): res[i] = r
    for v, j in zip([x[4] for x in jobs], res): j["var"] = v
    print(json.dumps(res, ensure_ascii=False))

if __name__ == "__main__":
    main()
