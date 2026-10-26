#!/usr/bin/env python3
"""キュー130：判断のまとめ #1 の推奨C「のんびり型だけ手当てして R2M@0.8 を入れる」の手当ての候補を測る。
usage: python3 exp_q93_c_v0.py [n=300] [variants=...]   測り方は exp_q93_r2m_current_v0（組A・hand・全部入り・ネタ込み）と同じ。
案 "R2M@0.8+F"：無料の稽古（ネタ作り・ネタ合わせ・フリーライブ）だけ量を今に戻す／"R2M@0.8+R<x>"：休む・バイトの週に一番少ない経験点を生の x（省略時1）。
案 "R2M@0.8+C<T>"：手持ちの経験点（5種の合計・内部値）が T 未満の時だけ供給を R2M@1.0 の量（今の 0.48）に戻す
（余って詰まっている人＝供給を減らしても伸びが変わらない人だけ 0.8 倍になる「追いつきの配り」）。研究用・既定値と golden は不変。"""
import sys
from multiprocessing import Pool
import exp_q93_r2m_current_v0 as R

def one(args):
    var, app, bi, n = args
    import balance_sim as B, exp_q93_retune_v0 as Q
    if var.endswith("+F") or "+R" in var:
        if var.endswith("+F"): base, mode, ramt = var[:-2], "F", 0.0
        else:
            base, _, ra = var.partition("+R"); mode = "R"; ramt = float(ra) if ra else 1.0
        orig = Q.apply
        def apply2(v):
            orig(base)
            low = B.EXP_SUPPLY_SCALE; full = low / 0.8
            if mode == "F":   # 無料の稽古だけ量を戻す
                ot = B.do_training
                def tr(s, name):
                    if name not in B.FREE_ROT: return ot(s, name)
                    B.EXP_SUPPLY_SCALE = full
                    try: return ot(s, name)
                    finally: B.EXP_SUPPLY_SCALE = low
                B.do_training = tr
            else:             # 休む・バイトの週に、手持ちが一番少ない経験点を生の1（稽古の主効果の約1/3）
                def wrap(fn):
                    def f(s, *a, **kw):
                        r = fn(s, *a, **kw)
                        if r is not False:
                            cur = min(B.CURRENCIES, key=lambda c: getattr(s, B.CURRENCY_ATTR[c], 0.0))
                            B.credit_currency(s, cur, ramt)
                        return r
                    return f
                B.do_rest = wrap(B.do_rest); B.do_job = wrap(B.do_job)
        Q.apply = apply2
        return R.one((var, app, bi, n))
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
