#!/usr/bin/env python3
"""キュー130：判断のまとめ #1 の推奨C「のんびり型だけ手当てして R2M@0.8 を入れる」の手当ての候補を測る。
usage: python3 exp_q93_c_v0.py [n=300] [variants=...]   測り方は exp_q93_r2m_current_v0（組A・hand・全部入り・ネタ込み）と同じ。
案 "R2M@0.8+C<T>"：手持ちの経験点（5種の合計・内部値）が T 未満の時だけ供給を R2M@1.0 の量（今の 0.48）に戻す
（余って詰まっている人＝供給を減らしても伸びが変わらない人だけ 0.8 倍になる「追いつきの配り」）。研究用・既定値と golden は不変。"""
import sys
from multiprocessing import Pool
import exp_q93_r2m_current_v0 as R

def one(args):
    var, app, bi, n = args
    import balance_sim as B, exp_q93_retune_v0 as Q
    base, _, c = var.partition("+C")
    if c:
        T = float(c); orig = Q.apply
        def apply(v):
            orig(base)
            low = B.EXP_SUPPLY_SCALE; full = low / 0.8
            attrs = list(B.CURRENCY_ATTR.values())
            def credit(s, currency, v):
                if v <= 0: return
                held = sum(getattr(s, a, 0.0) for a in attrs)
                attr = B.CURRENCY_ATTR[currency]
                setattr(s, attr, getattr(s, attr) + v * (full if held < T else low))
            B.credit_currency = credit
        Q.apply = apply
    return R.one((var, app, bi, n))

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    vs = sys.argv[2].split(",") if len(sys.argv) > 2 else ["A", "R2M@0.8", "R2M@0.8+C3", "R2M@0.8+C5", "R2M@0.8+C10"]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, [(v, a, b, n) for v in vs for a in (False, True) for b in range(4)], chunksize=1)
    for var, app, bi, r in res:
        print(f"{var}|APP={int(app)}|{R.NAMES[bi]}|優={r['win']:.1f}|決={r['fin']:.1f}|散={r['ds']:.1f}|詰1={r['st1']:.0f}|詰13={r['st13']:.0f}|実力10={r['j10']:.1f}")
