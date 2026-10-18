#!/usr/bin/env python3
"""キュー96：テレビ等の仕事（オファー）に名前を付ける＋続けて受けると漫才の腕が少しずつ落ちる（お金か漫才か）の実測。
usage: python3 exp_offer_named_v0.py [n=1000] [variants=all]
案：
  none   今のまま（お金重視／経験重視の2種）
  N      名前付き4種（ひな壇・ロケ・ラジオ・営業）。値は下の NAMED【仮】。来る率は今のまま
  N_D{x}_K{k}  N に加えて、直近6週に k 回以上オファーを受けていたら、受けるたびにセンスと表現を x ずつ下げる（テレビ慣れ）
ボットは来たオファーを必ず受ける＝一番オファーを受ける遊び方（人は選べる）。式・既定値は変えない。ネタ込み。数値は全て【仮】。"""
import sys
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み", "放置"]
NAMED = [   # 平均は今と同じ（収入18万・知名度2・表現+1/回）。ひな壇とラジオは喋りの腕が付く・ロケと営業はお金
    dict(name="ひな壇", income=120_000, fame=3, ability=("expr", 2), stam=-15),
    dict(name="ラジオ", income=100_000, fame=2, ability=("expr", 2), stam=-10),
    dict(name="ロケ", income=220_000, fame=2, ability=None, stam=-25),
    dict(name="営業", income=280_000, fame=1, ability=None, stam=-20),
]
WINDOW = 6

def one(args):
    var, name, n = args
    S.install(True)
    named = var.startswith("N"); D = K = 0
    for p in var.split("_")[1:]:
        if p.startswith("D"): D = float(p[1:])
        if p.startswith("K"): K = int(p[1:])
    st = {"w": 0, "hist": [], "offers": 0, "decay": 0.0}
    o_roll, o_do, o_rw = B.roll_offer, B.do_offer, C.rift_weekend
    def roll(s, rng):
        o = o_roll(s, rng)
        if o is not None and named:
            o = dict(NAMED[[B.OFFER_EXP["name"], B.OFFER_MONEY["name"]].index(o["name"]) * 2 + (rng.random() < 0.5)])
        return o
    def do(s, offer):
        o_do(s, offer)
        st["offers"] += 1
        recent = sum(1 for w in st["hist"] if st["w"] - w < WINDOW)
        if D > 0 and recent >= K:
            B.add(s, "sense", -D); B.add(s, "expr", -D); st["decay"] += D
        st["hist"].append(st["w"])
    def rw(s, year, c0):
        st["w"] += 1
        return o_rw(s, year, c0)
    B.roll_offer, B.do_offer, C.rift_weekend = roll, do, rw
    pol = S.make2(name)
    win = fin = ds = 0; money = offers = decay = 0.0
    for i in range(n):
        st.update(w=0, hist=[], offers=0, decay=0.0)
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
        money += s.money; offers += st["offers"]; decay += st["decay"]
    return var, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n,
                           money=money / n / 10000, offers=offers / n, decay=decay / n)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["none", "N", "N_D0.1_K3", "N_D0.2_K3", "N_D0.2_K4", "N_D0.5_K4"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS], chunksize=1)
    print(f"# n={n}/ボット ネタ込み。ボットは来たオファーを必ず受ける。落ちた腕=キャリアでセンス・表現それぞれ下がった合計")
    print("案|ボット|優勝%|決勝%|解散%|最後の所持金(万)|オファー回数|落ちた腕")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['money']:.0f}|{r['offers']:.1f}|{r['decay']:.1f}")

if __name__ == "__main__":
    main()
