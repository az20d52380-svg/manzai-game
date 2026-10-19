#!/usr/bin/env python3
"""キュー78 空白週の測り直し v1。既存の正典・既定値は変えない（案ごとの上書きはワーカー内だけ）。
usage: python3 measure_blank_weeks_v1.py [n=300]
案: A=今のまま / B=イベント抽選確率×1.5 / C=空白が8週続いたら抽選を強制(EVENT_RATE=1、非APP側は未発火候補だけから引く)
空白＝大会・イベント・オファー・療養のどれも無い週（exp_fun_audit_v0 と同じ定義。イベントは _apply_event / _others_apply / _app_apply を数える）
EVENTS_APP False/True を併記。ボット: のんびり改/ローテ/やり込み(PNeedV3)。"""
import sys, statistics
from multiprocessing import Pool
sys.path.insert(0, __import__("os").path.dirname(__file__))

CASES = ["A今のまま", "Bイベント率x1.5", "C空白8週で強制"]
BOTS = ["のんびり改", "ローテ", "やり込み"]

def work(task):
    case, app, bi, n = task
    import balance_sim as B, sim_career as C, canon_v2 as V, bots_v3
    import exp_fun_audit_v0 as F
    from exp_human import PCasual2
    from bots_v3 import PNeedV3, PRotate
    from exp_places_v1 import Cafe
    from exp_rests_v1 import Spa
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True; C.EVENTS_APP = bool(app)
    for k, v in F.PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = F.OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    base = C.EVENT_RATE
    F.install()
    R = F.R
    # イベント検出を拡張（_others_apply / _app_apply も「出来事」に数える）
    for nm in ("_others_apply", "_app_apply"):
        if hasattr(C, nm):
            def mk(f):
                def g(*a, **k):
                    if R.cur is None: R.begin()
                    R.cur["event"] = True
                    return f(*a, **k)
                return g
            setattr(C, nm, mk(getattr(C, nm)))
    if case == 1: C.EVENT_RATE = base * 1.5
    if case == 2:
        if not app: C.EVENT_DRAW_FILTER = True
        op = B.pour_all
        def pour(s):
            d = 0
            for w in reversed(R.weeks):
                if w["tourn"] or w["event"] or w["offer"] or w["inj"]: break
                d += 1
            C.EVENT_RATE = 1.0 if d >= 8 else base
            op(s)
        B.pour_all = pour
        # install() の pour ラッパが B.pour_all を差し替え済みなので、その外側に被せる
    bot = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), Spa(PNeedV3())][bi]
    pol = F.Wrap(bot)
    win = fin = 0; maxd = []; avgd = []; pos = []; ymax = []; dryfrac = []
    for i in range(n):
        R.weeks = []; R.year_jitsu = []; R.cur = None
        first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += ever
        wk = R.weeks
        years = {}
        for w in wk: years.setdefault(w["year"], []).append(w)
        best = (0, 0); lens = []
        for y, ws in years.items():
            run = 0; ym = 0
            for j, w in enumerate(ws + [dict(tourn=1)]):
                if not (w["tourn"] or w["event"] or w["offer"] or w["inj"]):
                    run += 1
                else:
                    if run:
                        lens.append(run); ym = max(ym, run)
                        if run > best[0]: best = (run, j - run + 1)   # 開始週(1始まり)
                    run = 0
            ymax.append(ym)
        maxd.append(best[0]); pos.append(best[1]); avgd.append(statistics.mean(lens) if lens else 0)
        nd = sum(1 for w in wk if not (w["tourn"] or w["event"] or w["offer"] or w["inj"]))
        dryfrac.append(100.0 * nd / max(1, len(wk)))
    return dict(case=case, app=app, bi=bi, n=n, win=100.0 * win / n, fin=100.0 * fin / n,
                maxd=statistics.mean(maxd), maxd90=sorted(maxd)[int(.9 * n)], maxdmax=max(maxd),
                yearmax=statistics.mean(ymax), avg=statistics.mean(avgd), pos=statistics.mean(pos),
                dryfrac=statistics.mean(dryfrac), nweeks=len(wk))

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    tasks = [(c, a, b, n) for a in (0, 1) for c in range(3) for b in range(3)]
    with Pool(6, maxtasksperchild=1) as p:
        res = p.map(work, tasks, chunksize=1)
    print(f"n={n} (1年の週数目安 {res[0]['nweeks']}週/キャリア全体)")
    for a in (0, 1):
        print(f"## EVENTS_APP={bool(a)}")
        for c in range(3):
            rs = [r for r in res if r["app"] == a and r["case"] == c]
            m = lambda k: statistics.mean(r[k] for r in rs)
            print(f"| {CASES[c]} | 最長(キャリア内平均){m('maxd'):.1f} p90 {m('maxd90'):.0f} 最大{max(r['maxdmax'] for r in rs)} | 年ごと最長平均{m('yearmax'):.1f} | 空白の平均長{m('avg'):.1f} | 最長の開始位置(年内の週){m('pos'):.1f} | 空白の週の割合{m('dryfrac'):.0f}% | " +
                  " ".join(f"{BOTS[r['bi']]}:決勝{r['fin']:.0f}/優勝{r['win']:.1f}" for r in sorted(rs, key=lambda r: r['bi'])) + " |")

if __name__ == "__main__":
    main()
