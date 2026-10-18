#!/usr/bin/env python3
"""キュー98：1〜3月（第37〜48週）に小さな大会を1つ足す（グランプリで負けた後の目標）の実測。
usage: python3 exp_winter_cup_v0.py [n=1000] [variants=all]
案 "W{週}_L{ライン}"：その週に「寒梅漫才杯」（架空名・芸歴10年内・東京・手元25万・知名度小）を足す。"none" は今のまま。
GP の週（30/39/41/43/45/47）とは重ねない。式・既定値は変えない（スクリプト内の差し替えだけ）。ネタ込み。数値は全て【仮】。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み", "放置"]

def one(args):
    var, name, n = args
    S.install(True)
    if var != "none":
        w, l = (int(x[1:]) for x in var.split("_"))
        C.TOURNAMENTS[w] = dict(name="寒梅漫才杯", line=l, prize=250_000, fame=C.FAME_SMALL, osaka=False,
                                ok=lambda year, s: year <= 10)
        C.EVENT_WEEKS.add(w)
    cnt = {"e": 0, "w": 0}
    o_ent = C.enter_tournament
    def ent(s, pol, t, rng):
        acted, ok = o_ent(s, pol, t, rng)
        if acted and t["name"] == "寒梅漫才杯":
            cnt["e"] += 1; cnt["w"] += bool(ok)
        return acted, ok
    C.enter_tournament = ent
    pol = S.make2(name)
    win = fin = ds = bk = 0; entered = won = 0; money = 0.0
    for i in range(n):
        C.RUN_TRACK = {}
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        entered += cnt["e"]; won += cnt["w"] > 0; cnt.update(e=0, w=0)
        win += first is not None; fin += bool(ever)
        ds += bool(s.__dict__.get("_dissolved")); bk += bool(s.__dict__.get("_bankrupt")); money += s.money
    C.RUN_TRACK = None
    return var, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n, bk=100.0 * bk / n,
                           ent=entered / n, wonc=100.0 * won / n, money=money / n / 10000)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["none", "W44_L26", "W44_L30", "W46_L26", "W46_L30"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS])
    print(f"# n={n}/ボット ネタ込み。出場=キャリアでの寒梅杯の出場回数・一度は優勝した%")
    print("案|ボット|優勝(GP)%|決勝%|解散%|夜逃げ%|寒梅出場回|寒梅優勝経験%|最後の所持金(万)")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|"
              f"{r['ent']:.1f}|{r['wonc']:.0f}|{r['money']:.0f}")

if __name__ == "__main__":
    main()
