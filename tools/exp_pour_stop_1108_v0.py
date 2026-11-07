#!/usr/bin/env python3
"""おすすめ注ぎが「gain 0 の最低値の能力」で止まり、まだ伸びる能力を残すかの実測（2026-11-08・code_review_1108d #3）。
測るだけ・既定値は変えず実行時に上書きする。測り方は exp_late_events_tuning_1108_v0.py と同じ
（EVENTS_APP=True・NETA_V2・4ボット・Pool(maxtasksperchild=1)+chunksize=1）。
案: now=今の式（止まった週を数える） / fix=gain 0 の能力を候補から外して続ける。
usage: python3 exp_pour_stop_1108_v0.py n"""
import sys, statistics, copy
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sim_career as C
import balance_sim as B
import exp_balance_snapshot_v0 as S2

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]
SHORT = ["のんびり", "ローテ", "必要充足", "やり込み"]
CNT = {"pour": 0, "stop": 0, "stop_mental": 0, "yearstop": {}}

def can_gain(s, a):
    amt = B._affordable_raw(s, a)
    return amt > B.POUR_EPS and B.projected_gain(s, a, amt) > B.POUR_EPS

def plan_now(s):
    """今の式と同じ計画。止まった時に、まだ伸びる能力が残っていれば数える"""
    scratch = copy.copy(s); plan = []; guard = 0
    while guard < 10_000:
        cand = [a for a in B.ALL_ABILITIES if B._affordable_raw(scratch, a) > B.POUR_EPS]
        if not cand: break
        t = min(cand, key=lambda a: getattr(scratch, a))
        if B.pour_step(scratch, t) <= 0:
            left = [a for a in B.ALL_ABILITIES if can_gain(scratch, a)]
            if left:
                CNT["stop"] += 1
                if "mental" in left: CNT["stop_mental"] += 1
            break
        plan.append(t); guard += 1
    CNT["pour"] += 1
    return plan

def plan_fix(s):
    scratch = copy.copy(s); plan = []; guard = 0
    while guard < 10_000:
        cand = [a for a in B.ALL_ABILITIES if can_gain(scratch, a)]
        if not cand: break
        t = min(cand, key=lambda a: getattr(scratch, a))
        if B.pour_step(scratch, t) <= 0: break
        plan.append(t); guard += 1
    CNT["pour"] += 1
    return plan

def job(a):
    case, bi, seeds = a
    S2.install(True)
    pol = S2.make2(BOTS[bi])
    C.NETA_ON = C.NETA_V2 = True
    C.EVENTS_APP = True
    B.recommended_plan = plan_now if case == "now" else plan_fix
    fin = []
    o = C.run_year
    def run_year(pol_, s, year, rng, **kw):
        r = o(pol_, s, year, rng, **kw)
        if r[2]: fin.append(year)
        return r
    C.run_year = run_year
    out = []
    for i in seeds:
        fin.clear(); CNT["pour"] = CNT["stop"] = CNT["stop_mental"] = 0
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        out.append(dict(win=first, fin=bool(fin), ds=bool(d.get("_dissolved")), mental=s.mental,
                        pour=CNT["pour"], stop=CNT["stop"], sm=CNT["stop_mental"]))
    return (case, bi), out

def main():
    n = int(sys.argv[1]); chunk = 25
    jobs = [(c, bi, list(range(i, min(i + chunk, n)))) for c in ("now", "fix") for bi in range(4) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as pool:
        for k, out in pool.imap_unordered(job, jobs, chunksize=1):
            res.setdefault(k, []).extend(out)
    print(f"n={n}|案|ボット|優勝%|決勝%|解散%|最後のメンタル平均|注ぎ回数/周|途中で止まった回数/周|うちメンタルが残った/周")
    for c in ("now", "fix"):
        for bi in range(4):
            r = res[(c, bi)]; m = len(r)
            print(f"|{c}|{SHORT[bi]}|{100*sum(1 for x in r if x['win'])/m:.1f}|{100*sum(1 for x in r if x['fin'])/m:.1f}|{100*sum(1 for x in r if x['ds'])/m:.1f}|{statistics.mean(x['mental'] for x in r):.1f}|{statistics.mean(x['pour'] for x in r):.0f}|{statistics.mean(x['stop'] for x in r):.1f}|{statistics.mean(x['sm'] for x in r):.1f}|")

if __name__ == "__main__":
    main()
