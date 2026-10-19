#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""分岐 golden の種探し（gen_golden.py の BRANCH_SCRIPTS 用）。
gen_golden.run_year をそのまま使い、各種で最大4年を回して 敗者復活/シード/優勝 を探す。
使い方: cd tools && python3 find_golden_seeds_v0.py [最大種数]"""
import sys
import gen_golden as G
import balance_sim as B

def trial(seed, years=4):
    rng = G.SplitMix64(seed); s = B.S(); prev = 0; ev = []
    for y in range(1, years + 1):
        tr = {}
        try:
            champ, stage = G.run_year(s, y, rng, None, gp_seed=(prev >= 3), trace=tr)
        except AssertionError:
            return None
        ev.append(dict(year=y, seeded=prev >= 3, revival=tr.get("revival", False), champ=champ, stage=stage))
        prev = stage
        if champ: break
    return ev

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    found = {"revival": [], "seeded": [], "champ": []}
    for seed in range(1, n + 1):
        ev = trial(seed)
        if not ev: continue
        for e in ev:
            if e["revival"] and len(found["revival"]) < 5: found["revival"].append((seed, e["year"]))
            if e["seeded"] and len(found["seeded"]) < 5: found["seeded"].append((seed, e["year"]))
            if e["champ"] and len(found["champ"]) < 5: found["champ"].append((seed, e["year"]))
    print(found)
