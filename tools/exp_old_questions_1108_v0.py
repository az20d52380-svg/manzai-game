#!/usr/bin/env python3
"""古い3論点の測り直し（docs/old_questions_remeasure_1108_v0.md）。usage: python3 exp_old_questions_1108_v0.py [n=300] [out.json]
いまの既定値（YEARS=15・較正A・周回の式は sim_career 正典のまま）。ボット4種＝帯の組（のんびり改/ローテ/必要充足/やり込み）・ネタ込み(NETA_ON=NETA_V2=True)・
全部入り（部屋+アイテム+特技＝exp_money_after_merge_v0.one "all"）。EVENTS_APP False/True。pour は auto（今の既定）と hand（人の手配り近似・旧の詰まり測定と同じ）の2通り。
記録：論点1 詰まる週（1年目/1〜3年・exp_ability_stall_v0 の stalled）、論点2 15年目の所持金・会場の段（<0/0-300/300-800/800+）、論点3 決勝到達・15年内初優勝。
式・既定値は変えない。上書きは各プロセス内（Pool(maxtasksperchild=1)・chunksize=1）。"""
import sys, json, statistics
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S
import exp_money_after_merge_v0 as M
import exp_ability_stall_v0 as ST

def tier(m): return 0 if m < 0 else 1 if m < 300 else 2 if m < 800 else 3
def pct(v, q):
    v = sorted(v); return v[min(len(v) - 1, int(q * len(v)))] if v else None

def one(args):
    app, bi, mode, n = args
    S.install(True)
    C.EVENTS_APP = bool(app)
    S.install = lambda neta: None          # M.one 内の再 install を無効化
    ST.install(mode, "A")                  # mode: "hand" or "auto"（詰まり・能力の記録）
    rc = C.run_career
    acc = dict(s1=0, w1=0, s13=0, w13=0, y15=[], end=[], firsts=[], fins=[], ds=0, bk=0, reach=0, ens=0)
    def run_career(*a, **kw):
        ST.REC.reset()
        r = rc(*a, **kw)
        first, s, stage, ever = r
        y1 = [w[1] for w in ST.REC.weeks if w[0] == 1]; y13 = [w[1] for w in ST.REC.weeks if w[0] <= 3]
        acc["s1"] += sum(y1); acc["w1"] += len(y1); acc["s13"] += sum(y13); acc["w13"] += len(y13)
        ml = kw.get("money_log")
        if ml and len(ml) >= 15 and ml[14]: acc["y15"].append(ml[14][0] / 10000)
        acc["end"].append(s.money / 10000)
        acc["firsts"].append(first); acc["fins"].append(bool(ever))
        acc["ds"] += bool(s.__dict__.get("_dissolved")); acc["bk"] += bool(s.__dict__.get("_bankrupt"))
        return r
    C.run_career = run_career
    M.one(("all", True, M.BOTS[bi], n))
    N = len(acc["firsts"]); y15 = acc["y15"]
    t15 = [0] * 4
    for m in y15: t15[tier(m)] += 1
    te = [0] * 4
    for m in acc["end"]: te[tier(m)] += 1
    wins = [f for f in acc["firsts"] if f]
    return dict(app=app, bot=bi, mode=mode, n=N,
        st1=100.0 * acc["s1"] / max(1, acc["w1"]), st13=100.0 * acc["s13"] / max(1, acc["w13"]),
        n15=len(y15), y15=[pct(y15, .25), pct(y15, .5), pct(y15, .75)], t15=[100.0 * t / max(1, len(y15)) for t in t15],
        tend=[100.0 * t / N for t in te], endmed=pct(acc["end"], .5),
        fin=100.0 * sum(acc["fins"]) / N, win=100.0 * len(wins) / N,
        w10=100.0 * sum(1 for f in wins if f <= 10) / N, ds=100.0 * acc["ds"] / N, bk=100.0 * acc["bk"] / N,
        winyears=wins)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    outp = sys.argv[2] if len(sys.argv) > 2 else None
    jobs = [(a, b, m, n) for m in ("auto", "hand") for a in (False, True) for b in range(4)]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, jobs, chunksize=1)
    NM = ["のんびり改", "ローテ", "必要充足", "やり込み"]
    print(f"# n={n}/ボット・15年・較正A・全部入り・ネタ込み。詰=経験点>=5で押せる＋0の週%(1年目/1〜3年)｜15年目所持金 万 Q1/中央/Q3(人数)｜段%=15年目の所持金で <0/0-300/300-800/800+｜終了時段=打切り時点")
    for r in res:
        print(f"{r['mode']}|APP={int(r['app'])}|{NM[r['bot']]}|詰1={r['st1']:.0f}|詰13={r['st13']:.0f}|優15={r['win']:.1f}|優10={r['w10']:.1f}|決={r['fin']:.1f}|散={r['ds']:.1f}|夜={r['bk']:.1f}|"
              f"y15={'/'.join(str(round(x)) if x is not None else '-' for x in r['y15'])}({r['n15']})|段15={'/'.join(f'{x:.0f}' for x in r['t15'])}|終了時中央={r['endmed']:.0f}|終了時段={'/'.join(f'{x:.0f}' for x in r['tend'])}")
    if outp: json.dump(res, open(outp, "w"), ensure_ascii=False)

if __name__ == "__main__":
    main()
