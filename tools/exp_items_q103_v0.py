#!/usr/bin/env python3
"""キュー103：アイテムを増やす（回復ドリンク大・舞台衣装・喉のケア用品）の値段と効果の実測。usage: python3 exp_items_q103_v0.py [n=1000] [variants=all]
原則：アイテムで能力は上がらない。体調ダウンは §97 推奨（体力50未満で練習→(50−体力)×0.005）を入れた状態で測る。
買い方（ボット共通の近似）：所持金が値段の3倍以上ある時に買う。
  D  回復ドリンク大：20,000円・体力+20・年4本まで。週末に体力40未満なら買って飲む
  C  舞台衣装：80,000円・年1。その年の本番（大会・GP）のブレ幅 −2
  T  喉のケア用品：20,000円・年1。その年の体調ダウンの確率が半分
式・既定値は変えない（スクリプト内の差し替えだけ）。ネタ込み。数値は全て【仮】。"""
import sys
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]
DRINK = (20_000, 20.0, 4); COSTUME = (80_000, 2.0); THROAT = 20_000

def one(args):
    var, name, n = args
    S.install(True)
    C.INJURY_TH, C.INJURY_P_PER = 50.0, 0.005
    st = {"y": 0, "drink": 0, "cost": False, "thr": False, "spent": 0}
    o_rw, o_ry, o_bw = C.rift_weekend, C.run_year, B.blur_width
    p0 = C.INJURY_P_PER
    def ry(pol, s, year, rng, **kw):
        st.update(drink=0, cost=False, thr=False)
        if "C" in var and s.money >= COSTUME[0] * 3:
            s.money -= COSTUME[0]; st["cost"] = True; st["spent"] += COSTUME[0]
        if "T" in var and s.money >= THROAT * 3:
            s.money -= THROAT; st["thr"] = True; st["spent"] += THROAT
        C.INJURY_P_PER = p0 * (0.5 if st["thr"] else 1.0)
        return o_ry(pol, s, year, rng, **kw)
    def rw(s, year, c0):
        out = o_rw(s, year, c0)
        if "D" in var and s.stamina < 40 and st["drink"] < DRINK[2] and s.money >= DRINK[0] * 3:
            s.money -= DRINK[0]; B.add(s, "stamina", DRINK[1]); st["drink"] += 1; st["spent"] += DRINK[0]
        return out
    def bw(m):
        return max(0.0, o_bw(m) - (COSTUME[1] if st["cost"] else 0.0))
    C.rift_weekend, C.run_year, B.blur_width = rw, ry, bw
    pol = S.make2(name)
    win = fin = ds = inj = 0; spent = money = 0.0
    for i in range(n):
        st["spent"] = 0; C.RUN_TRACK = {}
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
        inj += C.RUN_TRACK.get("injuries", 0); spent += st["spent"]; money += s.money
    C.RUN_TRACK = None
    return var, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n, inj=inj / n,
                           spent=spent / n / 10000, money=money / n / 10000)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else ["none", "D", "C", "T", "DCT"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS])
    print(f"# n={n}/ボット ネタ込み・体調ダウン§97推奨入り。使った額=10年でアイテムに使った額")
    print("案|ボット|優勝%|決勝%|解散%|ダウン回数|使った額(万)|最後の所持金(万)")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['inj']:.2f}|{r['spent']:.0f}|{r['money']:.0f}")

if __name__ == "__main__":
    main()
