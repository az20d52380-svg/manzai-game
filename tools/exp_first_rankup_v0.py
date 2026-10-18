#!/usr/bin/env python3
"""1年目に最初に能力ランクが上がる（G→F＝15以上）のは何週目か。測るだけ（式・数値・乱数は触らない）。
usage: python3 exp_first_rankup_v0.py [n=300] [out.json]
sim の1年=48週（アプリ表示の52週に相当する年末）。ボット×ネタ(無/込)ごとに1年目だけ走らせて打ち切る。"""
import sys, json, statistics, itertools
from multiprocessing import Pool
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PRotate
from exp_places_v1 import Cafe
from exp_rests_v1 import Spa

OFFER_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
PRE = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2, FAME_V62=True, FAME_OTHER_MULT=0.6, FAME_OTHER_CAP=80.0,
           FAME_FINALIST=30.0, FAME_CHAMP=10, FAME_CHAMP_FLAT=True)
AB = ["sense", "idea", "expr", "chara", "mental"]
CUR = B.CURRENCIES
BAL = {c: B.CURRENCY_ATTR[c] for c in CUR}
RANKS = [(15, "G"), (25, "F"), (35, "E"), (45, "D"), (55, "C"), (70, "B"), (90, "A"), (1e9, "S")]
def rank(v):
    for t, r in RANKS:
        if v < t: return r
BOTNAMES = ["のんびり改(カフェ・温泉)", "ローテ(カフェ・温泉)", "CareerBalanced", "CareerSmart"]

class Stop(Exception): pass

def setup(neta):
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = bool(neta)
    for k, v in PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    # ボットは差し替えの後に作る
    return [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()]

def work(args):
    bi, neta, seeds = args
    bot = setup(neta)[bi]
    st = {"wk": 0, "first": None, "first4": None}
    o_pour, o_run = B.pour_all, C.run_year
    def pour(s):
        o_pour(s)
        st["wk"] += 1
        if st["first"] is None and max(getattr(s, a) for a in AB) >= 15: st["first"] = st["wk"]
        if st["first4"] is None and max(getattr(s, a) for a in AB[:4]) >= 15: st["first4"] = st["wk"]
    out = []
    B.pour_all = pour
    for sd in seeds:
        st["wk"] = 0; st["first"] = None; st["first4"] = None
        box = {}
        def run_year(pol, s, year, rng, **kw):
            r = o_run(pol, s, year, rng, **kw)
            box["s"] = s
            raise Stop
        C.run_year = run_year
        try:
            C.run_career(bot, C.BASE_SEED + sd)
        except Stop:
            pass
        s = box["s"]
        out.append(dict(first=st["first"], first4=st["first4"], allG4=all(getattr(s, a) < 15 for a in AB[:4]), ranks={a: rank(getattr(s, a)) for a in AB},
                        allG=all(getattr(s, a) < 15 for a in AB),
                        bal={c: getattr(s, BAL[c]) for c in CUR}))
    B.pour_all = o_pour; C.run_year = o_run
    return bi, neta, out

def summarize(rs):
    n = len(rs)
    f = sorted(r["first"] if r["first"] is not None else 99 for r in rs)
    never = sum(r["first"] is None for r in rs)
    q = lambda p: f[min(n - 1, int(p * n))]
    f4 = sorted(r["first4"] if r["first4"] is not None else 99 for r in rs)
    q4 = lambda p: f4[min(n - 1, int(p * n))]
    show = lambda v: ">48" if v == 99 else v
    dist = {a: {k: sum(r["ranks"][a] == k for r in rs) for k in "GFEDCBAS" if any(r["ranks"][a] == k for r in rs)} for a in AB}
    return dict(n=n, med=show(q(.5)), p75=show(q(.75)), med4=show(q4(.5)), p754=show(q4(.75)), allG4=100.0 * sum(r["allG4"] for r in rs) / n, never=100.0 * never / n,
                allG=100.0 * sum(r["allG"] for r in rs) / n, dist=dist,
                bal={c: statistics.mean(r["bal"][c] for r in rs) for c in CUR})

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    outp = sys.argv[2] if len(sys.argv) > 2 else None
    chunk = 25
    jobs = [(bi, neta, list(range(i, min(i + chunk, n)))) for bi in range(4) for neta in (False, True) for i in range(0, n, chunk)]
    res = {}
    with Pool(maxtasksperchild=1) as p:
        for bi, neta, out in p.imap_unordered(work, jobs):
            res.setdefault((bi, neta), []).extend(out)
    final = {}
    for (bi, neta), rs in sorted(res.items()):
        r = summarize(rs); final[f"{BOTNAMES[bi]}|{'ネタ込' if neta else 'ネタ無'}"] = r
        print(f"RESULT|{BOTNAMES[bi]}|{'ネタ込' if neta else 'ネタ無'}|n={r['n']}|med={r['med']}|p75={r['p75']}|med4={r['med4']}|p754={r['p754']}|allG4={r['allG4']:.1f}%|never={r['never']:.1f}%|allG={r['allG']:.1f}%|"
              f"dist={json.dumps(r['dist'], ensure_ascii=False)}|bal={ {c: round(v, 1) for c, v in r['bal'].items()} }", flush=True)
    if outp: json.dump(final, open(outp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
