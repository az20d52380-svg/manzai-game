#!/usr/bin/env python3
"""帯のずれの切り分け用（測るだけ）。usage: python3 exp_band_bisect_1116_v0.py [n=300]
3セルだけ：ローテ(込・EVENTS_APP=False)決勝%／のんびり改(込・True)決勝%／必要充足(無・False)解散%。
measure_band_reference_v1.one を使う。出力は1行 'BISECT ローテ決勝 のんびり決勝 必要充足解散'。"""
import sys
from multiprocessing import Pool
import measure_band_reference_v1 as MB
import exp_money_after_merge_v0 as M

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    nm = {s: b for s, b in zip(M.SHORT, M.BOTS)}
    jobs = [(False, True, nm["ローテ"], n), (True, True, nm["のんびり改"], n), (False, False, nm["必要充足"], n)]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(MB.one, jobs, chunksize=1)
    print(f"BISECT {res[0][3]['fin']:.1f} {res[1][3]['fin']:.1f} {res[2][3]['ds']:.1f}")

if __name__ == "__main__":
    main()
