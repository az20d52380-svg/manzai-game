#!/usr/bin/env python3
"""選び方の差と年の予算（docs/event_scale_options_v0.md §選び方の差と年の予算）。usage: python3 exp_event_budget_choice_v0.py [n=1000]
{今=素の加減算, 年の予算に数える} x {毎回A, 毎回B, 体力で選ぶ(既定)} x {必要充足, やり込み}。ネタ込み・全部入り・EVENTS_APP=True。
年の予算=exp_event_scale_v1.py の yearcap（4能力の増分のみ B.add を鈍り無しで通す）。選び方=exp_exploit_search_v2.py の hook_evm。上書きはプロセス内のみ。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M
import exp_event_scale_v1 as E
import exp_exploit_search_v2 as X2

BOTSEL = ["PNeedV3", "金→力 全振り(やり込み改)"]
CH = {"A": "毎回A", "B": "毎回B", "default": "体力で選ぶ(既定)"}

def one(args):
    budget, ch, name, n = args
    E.patch("yearcap" if budget else "raw")
    if ch != "default": X2.hook_evm(ch)
    r = M.one(("all", True, name, n))
    return budget, ch, name, r[3]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    jobs = [(bg, ch, b, n) for b in BOTSEL for bg in (False, True) for ch in CH]
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, jobs, chunksize=1)
    print(f"# n={n}/行。ネタ込み・全部入り・EVENTS_APP=True")
    print("ボット|年の予算|選び方|優勝%|決勝%|解散%")
    for bg, ch, name, r in sorted(res, key=lambda x: (BOTSEL.index(x[2]), x[0], list(CH).index(x[1]))):
        print(f"{M.SHORT[M.BOTS.index(name)]}|{'数える' if bg else '今'}|{CH[ch]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}")

if __name__ == "__main__":
    main()
