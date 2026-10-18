#!/usr/bin/env python3
"""キュー97：体調ダウン（パワプロの怪我）が実際に起きるようにする率の実測。usage: python3 exp_injury_v1.py [n=1000] [variants=all]
今：INJURY_TH=20（この体力未満で練習/キツいバイト→抽選）と STAMINA_GATE=20（体力20未満は練習できない）が同じ値＝練習ではまず起きない。
案 "TH{x}_P{y}"：体力 x 未満で練習（またはキツいバイト）を選ぶと (x−体力)×y の確率でダウン（3週休み・メンタル−5）。ゲートは20のまま。
式・既定値は変えない（スクリプト内の差し替えだけ）。ネタ込み。数値は全て【仮】。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み", "放置"]

def one(args):
    var, name, n = args
    th, p = (float(x[2:] if x.startswith("TH") else x[1:]) for x in var.split("_"))
    S.install(True)
    C.INJURY_TH, C.INJURY_P_PER = th, p
    pol = S.make2(name)
    inj = win = fin = ds = yrs = 0; careers_inj = 0
    for i in range(n):
        C.RUN_TRACK = {}
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        k = C.RUN_TRACK.get("injuries", 0)
        inj += k; careers_inj += k > 0
        yrs += s.__dict__.get("_yr", 10)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
    C.RUN_TRACK = None
    return var, name, dict(per_year=inj / yrs, careers=100.0 * careers_inj / n, win=100.0 * win / n,
                           fin=100.0 * fin / n, ds=100.0 * ds / n)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["TH20_P0.02", "TH35_P0.01", "TH35_P0.02", "TH40_P0.01", "TH50_P0.005", "TH50_P0.01"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS], chunksize=1)
    print(f"# n={n}/ボット ネタ込み。ダウン=1年あたりの回数・一度でもダウンしたキャリア%")
    print("案|ボット|ダウン/年|ダウン経験%|優勝%|決勝%|解散%")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['per_year']:.2f}|{r['careers']:.0f}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}")

if __name__ == "__main__":
    main()
