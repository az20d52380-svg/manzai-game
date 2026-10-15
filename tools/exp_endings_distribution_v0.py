#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""エンディング判定案 A〜F の分布（2026-10-16）。コード・式は変更しない。exp_balance_snapshot_v0 の install/make2 を流用。
使い方: python3 exp_endings_distribution_v0.py [n=1000]"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_balance_snapshot_v0 as S

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み", "放置"]

def one(args):
    neta, name, n = args
    S.install(neta)
    mx = {"v": 0.0}
    orw = C.rift_weekend
    def rw(s, year, c0):
        r = orw(s, year, c0); mx["v"] = max(mx["v"], getattr(s, "rift", 0.0)); return r
    C.rift_weekend = rw
    pol = S.make2(name); recs = []
    for i in range(n):
        mx["v"] = 0.0
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        recs.append(dict(bk=bool(d.get("_bankrupt")), ds=bool(d.get("_dissolved")), champ=first is not None,
                         fin=d.get("_finals", 0), compat=s.compat, mr=mx["v"], warned=bool(d.get("rift_warned"))))
    return neta, name, recs

def end(r, rule):
    if r["bk"]: return 1
    if r["ds"]: return 2
    fin, c, mr, w = r["fin"], r["compat"], r["mr"], r["warned"]
    if rule == "A": hi = c >= 15
    elif rule == "B": hi = c >= 18
    elif rule == "C": hi = c >= 20
    elif rule == "D30": hi = mr < 30
    elif rule == "D50": hi = mr < 50
    elif rule in ("G", "G2"): hi = mr < 30
    elif rule == "D15": hi = mr < 15
    else: hi = c >= 15
    if r["champ"]:
        if rule == "F": return 8 if w else 7      # 予告が出た(=向き合う場面があった)なら#8、一度も出なければ#7
        if rule == "F2": return 7 if w else 8     # 逆向き
        return 8 if hi else 7
    if rule == "G":    # 決勝0回: rift最大<30で#4/#3。決勝1回=#5・2回以上=#6。優勝: rift<30で#8/他#7
        if fin >= 2: return 6
        if fin == 1: return 5
        return 4 if hi else 3
    if rule == "G2":   # Gの#5/#6を「決勝2回以上かつrift<30」で#6にする
        if fin >= 1: return 6 if (fin >= 2 and hi) else 5
        return 4 if hi else 3
    if rule == "E1":   # 決勝回数で #5/#6、決勝0回だけ相性15で #3/#4
        if fin >= 2: return 6
        if fin == 1: return 5
        return 4 if c >= 15 else 3
    if rule == "E2":   # 決勝>=2 かつ相性18 で #6、決勝1回以上は#5、0回は相性18で#3/#4
        if fin >= 1: return 6 if (fin >= 2 and c >= 18) else 5
        return 4 if c >= 18 else 3
    return {(True, True): 6, (True, False): 5, (False, True): 4, (False, False): 3}[(fin >= 1, hi)]

RULES = ["A", "B", "C", "D15", "D30", "D50", "E1", "E2", "G", "G2", "F", "F2"]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(ne, b, n) for ne in (False, True) for b in BOTS]
    with Pool(10) as p: res = p.map(one, jobs)
    print(f"n={n} 各案の #1〜#8 割合(%) と 5〜40%に入ったエンド数(出現するエンドのうち)")
    print("案|NETA|ボット|#1|#2|#3|#4|#5|#6|#7|#8|散り(#3〜#8で5-40%の数)")
    for rule in RULES:
        for ne in (False, True):
            for name, sh in zip(BOTS, SHORT):
                R = [r for (n_, nm, rs) in res if n_ == ne and nm == name for r in rs]
                es = [end(r, rule) for r in R]
                pc = [100 * es.count(j) / len(R) for j in range(1, 9)]
                ok = sum(5 <= x <= 40 for x in pc[2:])
                print(f"{rule}|{'込み' if ne else 'なし'}|{sh}|" + "|".join(f"{x:.1f}" for x in pc) + f"|{ok}", flush=True)
    print("\n補助(10年完走者・優勝者の特徴) NETA|ボット|相性>=15%|>=18%|=20%|maxrift中央|maxrift>=30%|>=50%(予告)|優勝者の予告あり%|決勝0/1/2+%")
    import statistics
    for ne in (False, True):
        for name, sh in zip(BOTS, SHORT):
            R = [r for (n_, nm, rs) in res if n_ == ne and nm == name for r in rs]
            k = len(R); f = lambda c: 100 * sum(c(r) for r in R) / k
            ch = [r for r in R if r["champ"]]
            wp = 100 * sum(r["warned"] for r in ch) / len(ch) if ch else float("nan")
            print(f"{'込み' if ne else 'なし'}|{sh}|{f(lambda r:r['compat']>=15):.0f}|{f(lambda r:r['compat']>=18):.0f}|{f(lambda r:r['compat']>=20):.0f}|"
                  f"{statistics.median(r['mr'] for r in R):.0f}|{f(lambda r:r['mr']>=30):.0f}|{f(lambda r:r['warned']):.0f}|{wp:.0f}|"
                  f"{f(lambda r:r['fin']==0):.0f}/{f(lambda r:r['fin']==1):.0f}/{f(lambda r:r['fin']>=2):.0f}")

if __name__ == "__main__": main()
