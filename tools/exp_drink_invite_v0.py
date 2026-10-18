#!/usr/bin/env python3
"""キュー102：先輩・後輩の飲みの誘いを、不定期に何度も来る軽い形にした時の実測。usage: python3 exp_drink_invite_v0.py [n=1000] [variants=all]
案 "P{率}_{行く|断る}"：大会のない週末に率 p で誘いが来る。行く＝所持金−5000・体力−10・メンタル+1（先輩の時は 1/2 で 発想+0.5）。
断る＝何も起きない。誘いの抽選はボットの乱数とは別の乱数（本編の乱数の並びを変えない）。式・既定値は変えない。ネタ込み。数値は全て【仮】。"""
import sys, random
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]

def one(args):
    var, name, n = args
    S.install(True)
    p = 0.0; go = True
    if var != "none":
        a, b = var.split("_"); p = float(a[1:]); go = (b == "行く")
    st = {"cnt": 0}
    o_rw = C.rift_weekend
    def rw(s, year, c0):
        out = o_rw(s, year, c0)
        if p > 0 and st["rng"].random() < p:
            st["cnt"] += 1
            if go:
                s.money -= 5_000; B.add(s, "stamina", -10); B.add(s, "mental", 1)
                if st["rng"].random() < 0.5: B.add(s, "idea", 0.5)
        return out
    C.rift_weekend = rw
    pol = S.make2(name)
    win = fin = ds = 0; cnt = 0; money = 0.0
    for i in range(n):
        st["rng"] = random.Random(9_000_000 + i); st["cnt"] = 0
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever); ds += bool(s.__dict__.get("_dissolved"))
        cnt += st["cnt"]; money += s.money
    return var, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n, cnt=cnt / n, money=money / n / 10000)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["none", "P0.04_行く", "P0.04_断る", "P0.08_行く"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS], chunksize=1)
    print(f"# n={n}/ボット ネタ込み。誘い=キャリアでの回数")
    print("案|ボット|優勝%|決勝%|解散%|誘い回数|最後の所持金(万)")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['cnt']:.1f}|{r['money']:.0f}")

if __name__ == "__main__":
    main()
