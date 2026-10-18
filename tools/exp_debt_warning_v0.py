#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""借金警告に反応するボットの効果（2026-10-16・コード/式は変更しない）。
使い方: python3 exp_debt_warning_v0.py [n=1000]
基準=人間らしい(稽古3週:バイト1週+喫茶店)。反応型を足す（所持金の線を越えたら発動・0以上に戻ったら基準に復帰）:
 ①@0  初マイナスで バイト週2（ネタ作り/ネタ合わせ/バイト/バイト の巡回）
 ②@-50万 の知らせで お店(喫茶店)をやめ バイト多め（稽古1:バイト2）
 ③@L  Lの知らせで バイト専念（借金中は標準バイト・体力20未満は休む・オファー受諾）。L=-80万(案)＋線の調整案 0/-30/-50/-60
夜逃げ=所持金が -100万 を生活費の週に下回る（canon_v2 の BANKRUPT_LINE）。"""
import sys, statistics
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
from exp_stuck_v0 import J, T
from exp_balance_snapshot_v0 import install, make2

HUMAN = "人間らしい(稽古3週:バイト1週+喫茶店)"
MAN = 10000
# (名前, 型, 線[万])
VARS = [("反応しない", None, None),
        ("①バイト週2 @0", "j2", 0), ("②店やめ+バイト多め @-50万", "j3", -50), ("③バイト専念 @-80万", "full", -80),
        ("③バイト専念 @0", "full", 0), ("③バイト専念 @-30万", "full", -30), ("③バイト専念 @-50万", "full", -50), ("③バイト専念 @-60万", "full", -60),
        ("③バイト専念 @-90万", "full", -90)]

class Warn:
    def __init__(self, base, kind, line):
        self.base, self.kind, self.line = base, kind, (line * MAN if line is not None else None)
        self.name = base.name; self.latched = False; self.i = 0
    def __getattr__(self, k): return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        self.wk = getattr(self, "wk", 0) + 1
        cr = s.__dict__.setdefault("_cross", {})
        for L in (0, -30, -50, -60, -80, -90):
            if s.money < L * MAN and L not in cr: cr[L] = self.wk
        if self.kind is None or s.money >= 0: return self.base.choose(s, week, offer, rng)
        if s.money <= self.line: self.latched = True
        if not self.latched: return self.base.choose(s, week, offer, rng)
        self.fired = True; s.__dict__["_fired"] = True
        if offer: return ("offer", None)
        if s.stamina < 20: return ("rest", "完全休養")
        if self.kind == "full": return ("job", "標準")
        cyc = ([T("ネタ作り"), T("ネタ合わせ"), J("標準"), J("標準")] if self.kind == "j2" else [T("ネタ合わせ"), J("標準"), J("標準")])
        a = cyc[self.i % len(cyc)]; self.i += 1
        return a

def one(args):
    neta, vi, n = args
    install(neta)
    nm, kind, line = VARS[vi]
    recs = []
    for i in range(n):
        pol = Warn(make2(HUMAN), kind, line)   # 毎キャリア新規（latch/巡回を持ち越さない）
        ml = [[] for _ in range(C.YEARS)]
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, money_log=ml)
        d = s.__dict__
        recs.append(dict(bk=bool(d.get("_bankrupt")), yr=d.get("_yr"), ds=bool(d.get("_dissolved")), win=first, fin=ever,
                         fired=bool(d.get("_fired")), m10=(ml[9][0] if ml[9] else None), cr=d.get("_cross", {})))
    return neta, vi, recs

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    with Pool(10, maxtasksperchild=1) as p: res = p.map(one, [(ne, vi, n) for ne in (False, True) for vi in range(len(VARS))], chunksize=1)
    P = lambda x, k: f"{100*x/k:.1f}" if k else "-"
    print(f"n={n} 夜逃げ年=夜逃げした人の年の中央値 | 立て直し=反応が発動して夜逃げしなかった人(発動数に対する%) | 決勝/優勝=全体に対する%(＋生存者のみ) | 10年目所持金=完走者の中央値(万)")
    print("NETA|型|発動%|夜逃げ%|夜逃げ年(中央)|立て直し%|決勝到達%|優勝%|生存者の決勝%|生存者の優勝%|10年目所持金|解散%")
    for ne, vi, R_ in res:
        k = len(R_); f = [r for r in R_ if r["fired"]]; sv = [r for r in R_ if not r["bk"]]
        yrs = [r["yr"] for r in R_ if r["bk"] and r["yr"]]; m10 = [r["m10"] / MAN for r in R_ if r["m10"] is not None]
        rec = [r for r in f if not r["bk"]]
        print(f"{'込み' if ne else 'なし'}|{VARS[vi][0]}|{P(len(f),k)}|{P(sum(r['bk'] for r in R_),k)}|{statistics.median(yrs) if yrs else '-'}|{P(len(rec),len(f))}|"
              f"{P(sum(r['fin'] for r in R_),k)}|{P(sum(r['win'] is not None for r in R_),k)}|{P(sum(r['fin'] for r in sv),len(sv))}|{P(sum(r['win'] is not None for r in sv),len(sv))}|"
              f"{format(statistics.median(m10),'.0f') if m10 else '-'}|{P(sum(r['ds'] for r in R_),k)}", flush=True)
    cross_table(res)

def cross_table(res):
    out = ["", "反応しない型の「線を越えた週」中央値(通算の行動週・0週目=開始)と、越えた人の割合(NETAなし)"]
    for ne, vi, R_ in res:
        if vi or ne: continue
        for L in (0, -30, -50, -60, -80, -90):
            w = [r["cr"][L] for r in R_ if L in r["cr"]]
            out.append(f"  {L}万: {100*len(w)/len(R_):.0f}%の人が越える・中央 {statistics.median(w) if w else '-'}週")
    print("\n".join(out))

if __name__ == "__main__": main()
