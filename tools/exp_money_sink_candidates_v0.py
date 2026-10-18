#!/usr/bin/env python3
"""能力・経験点に変わらない吸い込み口の案の測定。usage: python3 exp_money_sink_candidates_v0.py [n=300] [cands=all]
money_after_merge_v0 の one()（全部入り・ネタ込み・同ボット）をそのまま使い、年の頭に「見た目と記録だけの出費」を差し込む（効果は能力に一切返さない＝出費のみ）。
式・既定値は変えない。案は既定で無効（SINK=None）。金額は万円。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M

# 案: 名前 -> 規則リスト。("every", 年あたり金額万, 残金>=X万) ／ ("stage", [価格万...], 買う余裕=価格+X万)
CANDS = {
    "base": [],
    "A単独ライブ年1": [("every", 120, 400)],
    "A2段階買い": [("stage", [100, 250, 500], 300)],
    "B仕送りおごり": [("every", 56, 300)],
    "C衣装小道具": [("every", 150, 600)],
    "D A2+B+C": [("stage", [100, 250, 500], 300), ("every", 56, 300), ("every", 150, 600)],
}
SINK = None

def install_sink(rules):
    o_ry = C.run_year
    st = {"last": 99, "stage": 0, "spent": 0.0}
    def ry(pol, s, year, rng, **kw):
        if year <= st["last"]: st["stage"] = 0; st["spent"] = 0.0
        st["last"] = year
        for r in rules:
            if r[0] == "every":
                if s.money >= r[2] * 10000: s.money -= r[1] * 10000; st["spent"] += r[1]
            else:
                i = st["stage"]
                if i < len(r[1]) and s.money >= (r[1][i] + r[2]) * 10000:
                    s.money -= r[1][i] * 10000; st["stage"] += 1; st["spent"] += r[1][i]
        return o_ry(pol, s, year, rng, **kw)
    C.run_year = ry

def one(args):
    cand, name, n = args
    install_sink(CANDS[cand])      # M.one が C.run_year を包む前に内側へ入れる
    r = M.one(("all", True, name, n))
    return cand, name, r[3]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    cands = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else list(CANDS)
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(c, b, n) for c in cands for b in M.BOTS])
    print(f"# n={n}/ボット 全部入り・ネタ込み。所持金は万円 Q1/中央/Q3。段%=終了時 <0/0-300/300-800/800+(ドーム)")
    print("案|ボット|優勝%|決勝%|解散%|夜逃げ%|10年目所持金(n10)|段% <0/0-300/300-800/800+")
    for c, name, r in res:
        print(f"{c}|{M.SHORT[M.BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|"
              + "/".join(f"{x:.0f}" for x in r["y10"]) + f"({r['n10']})|" + "/".join(f"{x:.0f}" for x in r["tiers"]))

if __name__ == "__main__":
    main()
