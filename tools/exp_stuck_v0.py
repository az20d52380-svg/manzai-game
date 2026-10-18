#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
詰み・抜け道の実測（2026-10-15）。ブランチ q60-62-impl の推奨設定（ネタの飽きD・知名度G）で、既定値は変えない。
使い方: python3 exp_stuck_v0.py [キャリア数=300] [part]   part = stuck | exploit | all（既定 all）
ボット: PCasual2 / PRotate / PNeedV3（通常）＋ 極端な1行動ボット。canon_v2.apply()・EVENTS_ON・NETA_ON=NETA_V2=True。
"""
import statistics, sys
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

# ---------------- 極端ボット ----------------
class POne(B.Policy):
    """1つの行動だけを繰り返す。大会（強制参加）は通常どおり。cycle=行動の巡回リスト"""
    def __init__(self, name, cycle, take_offer=False, rest_below=None, debt_job=False):
        self.name, self.cycle, self.take_offer, self.rest_below, self.i = name, cycle, take_offer, rest_below, 0
        self.debt_job = debt_job   # 借金したら返すまでバイトに専念（死のスパイラルから逃げられるかの検査）
    def choose(self, s, week, offer, rng):
        if self.debt_job and s.money < 0:
            if offer: return ("offer", None)
            return ("rest", "完全休養") if s.stamina < 20 else ("job", "標準")
        if offer and self.take_offer:
            return ("offer", None)
        if self.rest_below is not None and s.stamina < self.rest_below:
            return ("rest", "完全休養")
        a = self.cycle[self.i % len(self.cycle)]
        self.i += 1
        return a
    def transport(self, s):
        return B.TRAIN if s.money >= 150_000 else B.BUS

import bots_v3 as _bv3
class PNeedMax(PNeedV3):
    """金→力の変換を最大にしたやり込み（PNeedV3 に、有料の練習場所・有料の休み・低い貯金線を足した上限探し）"""
    name = "金→力 全振り(やり込み改)"
    BUFFER = 60_000
    def choose(self, s, week, offer, rng):
        if offer: return ("offer", None)
        if (week + 1) in C.EVENT_WEEKS and s.stamina < 75:
            return ("rest", "温泉に一泊" if s.money >= 600_000 else "完全休養")
        if s.money < self.BUFFER: return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "温泉に一泊" if s.money >= 600_000 else ("サウナ" if s.money >= 300_000 else "完全休養"))
        ab = self.target(s); need = _bv3.bottleneck(s, ab)
        best, amt_b = None, -1
        for nm, iss in _bv3.ISSUE.items():
            if B.TRAININGS[nm]["cost"] > 0 and s.money < 150_000: continue
            amt = iss.get(need, 0) / (1 + B.TRAININGS[nm]["cost"] / 400_000 * 0)   # 費用は気にしない（上限探し）
            if amt > amt_b: best, amt_b = nm, amt
        return ("train", best if amt_b > 0 else "ネタ合わせ")

def J(n): return ("job", n)
def T(n): return ("train", n)
def R(n): return ("rest", n)

def make(name):
    if name == "金→力 全振り(やり込み改)":
        B.enable_places(True); B.enable_paid_rests(True)
        _bv3.ISSUE.update({k: _bv3._issue(k) for k in B.TRAININGS})
        return PNeedMax()
    ordinary = {"PCasual2": PCasual2, "PRotate": PRotate, "PNeedV3": PNeedV3}
    if name in ordinary: return ordinary[name]()
    one = {
        "バイト標準だけ": POne(name, [J("標準")]),
        "バイトキツいだけ": POne(name, [J("キツい")]),
        "バイト楽だけ": POne(name, [J("楽")]),
        "バイト標準+体力20未満で休む": POne(name, [J("標準")], rest_below=20),
        "バイトキツい+体力35未満で休む": POne(name, [J("キツい")], rest_below=35),
        "バイト標準+オファー": POne(name, [J("標準")], take_offer=True, rest_below=20),
        "オファーだけ(無ければ休む)": POne(name, [R("完全休養")], take_offer=True),
        "完全休養だけ": POne(name, [R("完全休養")]),
        "気分転換だけ": POne(name, [R("気分転換")]),
        "相方と過ごすだけ": POne(name, [R("相方と過ごす")]),
        "ネタ作りだけ": POne(name, [T("ネタ作り")]),
        "ネタ合わせだけ": POne(name, [T("ネタ合わせ")]),
        "フリーライブだけ": POne(name, [T("フリーライブ")]),
        "ネタ見せ会だけ(有料8万)": POne(name, [T("ネタ見せ会")]),
        "ランニング・サウナだけ(有料8万)": POne(name, [T("ランニング・サウナ")]),
        "サウナ休みだけ(有料1万)": POne(name, [R("サウナ")]),
        "温泉一泊だけ(有料6万)": POne(name, [R("温泉に一泊")]),
        "喫茶店で書くだけ(有料1万)": POne(name, [T("喫茶店で書く")]),
        "作家の勉強会だけ(有料8万)": POne(name, [T("作家の勉強会")]),
        "ボイトレだけ(有料8万)": POne(name, [T("ボイトレ")]),
        # 稽古:バイトの比率（夜逃げの境目）。無料稽古k週→バイト標準1週、体力20未満は休む、オファー受ける
        **{f"無料稽古{k}週:バイト1週": POne(name, [T(["ネタ作り", "ネタ合わせ", "フリーライブ"][j % 3]) for j in range(k)] + [J("標準")], take_offer=True, rest_below=20) for k in (1, 2, 3, 5, 8)},
        **{f"無料稽古{k}週:バイト1週+借金したらバイト専念": POne(name, [T(["ネタ作り", "ネタ合わせ", "フリーライブ"][j % 3]) for j in range(k)] + [J("標準")], take_offer=True, rest_below=20, debt_job=True) for k in (2, 3, 5, 8)},
        # 2〜3行動の巡回（金→有料稽古の変換。「1行動だけ」では金が尽きるので別に見る）
        "巡回:バイト標準→ネタ見せ会→休養": POne(name, [J("標準"), T("ネタ見せ会"), R("完全休養")], take_offer=True),
        "巡回:バイトキツい→ネタ見せ会→休養": POne(name, [J("キツい"), T("ネタ見せ会"), R("完全休養")], take_offer=True),
        "巡回:バイト標準→ランニング・サウナ→休養": POne(name, [J("標準"), T("ランニング・サウナ"), R("完全休養")], take_offer=True),
        "巡回:バイト標準→作家の勉強会→休養": POne(name, [J("標準"), T("作家の勉強会"), R("完全休養")], take_offer=True),
        "巡回:バイト標準→温泉一泊(有料休み)": POne(name, [J("標準"), R("温泉に一泊")], take_offer=True),
    }
    return one[name]

ORDINARY = ["PCasual2", "PRotate", "PNeedV3"]
EXTREME = ["金→力 全振り(やり込み改)", "バイト標準だけ", "バイトキツいだけ", "バイト楽だけ", "バイト標準+体力20未満で休む", "バイトキツい+体力35未満で休む",
           "バイト標準+オファー", "オファーだけ(無ければ休む)", "完全休養だけ", "気分転換だけ", "相方と過ごすだけ",
           "ネタ作りだけ", "ネタ合わせだけ", "フリーライブだけ", "ネタ見せ会だけ(有料8万)", "ランニング・サウナだけ(有料8万)",
           "サウナ休みだけ(有料1万)", "温泉一泊だけ(有料6万)", "喫茶店で書くだけ(有料1万)", "作家の勉強会だけ(有料8万)", "ボイトレだけ(有料8万)",
           "巡回:バイト標準→ネタ見せ会→休養", "巡回:バイトキツい→ネタ見せ会→休養", "巡回:バイト標準→ランニング・サウナ→休養",
           "巡回:バイト標準→作家の勉強会→休養", "巡回:バイト標準→温泉一泊(有料休み)"] + [f"無料稽古{k}週:バイト1週" for k in (1, 2, 3, 5, 8)] + [f"無料稽古{k}週:バイト1週+借金したらバイト専念" for k in (2, 3, 5, 8)]
NEEDS_EXTRAS = lambda n: any(k in n for k in ("サウナ休み", "温泉", "喫茶店", "作家", "ボイトレ"))

# ---------------- 計測フック ----------------
def install():
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    C.V2_TIRED_PEN, C.V2_TIRED_CAP = 1.0, 2          # 推奨（飽きD）を明示
    B.enable_places(True); B.enable_paid_rests(True)   # 追加の有料行動は選んだボットだけが使う（通常ボットは名前で指定するので影響しない）
    o_year, o_roll, o_track = C.run_year, B.roll_offer, C._track_pass
    def run_year(pol, s, year, rng, **kw):
        s._yr = year
        r = o_year(pol, s, year, rng, **kw)
        if getattr(s, "_bankrupt", False) and not hasattr(s, "_bk_year"):
            s._bk_year = year
        s.__dict__.setdefault("_hist", {})[year] = (s.money, B.jitsuryoku(s), s.compat, s.mental, s.fame)
        return r
    def roll(s, rng):
        # 週頭(前週の生活費を払った後)の所持金。マイナスが続いた年数＝今の年 − マイナスに入った年 を記録
        if s.money < 0:
            if getattr(s, "_neg_start", None) is None:
                s._neg_start = s._yr
            s._neg_max = max(getattr(s, "_neg_max", 0), s._yr - s._neg_start + 1)
        else:
            s._neg_start = None
        return o_roll(s, rng)
    def track(s):
        d = s.__dict__.setdefault("_pass", {})
        d[s._yr] = d.get(s._yr, 0) + 1
        o_track(s)
    C.run_year, B.roll_offer, C._track_pass = run_year, roll, track

def one_run(args):
    name, n, init, compat = args
    install()
    pol = make(name)
    recs = []
    for i in range(n):
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i, init_ability=init, compat=compat)
        p = getattr(s, "_pass", {})
        recs.append(dict(won=first is not None, win_year=first, fin=ever, stage=stage,
                         bk=getattr(s, "_bankrupt", False), bk_year=getattr(s, "_bk_year", None),
                         neg=getattr(s, "_neg_max", 0), p13=sum(p.get(y, 0) for y in (1, 2, 3)),
                         hist=getattr(s, "_hist", {}), min_money=s.min_money))
    return name, init, compat, recs

def med(v): return statistics.median(v) if v else float("nan")
def pct(x, n): return 100.0 * x / n

def summarize(recs):
    n = len(recs)
    bk = [r for r in recs if r["bk"]]
    neg3 = sum(1 for r in recs if r["neg"] >= 4)       # 週頭の所持金<0が途切れず、年を4つまたぐ（=3年超）
    weak = [r for r in recs if r["p13"] <= 1 and not (r["won"] and r["win_year"] <= 3)]
    stuck = [r for r in weak if r["stage"] < 3]           # 10年までに準々決勝(GP3回戦まで通過)に一度も届かない
    weakB = [r for r in recs if r["p13"] <= 3 and not (r["won"] and r["win_year"] <= 3)]
    stuckB = [r for r in weakB if r["stage"] < 4]         # 3年で通過3回以下 → 10年で準決勝に一度も立てない
    out = dict(weakB=pct(len(weakB), n), stuckB_given=pct(len(stuckB), len(weakB)) if weakB else float("nan"), stuckB=pct(len(stuckB), n),
               semi=pct(sum(r["stage"] >= 4 for r in recs), n), p13_med=med([r["p13"] for r in recs]),
               p13_p10=sorted(r["p13"] for r in recs)[len(recs) // 10], n=n, win=pct(sum(r["won"] for r in recs), n), fin=pct(sum(r["fin"] for r in recs), n),
               qf=pct(sum(r["stage"] >= 3 for r in recs), n),
               bk=pct(len(bk), n), bk_year=med([r["bk_year"] for r in bk]),
               neg3=pct(neg3, n), weak=pct(len(weak), n), stuck=pct(len(stuck), n),
               stuck_given_weak=pct(len(stuck), len(weak)) if weak else float("nan"),
               stuck_nobk=pct(sum(1 for r in stuck if not r["bk"]), n))
    for y in (3, 5, 10):
        h = [r["hist"][y] for r in recs if y in r["hist"]]
        out[f"money{y}"] = med([x[0] for x in h]) / 10000          # 万円
        out[f"p90money{y}"] = (sorted(x[0] for x in h)[int(0.9 * len(h))] / 10000) if h else float("nan")
        out[f"jit{y}"] = med([x[1] for x in h])
        out[f"alive{y}"] = pct(len(h), n)
    h10 = [r["hist"][max(r["hist"])] for r in recs if r["hist"]]
    out["compat_end"] = med([x[2] for x in h10]); out["mental_end"] = med([x[3] for x in h10]); out["fame_end"] = med([x[4] for x in h10])
    return out

def fmt(name, o):
    return (f"{name}｜優勝{o['win']:.1f}% 決勝{o['fin']:.1f}% 準々以上{o['qf']:.1f}%｜夜逃げ{o['bk']:.1f}%(中央{o['bk_year']:.0f}年) "
            f"3年超マイナス{o['neg3']:.1f}%｜出だし不振{o['weak']:.1f}% うち這い上がれず{o['stuck_given_weak']:.0f}%(全体の{o['stuck']:.1f}%)｜"
            f"所持金中央 3年{o['money3']:.0f}万/5年{o['money5']:.0f}万/10年{o['money10']:.0f}万(p90 {o['p90money10']:.0f}万)｜"
            f"[厳]3年通過≤3:{o['weakB']:.1f}% うち準決に立てず{o['stuckB_given']:.0f}%(全体{o['stuckB']:.1f}%) 準決以上{o['semi']:.1f}% 3年通過中央{o['p13_med']:.0f}/p10 {o['p13_p10']}｜実力 3年{o['jit3']:.0f}/10年{o['jit10']:.0f}｜相性{o['compat_end']:.0f} メンタル{o['mental_end']:.0f}")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    part = sys.argv[2] if len(sys.argv) > 2 else "all"
    jobs = []
    if part in ("stuck", "all"):
        for nm in ORDINARY:
            jobs += [(nm, n, None, None), (nm, n, 8.0, 2.0), (nm, n, 5.0, 0.0)]   # 悪い出だし＝初期能力−20%(10→8)・相性2(既定5)／どん底＝初期能力−50%・相性0
    if part == "final":
        FIN = ["金→力 全振り(やり込み改)", "バイト標準だけ", "バイトキツいだけ", "バイトキツい+体力35未満で休む", "オファーだけ(無ければ休む)", "相方と過ごすだけ", "ネタ作りだけ",
               "巡回:バイト標準→作家の勉強会→休養", "巡回:バイトキツい→ネタ見せ会→休養", "巡回:バイト標準→温泉一泊(有料休み)"] + \
              [f"無料稽古{k}週:バイト1週" for k in (1, 2, 3, 5)] + [f"無料稽古{k}週:バイト1週+借金したらバイト専念" for k in (2, 3, 5, 8)]
        jobs += [(nm, n, None, None) for nm in FIN]
        for nm in ORDINARY:
            jobs += [(nm, n, None, None), (nm, n, 8.0, 2.0), (nm, n, 5.0, 0.0)]
    if part in ("exploit", "all"):
        jobs += [(nm, n, None, None) for nm in EXTREME]
        jobs += [(nm, n, 8.0, 2.0) for nm in EXTREME if nm.startswith(("バイト標準+オファー", "巡回:バイト標準→ネタ見せ会"))]
    print(f"=== 詰み・抜け道 | n={n} | q60-62-impl 推奨(飽きD・知名度G)・ネタ込み・イベント込み | 数値は【仮】 ===")
    with Pool(10, maxtasksperchild=1) as p:
        res = p.map(one_run, jobs, chunksize=1)
    for name, init, compat, recs in res:
        tag = ("どん底出だし" if init == 5.0 else "悪い出だし") if init else "通常出だし"
        print(fmt(f"[{tag}] {name}", summarize(recs)), flush=True)

if __name__ == "__main__":
    main()
