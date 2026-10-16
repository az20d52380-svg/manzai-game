#!/usr/bin/env python3
"""能力アップ詰まり（経験点はあるのに押せる＋が無い）の実測。usage: python3 exp_ability_stall_v0.py [n=1000]
式・既定値は変えない（仮の値・案はこのスクリプト内の差し替えだけ。終了時に全部戻す）。数値は全て【仮】。
前提＝exp_fun_audit_v0 の「今」案（NETA_ON・NETA_V2・イベント・練習の場所・有料の休み・知名度案G）。
注ぎ方: auto=本番ボットの recommended_plan 即時全量（詰まりにくい・Swiftの『おまかせ』相当）
        hand=人の手配り近似＝優先順（センス→発想→表現→華→メンタル）に、押せるだけ押し、押せなければ貯める
案: A 今のまま / B 配合OR（各能力は配合の粒のどれでも払える・総コスト同じ）/ C 練習ごとに粒を1種足す(+1.0・供給は増える)
    / C2 同(主効果−1.0で供給中立) / D 余りの粒を2:1で不足の粒へ交換（詰まった升だけ）"""
import sys, statistics, collections, copy
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
KEYS = list(PRE) + ["V2_TIRED_NEW"]
PRIORITY = ["sense", "idea", "expr", "chara", "mental"]
CUR = B.CURRENCIES
STALL_MIN = 5.0
EXTRA = {"ネタ作り": "maai", "ネタ見せ会": "hirameki", "ネタ合わせ": "goi", "ランニング・サウナ": "sonzaikan",
         "フリーライブ": "tanryoku", "喫茶店で書く": "maai", "ファミレスで書く": "maai", "作家の勉強会": "maai",
         "ボイトレ": "tanryoku"}
EXTRA_V = 1.0

bal = lambda s, c: getattr(s, B.CURRENCY_ATTR[c])

# ---- 記録 ----
class Rec:
    def __init__(self): self.reset()
    def reset(self):
        self.year = 0; self.weeks = []; self.snap = {}; self.issued = collections.Counter()
REC = Rec()

def headroom(s):
    return any(B.projected_gain(s, a, 1.0) > 0.05 for a in PRIORITY)
def pushable(s, a):
    return B._affordable_raw(s, a) > B.POUR_EPS and B.projected_gain(s, a, B._affordable_raw(s, a)) > B.POUR_EPS
def stalled(s):
    tot = sum(bal(s, c) for c in CUR)
    return tot >= STALL_MIN and headroom(s) and not any(pushable(s, a) for a in PRIORITY)

# ---- 注ぎ方 ----
def hand_pour(s):
    for a in PRIORITY:
        g = 0
        while g < 500 and B.pour_step(s, a) > 0: g += 1

# ---- 案D: 交換 ----
def swap_pass(s):
    for _ in range(10):
        did = False
        for a in PRIORITY:
            if pushable(s, a) or B.projected_gain(s, a, 1.0) <= 0.05: continue
            mult = B._rank_cost_multiplier(getattr(s, a))
            rec = dict(B.ABILITY_RECIPE[a])
            need = {c: max(0.0, w * mult - bal(s, c)) for c, w in rec.items()}
            tot_need = sum(need.values())
            src = sorted([c for c in CUR if c not in rec and bal(s, c) > 0], key=lambda c: -bal(s, c))
            if sum(bal(s, c) for c in src) < 2 * tot_need: continue
            rest = 2 * tot_need
            for c in src:
                t = min(bal(s, c), rest); setattr(s, B.CURRENCY_ATTR[c], bal(s, c) - t); rest -= t
                if rest <= 1e-12: break
            for c, n in need.items():
                setattr(s, B.CURRENCY_ATTR[c], bal(s, c) + n)
            did = True; break
        if not did: break

# ---- 案B: 配合OR ----
def or_afford(s, key):
    mult = B._rank_cost_multiplier(getattr(s, key))
    return min(B.ALLOCATION_STEP, sum(bal(s, c) for c, _ in B.ABILITY_RECIPE[key]) / mult)
def or_pour_step(s, key):
    amount = or_afford(s, key)
    if amount <= B.POUR_EPS: return 0.0
    gain = B.projected_gain(s, key, amount)
    if gain <= B.POUR_EPS: return 0.0
    mult = B._rank_cost_multiplier(getattr(s, key))
    rest = amount * mult
    for c in sorted([c for c, _ in B.ABILITY_RECIPE[key]], key=lambda c: -bal(s, c)):
        t = min(bal(s, c), rest); setattr(s, B.CURRENCY_ATTR[c], bal(s, c) - t); rest -= t
        if rest <= 1e-12: break
    B.add(s, key, amount)
    return gain

def install(mode, scheme):
    sc = 1.0
    if "@" in scheme:
        scheme, x = scheme.split("@"); sc = float(x)
    o = dict(scale0=B.EXP_SUPPLY_SCALE, pour_all=B.pour_all, run_year=C.run_year, credit=B.credit_currency, do_training=B.do_training,
             aff=B._affordable_raw, ps=B.pour_step, trains={k: dict(v) for k, v in B.TRAININGS.items()})
    B.EXP_SUPPLY_SCALE = o["scale0"] * sc
    base_pour = o["pour_all"] if mode == "auto" else hand_pour
    if scheme == "B":
        B._affordable_raw = or_afford; B.pour_step = or_pour_step
    if scheme in ("C", "C2"):
        def do_training(s, name):
            ok = o["do_training"](s, name)
            if ok and name in EXTRA:
                fac = B.DEBT_TRAIN_FACTOR if (B.DEBT_TRAIN_FACTOR is not None and s.money < 0) else 1.0
                B.credit_currency(s, EXTRA[name], EXTRA_V * fac)
            return ok
        B.do_training = do_training
        if scheme == "C2":
            for name, t in B.TRAININGS.items():
                k, v = t["main"]; t["main"] = (k, max(0.0, v - EXTRA_V))
    def pour(s):
        base_pour(s)
        if scheme == "D":
            swap_pass(s); base_pour(s)
        REC.weeks.append((REC.year, stalled(s), tuple(bal(s, c) for c in CUR)))
    def credit(s, c, v):
        if v > 0: REC.issued[c] += v * B.EXP_SUPPLY_SCALE
        return o["credit"](s, c, v)
    def run_year(pol, s, year, rng, **kw):
        REC.year = year
        r = o["run_year"](pol, s, year, rng, **kw)
        REC.snap[year] = (tuple(getattr(s, a) for a in PRIORITY), B.jitsuryoku(s),
                          tuple(bal(s, c) for c in CUR), dict(REC.issued))
        return r
    B.pour_all = pour; B.credit_currency = credit; C.run_year = run_year
    return o

def uninstall(o):
    B.pour_all = o["pour_all"]; C.run_year = o["run_year"]; B.credit_currency = o["credit"]
    B.EXP_SUPPLY_SCALE = o["scale0"]
    B.do_training = o["do_training"]; B._affordable_raw = o["aff"]; B.pour_step = o["ps"]
    for k, v in o["trains"].items(): B.TRAININGS[k].update(v)

def pct(a, b): return 100.0 * a / b if b else 0.0
def runs(flags):
    out = []; n = 0
    for f in flags:
        if f: n += 1
        else:
            if n: out.append(n)
            n = 0
    if n: out.append(n)
    return out

def measure(pol, n, mode, scheme):
    o = install(mode, scheme)
    try:
        win = fin = bk = ds = 0
        w_all = s_all = w_y1 = s_y1 = w_y13 = s_y13 = 0
        careers_stalled = 0; streaks = []; maxstreak = []
        balsum = [0.0] * 5; nb = 0
        ab1 = [[] for _ in range(5)]; ab3 = [[] for _ in range(5)]; j1 = []; j3 = []
        unspent = [[] for _ in range(5)]
        for i in range(n):
            REC.reset()
            first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i)
            win += first is not None; fin += ever
            bk += bool(getattr(s, "_bankrupt", False)); ds += bool(getattr(s, "_dissolved", False))
            fl = [w[1] for w in REC.weeks]
            w_all += len(fl); s_all += sum(fl)
            y1 = [w[1] for w in REC.weeks if w[0] == 1]; y13 = [w[1] for w in REC.weeks if w[0] <= 3]
            w_y1 += len(y1); s_y1 += sum(y1); w_y13 += len(y13); s_y13 += sum(y13)
            careers_stalled += any(y13)
            rs = runs(y13); streaks += rs; maxstreak.append(max(rs) if rs else 0)
            for w in REC.weeks:
                if w[0] <= 3:
                    nb += 1
                    for k in range(5): balsum[k] += w[2][k]
            if 1 in REC.snap:
                for k in range(5): ab1[k].append(REC.snap[1][0][k])
                j1.append(REC.snap[1][1])
            if 3 in REC.snap:
                for k in range(5):
                    ab3[k].append(REC.snap[3][0][k])
                    iss = REC.snap[3][3].get(CUR[k], 0.0)
                    if iss > 0: unspent[k].append(REC.snap[3][2][k] / iss)
                j3.append(REC.snap[3][1])
        m = lambda v: statistics.mean(v) if v else 0.0
        return dict(win=pct(win, n), fin=pct(fin, n), bk=pct(bk, n), ds=pct(ds, n),
                    st_all=pct(s_all, w_all), st_y1=pct(s_y1, w_y1), st_y13=pct(s_y13, w_y13),
                    cs=pct(careers_stalled, n), slen=m(streaks), sp90=(sorted(streaks)[int(.9 * len(streaks))] if streaks else 0),
                    smax=m(maxstreak), nruns=len(streaks) / n,
                    bal=[b / nb for b in balsum] if nb else [0] * 5, unspent=[m(u) * 100 for u in unspent],
                    ab1=[m(a) for a in ab1], ab3=[m(a) for a in ab3], j1=m(j1), j3=m(j3))
    finally:
        uninstall(o)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    only = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else None
    saved = {k: getattr(C, k) for k in KEYS if hasattr(C, k)}
    offr0 = list(B.OFFER_RATES)
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    for k, v in PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    try:
        bots = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()]
        combos = [("auto", "A"), ("hand", "A"), ("hand", "B"), ("hand", "C"), ("hand", "C2"), ("hand", "D")]
        if len(sys.argv) > 3:
            combos = [tuple(x.split("-", 1)) for x in sys.argv[3].split(",")]
        print(f"# n={n} careers/bot  stall=週末に経験点>= {STALL_MIN:.0f} かつ伸び余地あり かつ押せる＋0")
        for b in bots:
            for mode, sch in combos:
                tag = f"{mode}-{sch}"
                if only and tag not in only: continue
                r = measure(b, n, mode, sch)
                print(f"RESULT|{b.name}|{tag}|win={r['win']:.1f}|fin={r['fin']:.1f}|bk={r['bk']:.1f}|ds={r['ds']:.1f}|"
                      f"st_all={r['st_all']:.1f}|st_y1={r['st_y1']:.1f}|st_y13={r['st_y13']:.1f}|cs={r['cs']:.0f}|"
                      f"slen={r['slen']:.1f}|p90={r['sp90']}|smax={r['smax']:.1f}|nruns={r['nruns']:.1f}|"
                      f"bal={'/'.join(f'{x:.1f}' for x in r['bal'])}|unsp={'/'.join(f'{x:.0f}' for x in r['unspent'])}|"
                      f"ab1={'/'.join(f'{x:.0f}' for x in r['ab1'])}|ab3={'/'.join(f'{x:.0f}' for x in r['ab3'])}|"
                      f"j1={r['j1']:.1f}|j3={r['j3']:.1f}", flush=True)
    finally:
        B.enable_places(False); B.enable_paid_rests(False)
        B.OFFER_RATES = offr0
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        V.reset()
        for k, v in saved.items(): setattr(C, k, v)

if __name__ == "__main__":
    main()
