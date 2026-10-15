#!/usr/bin/env python3
"""キュー78 ゲームの面白さの点検（実測側）。数値は全て【仮】・決定ではない。式・既定値は変えない（計測フックだけ差して戻す）。
usage: python3 exp_fun_audit_v0.py [n=300]
前提＝exp_money_balance_v1 の「今」案と同じ（NETA_ON・NETA_V2・飽きD・知名度案G・EVENTS_ON・練習の場所・有料の休み）。
出力（ボットごと）:
 ①週の分類: 大会/療養(強制)/オファー/資金強制/体力強制/大会前休養/自由 の割合。「実質1択の週」＝自由以外。自由週の稽古の選べる数
 ②同じ行動の連続: 週ごとの行動(種類)の最長連続・3連続以上に入る週の割合・稽古の偏り
 ③何も起きない週の連続: 大会/イベント/オファー/療養のどれも無い週の最長連続(キャリア内)・6週以上の連続に入る週の割合・大会と大会の間隔
 ④ボット間の差: 優勝％/決勝％/所持金中央値、最大-最小
 ⑤年ごとの伸び: 実力値の年末平均と前年差、伸びが0.5未満の年の割合"""
import sys, statistics, collections
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate
from exp_places_v1 import Cafe
from exp_rests_v1 import Spa

OFFER_NEW = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]
PRE = dict(V2_TIRED_PEN=1.0, V2_TIRED_CAP=2, FAME_V62=True, FAME_OTHER_MULT=0.6, FAME_OTHER_CAP=80.0,
           FAME_FINALIST=30.0, FAME_CHAMP=10, FAME_CHAMP_FLAT=True)
KEYS = list(PRE) + ["V2_TIRED_NEW"]
TOURN_WEEKS = set(C.EVENT_WEEKS)

class Rec:
    """1キャリアの週ごとの記録を溜める"""
    def __init__(self):
        self.cur = None; self.weeks = []; self.year_jitsu = []; self.year = 0
        self.wk = 0
    def start_year(self, y):
        self.year = y; self.wk = 0
    def begin(self):
        self.cur = dict(year=self.year, tourn=False, event=False, offer=False, inj=False,
                        cat=None, key=None, reason=None, nopt=0)
    def end(self):
        self.wk += 1
        self.cur["week"] = self.wk
        self.weeks.append(self.cur); self.cur = None

R = Rec()
CAREERS = []

class Wrap:
    """ボットの choose を包んで、選んだ時点の状態から「強制か自由か」を記録する"""
    def __init__(self, base):
        self.base = base; self.name = base.name
    def __getattr__(self, k):
        return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        if R.cur is None: R.begin()
        act, arg = self.base.choose(s, week, offer, rng)
        if offer: reason = "offer"
        elif s.money < 150_000: reason = "money"
        elif s.stamina < 35: reason = "stamina"
        elif (week + 1) in TOURN_WEEKS and s.stamina < 75: reason = "pre"
        else: reason = "free"
        R.cur["reason"] = reason
        R.cur["cat"] = act
        R.cur["key"] = f"{act}:{arg}"
        R.cur["nopt"] = sum(1 for n, d in B.TRAININGS.items() if d["cost"] <= s.money) if s.stamina >= C.STAMINA_GATE else 0
        return act, arg

def install():
    o = dict(run_year=C.run_year, enter=C.enter_tournament, gp=C._gp_perform, ev=C._apply_event,
             pour=B.pour_all, offer=B.do_offer, rest=B.do_rest)
    def run_year(pol, s, year, rng, **kw):
        R.start_year(year)
        r = o["run_year"](pol, s, year, rng, **kw)
        R.year_jitsu.append(B.jitsuryoku(s))
        return r
    def pour(s):
        if R.cur is None: R.begin()
        R.end() if False else None
        o["pour"](s)
        if R.cur is not None:
            R.end()
    def enter(s, pol, t, rng):
        if R.cur is None: R.begin()
        r = o["enter"](s, pol, t, rng)
        if r[0]: R.cur["tourn"] = True; R.cur["reason"] = "tourn"
        return r
    def gp(s, line, rng, final):
        if R.cur is None: R.begin()
        R.cur["tourn"] = True; R.cur["reason"] = "tourn"
        return o["gp"](s, line, rng, final)
    def ev(s, e):
        if R.cur is None: R.begin()
        if e in C.EVENT_TABLE or e in C.SEASONAL.values(): R.cur["event"] = True
        return o["ev"](s, e)
    def do_offer(s, off):
        if R.cur is None: R.begin()
        R.cur["offer"] = True
        return o["offer"](s, off)
    def do_rest(s, nm):
        if R.cur is not None and R.cur["reason"] is None:
            R.cur["reason"] = "inj"; R.cur["inj"] = True; R.cur["cat"] = "rest"; R.cur["key"] = "rest:療養"
        return o["rest"](s, nm)
    C.run_year, B.pour_all, C.enter_tournament, C._gp_perform, C._apply_event, B.do_offer, B.do_rest = \
        run_year, pour, enter, gp, ev, do_offer, do_rest
    return o

def uninstall(o):
    C.run_year, B.pour_all, C.enter_tournament, C._gp_perform, C._apply_event, B.do_offer, B.do_rest = \
        o["run_year"], o["pour"], o["enter"], o["gp"], o["ev"], o["offer"], o["rest"]

def pct(a, b): return 100.0 * a / b if b else 0.0

def runs(seq):
    out = []; prev = None; n = 0
    for x in seq:
        if x == prev: n += 1
        else:
            if prev is not None: out.append((prev, n))
            prev, n = x, 1
    if prev is not None: out.append((prev, n))
    return out

def analyze(pol, n):
    cat = collections.Counter(); tot = 0; nopt_free = []
    maxrun_cat = []; maxrun_key = []; in_run3 = 0; in_dry6 = 0; maxdry = []; tgap = []
    keyc = collections.Counter(); win = fin = 0; money = []
    yj = collections.defaultdict(list); stall = collections.defaultdict(lambda: [0, 0])
    one_choice_year = []
    for i in range(n):
        R.weeks = []; R.year_jitsu = []; R.cur = None
        first, s, _st, ever = C.run_career(pol, C.BASE_SEED + i)
        win += first is not None; fin += ever; money.append(s.money)
        wk = R.weeks
        # 週の分類（行動の無い週＝大会での強制は reason=tourn）
        for w in wk:
            r = w["reason"] or "tourn"
            cat[r] += 1; tot += 1
            if r == "free": nopt_free.append(w["nopt"]); keyc[w["key"]] += 1
        # ② 連続
        cs = [w["cat"] or "tourn" for w in wk]; ks = [w["key"] or "tourn" for w in wk]
        rc = runs(cs); rk = runs(ks)
        # 種類(job/train/rest/offer)の連続・同じ稽古名の連続
        if rc: maxrun_cat.append(max(l for k, l in rc if k != "tourn") if any(k != "tourn" for k, l in rc) else 0)
        if rk: maxrun_key.append(max(l for k, l in rk if k != "tourn") if any(k != "tourn" for k, l in rk) else 0)
        in_run3 += sum(l for k, l in rc if l >= 3 and k != "tourn")
        # ③ 何も起きない週
        dry = [not (w["tourn"] or w["event"] or w["offer"] or w["inj"]) for w in wk]
        dr = runs(dry); lens = [l for k, l in dr if k]
        maxdry.append(max(lens) if lens else 0)
        in_dry6 += sum(l for l in lens if l >= 6)
        tw = [j for j, w in enumerate(wk) if w["tourn"]]
        tgap += [b - a for a, b in zip(tw, tw[1:])]
        # ⑤
        prev = 0.0
        for y, j in enumerate(R.year_jitsu, 1):
            yj[y].append(j)
            if y >= 2:
                stall[y][1] += 1; stall[y][0] += (j - prev) < 0.5
            prev = j
    allw = tot
    forced = allw - cat["free"]
    res = dict(name=pol.name, n=n, win=pct(win, n), fin=pct(fin, n), money=statistics.median(money),
               tot=tot, cat=cat, forced=pct(forced, allw), nopt=statistics.mean(nopt_free) if nopt_free else 0,
               maxrun_cat=statistics.mean(maxrun_cat), maxrun_key=statistics.mean(maxrun_key),
               run3=pct(in_run3, allw), maxdry=statistics.mean(maxdry), maxdry90=sorted(maxdry)[int(.9 * len(maxdry))],
               dry6=pct(in_dry6, allw), tgap=statistics.median(tgap) if tgap else 0,
               keyc=keyc, yj=yj, stall=stall)
    return res

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    saved = {k: getattr(C, k) for k in KEYS if hasattr(C, k)}
    offr0 = list(B.OFFER_RATES)
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    for k, v in PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    o = install()
    try:
        bots = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), Spa(PNeedV3()), C.CareerBalanced(), C.CareerSmart(),
                B.PWork(), B.PTrain(), B.PRandom()]
        out = []
        for b in bots:
            r = analyze(Wrap(b), n); out.append(r)
            c = r["cat"]; t = r["tot"]
            lab = {"tourn": "大会", "inj": "療養", "offer": "オファー", "money": "資金強制", "stamina": "体力強制", "pre": "大会前休養", "free": "自由"}
            print(f"[{r['name']}] 優勝{r['win']:.1f}% 決勝{r['fin']:.1f}% 所持金中央{r['money']/10000:.0f}万", flush=True)
            print("  ①週 " + " ".join(f"{lab[k]}{pct(c[k], t):.0f}%" for k in lab) + f" | 実質1択(自由以外){r['forced']:.0f}% 自由週の稽古の数{r['nopt']:.1f}")
            top = r["keyc"].most_common(3); ft = sum(r["keyc"].values())
            print(f"  ②最長連続(種類){r['maxrun_cat']:.1f}週 最長連続(同一行動){r['maxrun_key']:.1f}週 3連続以上の週{r['run3']:.0f}% 自由週の上位=" +
                  " ".join(f"{k}{pct(v, ft):.0f}%" for k, v in top))
            print(f"  ③何も起きない最長{r['maxdry']:.1f}週(p90 {r['maxdry90']}) 6週以上の連続に入る週{r['dry6']:.0f}% 大会間隔中央{r['tgap']:.0f}週")
            ys = " ".join(f"{y}:{statistics.mean(v):.1f}" for y, v in sorted(r["yj"].items()))
            st = " ".join(f"{y}:{pct(a, b):.0f}%" for y, (a, b) in sorted(r["stall"].items()) if b >= 30)
            print(f"  ⑤実力値(年末平均) {ys}\n  ⑤伸び<0.5の年の割合 {st}")
        print("④ボット間: 優勝 " + " / ".join(f"{r['name']}{r['win']:.1f}" for r in out))
        sens = [r for r in out[:5]]
        print(f"  まともな5種の幅: 優勝{min(r['win'] for r in sens):.1f}〜{max(r['win'] for r in sens):.1f}% 決勝{min(r['fin'] for r in sens):.1f}〜{max(r['fin'] for r in sens):.1f}% "
              f"所持金中央{min(r['money'] for r in sens)/10000:.0f}〜{max(r['money'] for r in sens)/10000:.0f}万")
        print(f"  全8種の幅: 優勝{min(r['win'] for r in out):.1f}〜{max(r['win'] for r in out):.1f}% 決勝{min(r['fin'] for r in out):.1f}〜{max(r['fin'] for r in out):.1f}%")
    finally:
        uninstall(o)
        B.enable_places(False); B.enable_paid_rests(False)
        B.OFFER_RATES = offr0
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        V.reset()
        for k, v in saved.items(): setattr(C, k, v)

if __name__ == "__main__":
    main()
