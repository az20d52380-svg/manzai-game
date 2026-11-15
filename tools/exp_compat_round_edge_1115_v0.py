#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""相性が 14.5〜15 未満で終わるキャリアの割合（2026-11-15・notebook_intro_ending_audit_1115 低-1 の材料）。
手帳は四捨五入で「15」、エンディング判定は生の値で 15 未満＝分岐が食い違う範囲。コード・式は変更しない。
使い方: python3 exp_compat_round_edge_1115_v0.py [n=300]"""
import sys
from multiprocessing import Pool
import exp_endings_distribution_v0 as E

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    jobs = [(ne, b, n) for ne in (False, True) for b in E.BOTS]
    with Pool(10, maxtasksperchild=1) as p: res = p.map(E.one, jobs, chunksize=1)
    print(f"n={n} 解散・夜逃げ以外で終わったキャリアのうち｜相性>=15%｜14.5<=相性<15%（食い違う範囲）｜その中の優勝あり%")
    for ne, name, rs in res:
        R = [r for r in rs if not r["bk"] and not r["ds"]]
        if not R: continue
        k = len(R); edge = [r for r in R if 14.5 <= r["compat"] < 15]
        ch = 100 * sum(r["champ"] for r in edge) / len(edge) if edge else 0
        sh = E.SHORT[E.BOTS.index(name)]
        print(f"{'込み' if ne else 'なし'}|{sh}|完走{k}|{100*sum(r['compat']>=15 for r in R)/k:.1f}|{100*len(edge)/k:.2f}|{ch:.0f}", flush=True)

if __name__ == "__main__": main()
