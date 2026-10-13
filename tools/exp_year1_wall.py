#!/usr/bin/env python3
"""1年目の壁の内訳（dynasty_v2_research_v0 §5「1年目の壁は能力ではなくネタ・知名度・決勝ライン側（要確認）」の確認）。
usage: python3 exp_year1_wall.py [n]。周回の頂点（m=1・J0=44）と m=0 で1年目だけを回し、GP各回戦の
「ライン − (実力+相性+体力ペナ)」＝不足分を、基本ライン・ネタ補正(＋波乱)・知名度補正(決勝)に分けて平均する。
ブレ幅 b（メンタル由来）と比べ、不足がブレで届く範囲か（|不足|<b）を数える。式・GameCore は触らない（実験内で一時差し替え）。【仮】"""
import sys, random, statistics
from collections import defaultdict
import balance_sim as B
import sim_career as C
import canon_v2 as V
from bots_v3 import PNeedV3
from exp_meta_curve_v3 import E0_SPLIT

LOG = []
def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    V.apply()
    base_curve, orig = C.CAP_CURVE, C._gp_perform
    cur = {}
    def wrap(s, line, rng, final):
        ok, sc = orig(s, line, rng, final)
        k = cur["k"]
        if final:
            lab = "敗者復活" if cur.get("sf_lost") and not cur.get("rev_done") else "決勝"
            if lab == "敗者復活": cur["rev_done"] = True
            base = C.GP_REVIVAL_LINE if lab == "敗者復活" else C.GP_FINAL_LINE
            fame_adj = 0.0 if lab == "敗者復活" else -C.FAME_FINAL_BONUS * (s.fame - 50) / 50
        else:
            lab, base, fame_adj = C.GP_ROUNDS[k][2], C.GP_ROUNDS[k][1], 0.0
            if not ok and k == len(C.GP_ROUNDS) - 1: cur["sf_lost"] = True
            cur["k"] = k + 1
        pen = 0
        for th, p in B.STAM_PEN:
            if s.stamina < th: pen = p; break
        det = B.jitsuryoku(s) + s.compat + pen
        LOG.append(dict(m=cur["m"], lab=lab, ok=ok, base=base, other=line - base - fame_adj, fame_adj=fame_adj,
                        jitsu=B.jitsuryoku(s), compat=s.compat, pen=pen, fame=s.fame, b=B.blur_width(s.mental), short=line - det))
        return ok, sc
    C._gp_perform = wrap
    try:
        for m in (0.0, 1.0):
            J0 = 44 * m ** 2.6
            C.CAP_CURVE = (base_curve[0] + 0.02 * 30 * m, base_curve[1], base_curve[2])
            pol = PNeedV3()
            for i in range(n):
                rng = random.Random(C.BASE_SEED + i); s = C.new_state(); s._yg = -J0
                for k, r in E0_SPLIT.items(): setattr(s, k, getattr(s, k) + 8 * J0 * r)
                cur.clear(); cur.update(k=0, m=m)
                C.run_year(pol, s, 1, rng)
        for m in (0.0, 1.0):
            print(f"== m={m} (n={n}) 1年目 ==")
            by = defaultdict(list)
            for r in LOG:
                if r["m"] == m: by[r["lab"]].append(r)
            for lab in [x[2] for x in C.GP_ROUNDS] + ["敗者復活", "決勝"]:
                rs = by.get(lab)
                if not rs: continue
                f = lambda key: statistics.mean(r[key] for r in rs)
                reach = sum(1 for r in rs if r["short"] <= r["b"])
                print(f"{lab:<6} 挑戦{len(rs):4d} 通過{100*sum(r['ok'] for r in rs)/len(rs):5.1f}% | 実力{f('jitsu'):5.1f} 相性{f('compat'):4.1f} 体力{f('pen'):4.1f} "
                      f"| ライン 基本{f('base'):4.0f} ネタ等{f('other'):+5.1f} 知名度{f('fame_adj'):+5.1f}(知名度{f('fame'):4.0f}) | 不足{f('short'):+6.1f} ブレ幅{f('b'):4.1f} ブレで届く{100*reach/len(rs):4.0f}%")
    finally:
        C.CAP_CURVE, C._gp_perform = base_curve, orig
        V.reset()

if __name__ == "__main__":
    main()
