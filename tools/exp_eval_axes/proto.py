"""評価軸 v0 の試作（scratch・正典ではない）。sim_career/balance_sim を monkeypatch して
「ネタの型×能力の重み」「審査員の好み（◎○△×）」「尺の合う/合わない」「型ごとのブレ」「スベった夜」
「成長予算の均等課金」「ラインの引き直し」を入れ、ビルド別・年次別の通過率を測る。"""
import sys, math, copy, collections
import balance_sim as B
import sim_career as C

ABIL = ["sense", "idea", "expr", "chara"]
KATA = ["王道", "関係性", "伏線", "リターン", "非定型", "瞬発", "華先行"]
JUDGES = ["天堂寺", "花園", "卯月", "目白", "白波", "神楽坂", "音羽"]
BASE_W = (0.30, 0.30, 0.25, 0.15)

CFG = dict(
    ctx_on=True,
    alpha=1.0,            # 型の重みの傾きの強さ（0=全型が基本重み）
    omega={               # (センス, 発想, 表現, 華) 行和1.0
        "王道":   (0.40, 0.25, 0.25, 0.10),
        "関係性": (0.30, 0.20, 0.35, 0.15),
        "伏線":   (0.25, 0.45, 0.20, 0.10),
        "リターン": (0.35, 0.35, 0.20, 0.10),
        "非定型": (0.15, 0.40, 0.20, 0.25),
        "瞬発":   (0.25, 0.15, 0.40, 0.20),
        "華先行": (0.15, 0.15, 0.30, 0.40),
    },
    lenfit={
        "王道": "中長", "関係性": "中長", "伏線": "中長", "リターン": "短中長",
        "非定型": "短中長", "瞬発": "短中", "華先行": "短中",
    },
    lam=3.0,              # 尺が合わない減点
    nu={"王道": 0.9, "関係性": 1.0, "伏線": 1.0, "リターン": 0.85, "非定型": 1.35, "瞬発": 1.1, "華先行": 1.1},
    pval={"◎": 3.0, "○": 1.0, "△": 0.0, "×": -3.0},
    pref={  # NetaCatalog.affinityTable の写し（審査員順: 天堂寺 花園 卯月 目白 白波 神楽坂 音羽）
        "王道":   "◎○○○△◎○",
        "関係性": "○◎△△○○○",
        "伏線":   "○△◎◎△○△",
        "リターン": "○△○○○◎○",
        "非定型": "×△◎○△◎△",
        "瞬発":   "△○△△◎○◎",
        "華先行": "△○××○△◎",
    },
    semi_panel=3,         # 準決勝の審査員数（年で入れ替わる・0=中立）
    final_center=False,   # 決勝7人の好みの平均を型ごとに0へ寄せるか
    aud_fame=3.0,         # 観客票の知名度項: +aud_fame×(知名度−50)/50
    slip_p=0.0, slip_pen=0.0,   # スベった夜（ハマ判定と同じ一様乱数の上端を使う＝乱数の本数は不変）
    blur=(5.0, 15.0),     # ブレ幅 = floor + span×(1−メンタル/100)
    equal_budget=False,   # 成長予算を「生の伸び×0.25」で均等課金
    lines=None,           # 文脈→ライン（None=現行）
)

# 大会の形式（尺・審査）。審査=審査員名のリスト / "aud"=観客票 / []=中立（作家審査）
TOURN_CTX = {
    "春新人賞A": ("中", ["天堂寺"]),
    "春新人賞B": ("短", ["音羽"]),
    "夏中堅賞": ("長", ["目白"]),
    "大阪戎コンクール": ("中", ["花園"]),
    "若手限定賞": ("短", ["白波"]),
    "推薦制中堅賞": ("中", ["卯月"]),
}
GP_CTX = [("短", []), ("中", []), ("中", []), ("中", []), ("長", "semi")]
REV_CTX = ("長", "aud")
FIN_CTX = ("長", JUDGES)
CUR_LINES = {"GP0": 18, "GP1": 26, "GP2": 34, "GP3": 45, "GP4": 74, "REV": 76, "FIN": 80,
             "春新人賞A": 30, "春新人賞B": 28, "夏中堅賞": 33, "大阪戎コンクール": 22, "若手限定賞": 28, "推薦制中堅賞": 33}

def semi_panel(year, k=None):
    k = CFG["semi_panel"] if k is None else k
    if k <= 0:
        return []
    return [JUDGES[(3 * year + i) % 7] for i in range(k)]

def rot_panel(year, k, off):
    return [JUDGES[(3 * year + off + i) % 7] for i in range(k)]

def omega(kata):
    a = CFG["alpha"]
    if CFG.get("mult"):
        m = CFG["mult"][kata]
        return tuple(BASE_W[i] * (1 + a * (m[i] - 1)) for i in range(4))
    o = CFG["omega"][kata]
    return tuple(BASE_W[i] + a * (o[i] - BASE_W[i]) for i in range(4))

def pref_value(kata, judges):
    if not judges:
        return 0.0
    tab = CFG["pref"][kata]
    vals = [CFG["pval"][tab[JUDGES.index(j)]] for j in judges]
    v = sum(vals) / len(vals)
    if CFG["final_center"] and len(judges) == 7:
        allm = []
        for k in KATA:
            t = CFG["pref"][k]
            allm.append(sum(CFG["pval"][t[i]] for i in range(7)) / 7)
        v -= sum(allm) / len(allm)
    return v

def blur(m):
    f, sp = CFG["blur"]
    return f + sp * (1 - m / 100)

def stam_pen(s):
    for th, p in B.STAM_PEN:
        if s.stamina < th:
            return p
    return 0

def panel_mult(panel, length):
    """席の平均の倍率（審査員の傾き）＋予選の尺の傾き。Σw0·M=1 を保つ"""
    M = [1.0, 1.0, 1.0, 1.0]
    jm = CFG.get("judge_mult")
    if jm and isinstance(panel, list) and panel:
        a = CFG.get("alpha_j", 1.0)
        for i in range(4):
            M[i] += a * (sum(jm[j][i] for j in panel) / len(panel) - 1)
    fm = CFG.get("format_mult")
    if fm and isinstance(panel, list) and not panel and length in fm:
        for i in range(4):
            M[i] += fm[length][i] - 1
    return M

def beta(panel):
    bt = CFG.get("beta")
    if not bt:
        return 1.0
    if panel == "aud":
        return bt["aud"]
    n = len(panel) if isinstance(panel, list) else 0
    return bt["0"] if n == 0 else bt["1"] if n <= 2 else bt["3"] if n <= 5 else bt["7"]

def det_score(s, kata, ctx):
    """乱数を除いたスコア（文脈項込み）と、その型のブレ幅"""
    length, panel = ctx
    if kata is None or not CFG["ctx_on"]:
        J = B.jitsuryoku(s)
        return J + s.compat + stam_pen(s), blur(s.mental)
    o = omega(kata)
    M = panel_mult(panel, length)
    J = sum(o[i] * M[i] * getattr(s, ABIL[i]) for i in range(4))
    P = 0.0
    if panel == "aud":
        P = CFG["aud_fame"] * (s.fame - 50) / 50
    else:
        P = pref_value(kata, panel)
    L = 0.0 if length in CFG["lenfit"][kata] else -CFG["lam"]
    return J + s.compat + P + L + stam_pen(s), blur(s.mental) * CFG["nu"][kata] * beta(panel)

def pass_prob(base, b, line):
    """一様ブレ＋ハマ/スベリの混合での通過確率（ボットの読み用）"""
    def p_unif(d):
        if b <= 0:
            return 1.0 if d <= 0 else 0.0
        return min(1.0, max(0.0, (b - d) / (2 * b)))
    d = line - base
    pb, ps = B.BURST_P, CFG["slip_p"]
    return (1 - pb - ps) * p_unif(d) + pb * p_unif(d - B.BURST_BONUS) + ps * p_unif(d + CFG["slip_pen"])

def perform_ctx(s, line, rng, ctx, kata):
    base, b = det_score(s, kata, ctx)
    roll = rng.uniform(-b, b)
    if B.BURST_P:
        u = rng.random()
        if u < B.BURST_P:
            roll += B.BURST_BONUS
        elif CFG["slip_p"] and u >= 1 - CFG["slip_p"]:
            roll -= CFG["slip_pen"]
    score = base + roll
    return score >= line, score

# ---------------- 成長予算の均等課金 ----------------
_orig_add = B.add
def add_equal(s, key, amt):
    if key in ABIL and CFG["equal_budget"] and B.YEAR_GROWTH_CAP is not None and amt > 0:
        if B.GROWTH_DECAY_D:
            amt = amt * max(0.0, 1 - getattr(s, key) / B.GROWTH_DECAY_D)
        budget = B.YEAR_GROWTH_CAP - getattr(s, "_yg", 0.0)
        amt = max(0.0, min(amt, budget / 0.25))
        s._yg = getattr(s, "_yg", 0.0) + amt * 0.25
        setattr(s, key, B.clamp(getattr(s, key) + amt, 0, B.ABILITY_CAP))
        return
    _orig_add(s, key, amt)

_orig_pg = B.projected_gain
def projected_gain_equal(s, key, amount):
    if key in ABIL and CFG["equal_budget"]:
        if amount <= 0:
            return 0.0
        amt = amount
        if B.GROWTH_DECAY_D:
            amt = amount * max(0.0, 1 - getattr(s, key) / B.GROWTH_DECAY_D)
        if B.YEAR_GROWTH_CAP is not None and amt > 0:
            remaining = B.YEAR_GROWTH_CAP - getattr(s, "_yg", 0.0)
            amt = max(0.0, min(amt, remaining / 0.25))
        return B.clamp(getattr(s, key) + amt, 0, B.ABILITY_CAP) - getattr(s, key)
    return _orig_pg(s, key, amount)

# ---------------- ビルド別の注ぎ方 ----------------
_orig_pour_all = B.pour_all
def pour_build(s):
    r = getattr(s, "_build", None)
    if r is None:
        return _orig_pour_all(s)
    guard = 0
    while guard < 10_000:
        guard += 1
        cands = [a for a in B.ALL_ABILITIES if B._affordable_raw(s, a) > B.POUR_EPS]
        if not cands:
            break
        a = min(cands, key=lambda a: getattr(s, a) / r.get(a, 1.0))
        if B.pour_step(s, a) <= 0:
            break

# ---------------- 文脈の差し込み（呼び出し元のローカル変数から大会を特定） ----------------
CUR_BOT = None
STATS = collections.Counter()
_orig_perf = B.perform
_orig_gp = C._gp_perform

def _find(names, depth=2):
    f = sys._getframe(depth)
    out = {}
    while f is not None and len(out) < len(names):
        for n in names:
            if n not in out and n in f.f_locals:
                out[n] = f.f_locals[n]
        f = f.f_back
    return out

def _line_for(key, old_line, nominal):
    lines = CFG["lines"]
    if not lines or key not in lines:
        return old_line
    return old_line - nominal + lines[key]

def _run(s, line, rng, key, ctx, nominal, year):
    kata = CUR_BOT.pick(s, ctx, _line_for(key, line, nominal)) if (CUR_BOT and CFG["ctx_on"]) else None
    ln = _line_for(key, line, nominal)
    ok, sc = perform_ctx(s, ln, rng, ctx, kata)
    STATS[(year, key, "try")] += 1
    STATS[(year, key, "ok")] += ok
    if kata:
        STATS[("kata", key, kata)] += 1
    return ok, sc

def perf_wrapped(s, line, rng):
    loc = _find(["t", "year"])
    t = loc.get("t")
    tc = CFG.get("tourn_ctx") or TOURN_CTX
    if isinstance(t, dict) and t.get("name") in tc:
        name = t["name"]
        c = tc[name]
        ctx = (c[0], c[1] if c[1] != "all" else JUDGES)
        return _run(s, line, rng, name, ctx, CUR_LINES[name], loc.get("year", 0))
    return _orig_perf(s, line, rng)

def gp_wrapped(s, line, rng, final):
    loc = _find(["gp_stage", "year", "rev_line", "eff_line"])
    year = loc.get("year", 0)
    if not final:
        idx = loc["gp_stage"]
        length, panel = (CFG.get("gp_ctx") or GP_CTX)[idx]
        if panel == "semi":
            panel = semi_panel(year)
        elif isinstance(panel, str) and panel.startswith("rot"):
            k = int(panel[3:])
            panel = rot_panel(year, k, 0 if k == 3 else 4)
        return _run(s, line, rng, f"GP{idx}", (length, panel), CUR_LINES[f"GP{idx}"], year)
    if "eff_line" in loc and abs(loc["eff_line"] - line) < 1e-9:
        return _run(s, line, rng, "FIN", FIN_CTX, CUR_LINES["FIN"], year)
    return _run(s, line, rng, "REV", REV_CTX, CUR_LINES["REV"], year)

def _rebuild_issue():
    ISSUE.clear()
    for name, t in B.TRAININGS.items():
        d = {}
        for part in (t["main"], t["sub"]):
            if part and part[0].startswith("cur:"):
                d[part[0][4:]] = d.get(part[0][4:], 0) + part[1]
        ISSUE[name] = d

def install():
    if CFG.get("live_sub"):
        B.TRAININGS["フリーライブ"] = dict(B.TRAININGS["フリーライブ"], sub=tuple(CFG["live_sub"]))
    _rebuild_issue()
    B.perform = perf_wrapped
    C._gp_perform = gp_wrapped
    B.add = add_equal
    B.projected_gain = projected_gain_equal
    B.pour_all = pour_build

# ---------------- ボット ----------------
ISSUE = {}
for name, t in B.TRAININGS.items():
    d = {}
    for part in (t["main"], t["sub"]):
        if part and part[0].startswith("cur:"):
            d[part[0][4:]] = d.get(part[0][4:], 0) + part[1]
    ISSUE[name] = d

def bottleneck(s, ab):
    rec = B.ABILITY_RECIPE[ab]
    return min(rec, key=lambda cw: getattr(s, B.CURRENCY_ATTR[cw[0]]) / cw[1])[0]

class BuildBot(B.Policy):
    """v3対応のやり込み＋ビルド（注ぐ比率）＋持ちネタ4本＋読み（大会ごとに通過確率が最大の型を選ぶ）"""
    BUFFER = 150_000
    def __init__(self, name, ratios, portfolio, read=True, rest_before=75):
        self.name = name
        self.r = dict(ratios)
        self.r.setdefault("mental", 1.0)
        self.portfolio = portfolio
        self.read = read
        self.rest_before = rest_before

    def pick(self, s, ctx, line):
        port = CFG.get("portfolio_all") or self.portfolio
        if not self.read:
            return port[0]
        best, bp = None, -1
        for k in port:
            base, b = det_score(s, k, ctx)
            p = pass_prob(base, b, line)
            if p > bp + 1e-12:
                best, bp = k, p
        return best

    def target(self, s):
        perf_avg = sum(getattr(s, a) for a in ABIL) / 4
        if s.mental + 25 < perf_avg and s.mental < B.MENTAL_CAP:
            return "mental"
        return min(ABIL, key=lambda a: getattr(s, a) / self.r[a])

    def choose(self, s, week, offer, rng):
        s._build = self.r
        if offer:
            return ("offer", None)
        if (week + 1) in C.EVENT_WEEKS and s.stamina < self.rest_before:
            return ("rest", "完全休養")
        if s.money < self.BUFFER:
            return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "完全休養")
        if s.compat < B.COMPAT_CAP - 2 and week % 3 == 0:
            return ("train", "ネタ合わせ")   # 相性は全ビルド共通の床（人間は相方との稽古を欠かさない）
        need = bottleneck(s, self.target(s))
        best, amt = None, -1
        for name, iss in ISSUE.items():
            if B.TRAININGS[name]["cost"] > 0 and s.money < 400_000:
                continue
            if iss.get(need, 0) > amt:
                best, amt = name, iss.get(need, 0)
        if amt <= 0:
            best = "ネタ合わせ"
        return ("train", best)

    def transport(self, s):
        return B.TRAIN if s.money >= 150_000 else B.BUS

class CasualBot:
    """のんびり改（exp_human.PCasual2）＋おすすめ注ぎ＋持ちネタは作った順の4本・読まない（最初のネタを使う）"""
    def __init__(self, inner, portfolio=("王道", "関係性", "伏線", "リターン"), read=False):
        self.inner = inner
        self.name = inner.name + ("（読む）" if read else "")
        self.portfolio = list(portfolio)
        self.read = read
    def pick(self, s, ctx, line):
        return BuildBot.pick(self, s, ctx, line)
    def choose(self, s, week, offer, rng):
        s._build = None
        return self.inner.choose(s, week, offer, rng)
    def transport(self, s):
        return self.inner.transport(s)
    def __getattr__(self, k):
        return getattr(self.inner, k)

BUILDS = {
    "均等":   (dict(sense=1.0, idea=1.0, expr=1.0, chara=1.0), ["王道", "リターン", "瞬発", "伏線"]),
    "センス型": (dict(sense=1.5, idea=1.0, expr=1.0, chara=0.8), ["王道", "リターン", "関係性", "瞬発"]),
    "発想型": (dict(sense=1.0, idea=1.5, expr=0.9, chara=0.8), ["伏線", "リターン", "非定型", "王道"]),
    "表現型": (dict(sense=1.0, idea=0.9, expr=1.5, chara=0.9), ["関係性", "瞬発", "王道", "リターン"]),
    "華型":   (dict(sense=0.9, idea=0.9, expr=1.1, chara=1.5), ["華先行", "瞬発", "非定型", "関係性"]),
}

def run(pol, n, years=(1, 2, 3, 4, 5, 7, 10)):
    global CUR_BOT
    CUR_BOT = pol
    STATS.clear()
    wins = finals = 0
    first_years = []
    for i in range(n):
        first, s, _st, ever_final = C.run_career(pol, C.BASE_SEED + i)
        if first is not None:
            wins += 1
            first_years.append(first)
        finals += ever_final
    CUR_BOT = None
    return dict(win=100 * wins / n, fin=100 * finals / n, stats=dict(STATS), years=first_years)

def rate(stats, year, key):
    t = stats.get((year, key, "try"), 0)
    return (100 * stats.get((year, key, "ok"), 0) / t, t) if t else (None, 0)

def tourn_rate(stats, year):
    t = sum(stats.get((year, k, "try"), 0) for k in TOURN_CTX)
    o = sum(stats.get((year, k, "ok"), 0) for k in TOURN_CTX)
    return (100 * o / t, t) if t else (None, 0)

def table(res, years=(1, 2, 3, 4, 5, 7, 10)):
    cols = ["GP0", "GP1", "GP2", "GP3", "GP4", "FIN", "大会"]
    head = ["1回戦", "2回戦", "3回戦", "準々", "準決", "決勝", "道中"]
    out = ["年 " + "".join(f"{h:>7}" for h in head)]
    for y in years:
        cells = []
        for c in cols:
            r, t = tourn_rate(res["stats"], y) if c == "大会" else rate(res["stats"], y, c)
            cells.append(f"{r:6.0f}%" if r is not None and t >= 5 else f"{'-':>7}")
        out.append(f"{y:2d} " + "".join(cells))
    return "\n".join(out)

# ---------------- 年末の状態の記録（診断用） ----------------
YEAR_END = collections.defaultdict(list)
_orig_run_year = C.run_year
def run_year_rec(pol, s, year, rng, **kw):
    r = _orig_run_year(pol, s, year, rng, **kw)
    YEAR_END[year].append((s.sense, s.idea, s.expr, s.chara, s.mental, s.compat, s.money / 10000, s.fame))
    return r

def install_rec():
    C.run_year = run_year_rec

def profile(years=(3, 5, 10)):
    import statistics as st
    out = []
    for y in years:
        rows = YEAR_END.get(y, [])
        if not rows:
            continue
        med = [st.median(r[i] for r in rows) for i in range(8)]
        out.append(f"  {y}年末 S{med[0]:.0f} I{med[1]:.0f} E{med[2]:.0f} C{med[3]:.0f} M{med[4]:.0f} 相性{med[5]:.0f} 金{med[6]:.0f}万 知名度{med[7]:.0f}")
    return "\n".join(out)
