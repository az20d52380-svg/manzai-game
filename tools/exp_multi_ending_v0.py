#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
複数エンディングの到達率の実測（キュー82・2026-10-15）。本体の式は変えず、スクリプト内で結末を後付け判定する。
使い方: python3 exp_multi_ending_v0.py [キャリア数=1000]
設定: A=現行（イベントON・ネタOFF） / B=NETA_ON+NETA_V2（q60-62 推奨の飽きD込み）。ボット: PCasual2/PRotate/PNeedV3 + 偏りボット。
解散は「本体に無い新しい仕組み」＝週ごとの相性の推移（sim は相性が下がらない）に条件を仮に当てて判定（ボットは予告に反応しない＝回避は偶然のみ）。
"""
import sys
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_stuck_v0 import make

BOTS = ["PCasual2", "PRotate", "PNeedV3", "相方と過ごすだけ", "ネタ作りだけ", "無料稽古3週:バイト1週"]
YEARS = 10

def install(setting):
    V.apply(); C.EVENTS_ON = True
    C.NETA_ON = C.NETA_V2 = (setting == "B")
    if setting == "B":
        C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2
    B.enable_places(True); B.enable_paid_rests(True)
    o_year, o_roll = C.run_year, B.roll_offer
    def run_year(pol, s, year, rng, **kw):
        r = o_year(pol, s, year, rng, **kw)
        d = s.__dict__
        d.setdefault("_ye", []).append((s.compat, d.get("_fy", 0) + (1 if r[2] else 0) > 0, s.fame))
        d["_fy"] = d.get("_fy", 0) + (1 if r[2] else 0)
        d.setdefault("_stage", []).append(r[1]); d.setdefault("_fyr", []).append(bool(r[2]))
        return r
    def roll(s, rng):
        s.__dict__.setdefault("_traj", []).append(s.compat)
        return o_roll(s, rng)
    C.run_year, B.roll_offer = run_year, roll

def one(args):
    setting, name, n = args
    install(setting)
    pol = make(name)
    recs = []
    for i in range(n):
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        recs.append(dict(seed=C.BASE_SEED + i, stg=d.get("_stage", []), fyr=d.get("_fyr", []), win=first, bk=bool(d.get("_bankrupt")), traj=d.get("_traj", []), ye=d.get("_ye", []),
                         fy=d.get("_fy", 0), stage=stage, ever=ever, netas=len(d.get("netas", []) or []),
                         fame=s.fame, money=s.money))
    return setting, name, recs

# ---- 解散の仮条件：二人の関係（すれ違いゲージ）で決める。成績は引き金の一つ（売れても売れなくても加算）----
import random
def strain_diss(r, seed, thr=30.0, warn=22.0, drift=0.5, shock_p=0.2, shock=6.0, perf=3.0, gain_rel=3.0, avert=10.0, win=8):
    """週ごと: 相性が上がった週 → ゲージ-gain_rel / 上がらない週 → +drift*(20-相性)/20。年末: すれ違いの出来事が確率shock_pで+shock（成績と無関係）、
    決勝に出た年（多忙）・準々決勝すら通れなかった年（腐る）は+perf（成績は両極端どちらも引き金）。ゲージが warn で予告→win週内に相性が上がれば-avert。thr で解散。
    返り値=(解散した週 or None, 予告が出た回数, 回避した回数)"""
    rng = random.Random(seed * 7919 + 13)
    t, ye, st, fyears = r["traj"], r["ye"], r.get("stg", []), r.get("fyr", [])
    g, warned, nwarn, nav = 0.0, False, 0, 0
    n = len(t)
    for i in range(1, n):
        if t[i] > t[i - 1]:
            g = max(0.0, g - gain_rel)
            if warned and i <= warned_end: nav += 1; g = max(0.0, g - avert); warned = False
        else:
            g += drift * (20 - t[i]) / 20.0
        if i % 52 == 0:
            y = i // 52 - 1
            if rng.random() < shock_p: g += shock
            if perf:
                if y < len(fyears) and fyears[y]: g += perf
                elif y < len(st) and st[y] < 3: g += perf
        if not warned and g >= warn:
            warned, warned_end = True, i + win; nwarn += 1
        if warned and i > warned_end: warned = False
        if g >= thr: return i, nwarn, nav
    return None, nwarn, nav

DISS = {"S1 標準(閾30・出来事20%/年・成績±3)": dict(),
        "S2 成績を引き金にしない(成績±0)": dict(perf=0.0),
        "S3 ゆるめ(閾40・出来事15%/年)": dict(thr=40.0, warn=30.0, shock_p=0.15)}

def ending(r, diss=None):
    end = len(r["traj"])
    if diss is not None:
        w = strain_diss(r, r["seed"], **diss)[0]
        if w is not None and w < end - 1:
            return "解散(成績良 決勝経験あり)" if r["fy"] > 0 else "解散(成績悪 決勝なし)"
    if r["bk"]: return "夜逃げ"
    cp = r["ye"][-1][0] if r["ye"] else 0
    if r["win"] is not None:
        if r["win"] <= 4: return "若き王者(優勝4年内)"
        return "優勝で勇退(相性15↑=真の頂)" if cp >= 15 else "優勝で勇退"
    if r["fy"] == 0: return "続けた二人(決勝なし 相性15↑)" if cp >= 15 else "あきらめ(決勝なし 相性15未満)"
    if cp >= 15: return "T-2 トゥルー(相性15↑+決勝1回↑)"
    return "10年で区切り(決勝あり 相性15未満)"

ORDER = ["夜逃げ", "解散(成績良 決勝経験あり)", "解散(成績悪 決勝なし)", "あきらめ(決勝なし 相性15未満)", "続けた二人(決勝なし 相性15↑)", "10年で区切り(決勝あり 相性15未満)", "T-2 トゥルー(相性15↑+決勝1回↑)", "優勝で勇退", "優勝で勇退(相性15↑=真の頂)", "若き王者(優勝4年内)"]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(s, b, n) for s in ("A", "B") for b in BOTS]
    with Pool(10) as p: res = p.map(one, jobs)
    for setting in ("A", "B"):
        print(f"\n## 設定{setting}（{'現行: ネタなし' if setting=='A' else 'NETA_ON+V2 飽きD'}）n={n}")
        for dn, df in [("(解散なし=今の決まり)", None)] + [(k, v) for k, v in DISS.items()]:
            print(f"\n### {dn}")
            print("| ボット | " + " | ".join(ORDER) + " | 相性10年末中央 |")
            print("|---|" + "---|" * (len(ORDER) + 1))
            for st, nm, recs in res:
                if st != setting: continue
                cnt = {k: 0 for k in ORDER}
                for r in recs: cnt[ending(r, df)] += 1
                cps = sorted(r["ye"][-1][0] for r in recs if r["ye"])
                print(f"| {nm} | " + " | ".join(f"{100*cnt[k]/n:.1f}" for k in ORDER) + f" | {cps[len(cps)//2]:.0f} |")
        for dn, kw in DISS.items():
            for st, nm, recs in res:
                if st != setting or nm not in ("PCasual2", "PRotate", "PNeedV3"): continue
                x = [strain_diss(r, r["seed"], **kw) for r in recs]
                print(f"[予告] {dn} {nm}: 予告あり{100*sum(a[1]>0 for a in x)/n:.0f}% 回避{100*sum(a[2]>0 for a in x)/n:.0f}%")
        print("\n### 参考: 相性の分布（10年末 or 終了時）と週数")
        for st, nm, recs in res:
            if st != setting: continue
            cps = sorted(r["ye"][-1][0] for r in recs if r["ye"])
            wk = sorted(len(r["traj"]) for r in recs)
            print(f"{nm}: 相性p10/p50/p90={cps[len(cps)//10]:.0f}/{cps[len(cps)//2]:.0f}/{cps[9*len(cps)//10]:.0f} 週数中央{wk[len(wk)//2]} 決勝経験{100*sum(r['fy']>0 for r in recs)/n:.0f}% 優勝{100*sum(r['win'] is not None for r in recs)/n:.1f}%")

if __name__ == "__main__":
    main()
