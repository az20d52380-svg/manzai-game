#!/usr/bin/env python3
"""キュー128 案②（候補 claude/calendar-jan-candidate）でイベント3種の1キャリアあたり発生回数がどう変わるか。usage: python3 exp_calendar_jan_events_v0.py <tools のパス> [n]  EVENTS_APP=True・全部入り・ネタ込み（exp_money_after_merge_v0.one）。研究用・golden 不変（candidate_review_1026_v0）"""
import sys, os, collections
tools = sys.argv[1]; n = int(sys.argv[2]); sys.path.insert(0, tools); os.chdir(tools)
from multiprocessing import Pool
def one(bot):
    import sim_career as C, exp_money_after_merge_v0 as M
    C.EVENTS_APP = True
    cnt = collections.Counter()
    oa, ob = C._others_apply, C._app_apply
    def wa(s, k): cnt[k] += 1; return oa(s, k)
    def wb(s, k): cnt[k] += 1; return ob(s, k)
    C._others_apply, C._app_apply = wa, wb
    M.one(("all", True, bot, n))
    return bot, dict(cnt)
if __name__ == "__main__":
    import exp_money_after_merge_v0 as M
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, M.BOTS, chunksize=1)
    for bot, c in res:
        print(bot[:8], "|", " ".join(f"{k}={c.get(k,0)/n:.2f}" for k in ("homecoming","festival","yearend")), "| total/run=%.2f" % (sum(c.values())/n))
