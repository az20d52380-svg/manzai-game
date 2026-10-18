#!/usr/bin/env python3
"""キュー93 R2M の「いまの本体」での測り直し（docs/q93_r2m_current_v0.md）。usage: python3 exp_q93_r2m_current_v0.py [n=300] [variants=A,R2M@0.8,R2M@0.9,R2M@1.0]
全部入り(部屋+アイテム+特技)・ネタ込み・EVENTS_APP False/True。ボットは §93 の組A（のんびり+喫茶店／ローテ+喫茶店／バランス／調整型）を hand（人の手配り近似）で。
exp_money_after_merge_v0.one（全部入り）に exp_ability_stall_v0 の記録（詰まり・未使用・能力）を重ねる。式・既定値は変えない（案は子プロセス内の上書きだけ）。数値は全て【仮】。"""
import sys, statistics
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
import exp_balance_snapshot_v0 as S
import exp_money_after_merge_v0 as M
import exp_ability_stall_v0 as ST
import exp_q93_retune_v0 as Q
from exp_human import PCasual2
from bots_v3 import PRotate
from exp_places_v1 import Cafe
from exp_rests_v1 import Spa

NAMES = ["のんびり改+喫茶", "ローテ+喫茶", "バランス/必要充足", "調整型(Smart)"]
def mk(i): return [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()][i]

def one(args):
    var, app, bi, n = args
    S.install(True)                       # V.apply・イベント・ネタ込み・場所・有料休み
    C.EVENTS_APP = bool(app)
    Q.apply(var)                          # 案の上書き（"A"＝今は何もしない）
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    S.install = lambda neta: None         # M.one 内の再 install を無効化（上書きを消さない）
    bot = mk(bi); S.make2 = lambda name: bot
    ST.install("hand", "A")               # hand 注ぎ＋詰まり/未使用/能力の記録
    rc = C.run_career
    acc = dict(s1=0, w1=0, s13=0, w13=0, ab10=[[] for _ in range(5)], j10=[], un=[], n10=0)
    def run_career(*a, **kw):
        ST.REC.reset()
        r = rc(*a, **kw)
        y1 = [w[1] for w in ST.REC.weeks if w[0] == 1]; y13 = [w[1] for w in ST.REC.weeks if w[0] <= 3]
        acc["s1"] += sum(y1); acc["w1"] += len(y1); acc["s13"] += sum(y13); acc["w13"] += len(y13)
        if 3 in ST.REC.snap:
            iss = ST.REC.snap[3][3].get("maai", 0.0)
            if iss > 0: acc["un"].append(ST.REC.snap[3][2][ST.CUR.index("maai")] / iss)
        if 10 in ST.REC.snap:
            acc["n10"] += 1
            for k in range(5): acc["ab10"][k].append(ST.REC.snap[10][0][k])
            acc["j10"].append(ST.REC.snap[10][1])
        return r
    C.run_career = run_career
    r = M.one(("all", True, "x", n))[3]
    m = lambda v: statistics.mean(v) if v else 0.0
    return var, app, bi, dict(win=r["win"], fin=r["fin"], ds=r["ds"], bk=r["bk"],
        st1=100.0 * acc["s1"] / max(1, acc["w1"]), st13=100.0 * acc["s13"] / max(1, acc["w13"]),
        un=100.0 * m(acc["un"]), n10=acc["n10"], ab10=[m(a) for a in acc["ab10"]], j10=m(acc["j10"]))

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    vs = sys.argv[2].split(",") if len(sys.argv) > 2 else ["A", "R2M@0.8", "R2M@0.9", "R2M@1.0"]
    jobs = [(v, a, b, n) for v in vs for a in (False, True) for b in range(4)]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, jobs, chunksize=1)
    print(f"# n={n}/ボット・全部入り・ネタ込み・hand。詰1/詰13=週末に経験点>=5で押せる＋0の週%（1年目/1〜3年）｜間残=3年末に残った間合い÷もらった間合い%｜能力10=10年目年末の 感性/発想/表現/華/メンタル（n10人の平均）｜実力10")
    for var, app, bi, r in res:
        print(f"{var}|APP={int(app)}|{NAMES[bi]}|優={r['win']:.1f}|決={r['fin']:.1f}|散={r['ds']:.1f}|夜={r['bk']:.1f}|"
              f"詰1={r['st1']:.0f}|詰13={r['st13']:.0f}|間残={r['un']:.0f}|n10={r['n10']}|能力10={'/'.join(f'{x:.0f}' for x in r['ab10'])}|実力10={r['j10']:.1f}")

if __name__ == "__main__":
    main()
