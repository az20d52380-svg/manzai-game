#!/usr/bin/env python3
"""決勝2本目の減点 NETA_SECOND_PEN を 0/1.5/3 で比較（ネタ込み・EVENTS_APP=True・全部入り＝band_reference と同じ M.one）。
usage: python3 exp_second_pen_1116_v0.py [n=300] [pens=0,1.5,3]
減点が掛かった割合＝_neta_line_adj(final=True) の中で「2本目が無い/完成度未満」の条件が成立した回数 / 決勝の判定回数（ネタ0本で選ばない場合は掛からない）。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M

def one(args):
    pen, name, n = args
    C.EVENTS_APP = True
    C.NETA_SECOND_PEN = pen
    cnt = {"fin": 0, "pen": 0}
    def adj(s, series, rng, final=False):
        if not C.NETA_ON:
            return 0.0
        nn = C._neta_pick(s, series, rng)
        if nn is None:
            if final: cnt["fin"] += 1
            return 0.0 if C.NETA_V2 else (C.NETA_SECOND_PEN if final else 0.0)
        a = -C._neta_bonus(nn, series)
        C._neta_use(nn, series)
        if final:
            cnt["fin"] += 1
            others = [x for x in s.netas if x is not nn]
            second = max(others, key=lambda x: x["comp"]) if others else None
            if second is None or second["comp"] < (C.V2_SECOND_MIN if C.NETA_V2 else 60):
                a += C.NETA_SECOND_PEN
                cnt["pen"] += 1
        return a
    o_install = M.S.install
    def inst(ne):
        o_install(ne); C._neta_line_adj = adj
    M.S.install = inst
    r = M.one(("all", True, name, n))[3]
    return pen, name, r["win"], r["fin"], cnt["pen"], cnt["fin"]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    pens = [float(x) for x in (sys.argv[2] if len(sys.argv) > 2 else "0,1.5,3").split(",")]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(p, b, n) for p in pens for b in M.BOTS], chunksize=1)
    print(f"# n={n}/セル 全部入り・ネタ込み・EVENTS_APP=True")
    print("減点|ボット|優勝%|決勝%|減点掛かり%(掛かった決勝/全決勝)")
    for pen, name, w, f, p, t in res:
        print(f"{pen}|{M.SHORT[M.BOTS.index(name)]}|{w:.1f}|{f:.1f}|{100.0*p/max(1,t):.1f}% ({p}/{t})")

if __name__ == "__main__":
    main()
