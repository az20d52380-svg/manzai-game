#!/usr/bin/env python3
"""出会いにくいイベント4種（3行目の当たり・年末ライブ・帰省・夏祭り）の条件をゆるめたら、1キャリアで見る割合がどう変わるか。
usage: python3 exp_event_reach_relax_v0.py [n]   EVENTS_APP=True・全部入り・ネタ込み（exp_money_after_merge_v0.one）。
研究用・golden 不変（sim_career の _app_band を実行中だけ差し替える）。結果は docs/event_reach_relax_1026_v0.md。"""
import sys, collections
from multiprocessing import Pool

RARE = ("luckythird", "yearend", "homecoming", "festival")
CASES = ["base", "L60", "Lnoloss", "Lboth", "W", "Lboth+W", "H2", "cap25", "sure"]

def one(args):
    case, bot, n = args
    import sim_career as C, exp_money_after_merge_v0 as M
    C.EVENTS_APP = True
    cnt = collections.Counter()
    ob = C._app_band
    def band(k, s, week, year, ahead, nxt, a):
        last[id(a)] = year
        L = case.startswith("L"); W = case.endswith("W")
        if k == "luckythird" and L:
            hp = 60 if case in ("L60", "Lboth", "Lboth+W") else 80
            noloss = case in ("Lnoloss", "Lboth", "Lboth+W")
            return (s.stamina >= hp and (noloss or a["loss"] == 0)
                    and nxt is not None and 2 <= nxt[0] - week <= 4)
        if W and k == "festival":   return 13 <= week <= 21 and s.stamina >= 40 and ahead >= 2
        if W and k == "yearend":    return 32 <= week <= 37 and s.money >= 1500
        if W and k == "homecoming": return week >= 36 and ahead > 3
        if case == "H2" and k == "homecoming": return week >= 38 and ahead >= 2
        return ob(k, s, week, year, ahead, nxt, a)
    C._app_band = band
    if case == "cap25": C.APP_EVENT_CAP = 25
    if case == "sure": C.SURE_SEASONAL = True   # 候補 claude/season-sure-candidate の時だけ効く
    last = {}   # キャリアごとに、抽選がまだ行われた最後の年（上限に達するとそれ以後は呼ばれない）
    oa, oapp = C._others_apply, C._app_apply
    def wa(s, k): cnt[k] += 1; return oa(s, k)
    def wb(s, k): cnt[k] += 1; return oapp(s, k)
    C._others_apply, C._app_apply = wa, wb
    M.one(("all", True, bot, n))
    ys = list(last.values())
    cnt["_lastyear"] = sum(ys) / max(1, len(ys))
    return case, bot, dict(cnt)

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    import exp_money_after_merge_v0 as M
    jobs = [(c, b, n) for c in CASES for b in M.BOTS]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, jobs, chunksize=1)
    print("| 案 | ボット | 3行目の当たり | 年末ライブ | 帰省 | 夏祭り | イベント計/キャリア | 抽選が続いた最後の年(平均) |")
    print("|---|---|---|---|---|---|---|---|")
    for case, bot, c in res:
        print(f"| {case} | {bot[:8]} | " + " | ".join(f"{c.get(k,0)/n:.0%}" for k in RARE)
              + f" | {sum(v for k, v in c.items() if k[0] != '_')/n:.1f} | {c['_lastyear']:.1f} |")
