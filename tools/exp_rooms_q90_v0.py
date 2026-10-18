#!/usr/bin/env python3
"""キュー90：引っ越し（お店で部屋を選ぶ）の実測。usage: python3 exp_rooms_q90_v0.py [n=1000] [variants=all]
部屋の段（家賃は今の生活費に上乗せ・4週ごと）：
  0 安アパート（今）     上乗せ 0       家で休む（完全休養・気分転換）の体力の戻り +0
  1 ふつうの部屋         上乗せ R1      +H1
  2 いい部屋             上乗せ R2      +H2（完全休養のメンタルも +1）
引っ越しの近似：所持金が「次の段の上乗せ×26（約2年分）」以上ある年初に1段上げる。所持金がマイナスの年初は安アパートに戻る。
案 "R{R1}-{R2}_H{H1}-{H2}"（円は万）。none は今のまま。式・既定値は変えない（スクリプト内の差し替えだけ）。ネタ込み。数値は全て【仮】。"""
import sys
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み"]
HOME = {"完全休養", "気分転換"}

def one(args):
    var, name, n = args
    S.install(True)
    rent = [0, 0, 0]; heal = [0.0, 0.0, 0.0]
    if var != "none":
        r, h = var.split("_")
        a, b = r[1:].split("-"); rent = [0, int(a) * 10_000, int(b) * 10_000]
        a, b = h[1:].split("-"); heal = [0.0, float(a), float(b)]
    st = {"room": 0, "w": 0, "yrs": [0, 0, 0]}
    o_rw, o_ry, o_rest = C.rift_weekend, C.run_year, B.do_rest
    def ry(pol, s, year, rng, **kw):
        if var != "none":
            if s.money < 0:
                st["room"] = 0
            elif st["room"] < 2 and s.money >= rent[st["room"] + 1] * 26:
                st["room"] += 1
        st["yrs"][st["room"]] += 1
        return o_ry(pol, s, year, rng, **kw)
    def rw(s, year, c0):
        st["w"] += 1
        if st["w"] % 4 == 0:
            s.money -= rent[st["room"]]
        return o_rw(s, year, c0)
    def rest(s, nm):
        o_rest(s, nm)
        if nm in HOME and st["room"]:
            B.add(s, "stamina", heal[st["room"]])
            if st["room"] == 2 and nm == "完全休養":
                B.add(s, "mental", 1)
    C.rift_weekend, C.run_year, B.do_rest = rw, ry, rest
    pol = S.make2(name)
    win = fin = ds = bk = 0; money = 0.0; yrs = [0, 0, 0]
    for i in range(n):
        st.update(room=0, w=0, yrs=[0, 0, 0])
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += bool(ever)
        ds += bool(s.__dict__.get("_dissolved")); bk += bool(s.__dict__.get("_bankrupt")); money += s.money
        for k in range(3): yrs[k] += st["yrs"][k]
    tot = sum(yrs) or 1
    return var, name, dict(win=100.0 * win / n, fin=100.0 * fin / n, ds=100.0 * ds / n, bk=100.0 * bk / n,
                           money=money / n / 10000, share=[100.0 * y / tot for y in yrs])

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["none", "R3-8_H5-10", "R3-8_H10-20", "R5-15_H10-20"]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(v, b, n) for v in variants for b in BOTS])
    print(f"# n={n}/ボット ネタ込み。部屋の年%=キャリアの年のうち 安/ふつう/いい部屋 に住んだ割合")
    print("案|ボット|優勝%|決勝%|解散%|夜逃げ%|最後の所持金(万)|部屋の年%(安/ふつう/いい)")
    for var, name, r in res:
        print(f"{var}|{SHORT[BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|{r['money']:.0f}|"
              + "/".join(f"{x:.0f}" for x in r["share"]))

if __name__ == "__main__":
    main()
