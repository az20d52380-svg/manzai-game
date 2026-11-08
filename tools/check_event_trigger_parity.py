"""選択肢イベントの「発火条件」を Swift と Python 鏡像で突き合わせる（読むだけ・正典は変えない）。
Swift: ChoiceEvent.swift の weeklyBandFireable／choices の gate／isWeeklyRandom、GameSession.swift の weeklyExtraGate／evaluateChoiceEventFire を
       正規表現で読み、式を Python に機械翻訳して状態の格子で評価する（翻訳できない式は「??」）。
Python: sim_career._app_band(+yearend の所持金ゲート)＝週次抽選の候補判定／_app_week_event＝確定発火（EVENT_RATE=0 にして抽選を止める）。
使い方: python3 tools/check_event_trigger_parity.py [--choice ChoiceEvent.swift] [--session GameSession.swift]
終了コード: 0=全一致 / 1=不一致か読めない条件あり
"""
import os, re, sys, random, argparse
from types import SimpleNamespace

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim_career as C
C.EVENTS_APP = True      # メモリ上のみ
C.EVENT_RATE = 0.0       # 確定発火の検査で週次抽選を引かせない

ap = argparse.ArgumentParser()
ap.add_argument("--choice", default=os.path.join(HERE, "..", "GameCore", "Sources", "GameCore", "ChoiceEvent.swift"))
ap.add_argument("--session", default=os.path.join(HERE, "..", "ManzaiGame", "Sources", "GameSession.swift"))
ap.add_argument("--n", type=int, default=200000)
args = ap.parse_args()

KEYMAP = {
    "brokedrink": "brokeDrinkingInvite", "meishi": "senpaiMeishi", "peerchair": "peerFoldedChair",
    "lineuptop": "lineupTop", "greenroom": "greenroomSilentTen", "lasttrain": "lastTrainReview",
    "luckythird": "luckyThirdLine", "wrote": "wroteOneTonight", "photo": "photoShootOffer",
    "kouhai": "kouhaiInvite", "senpai": "senpaiAllNight", "crew": "stageCrewChairs", "postcard": "writerPostcards",
    "douki": "doukiJointLive", "inventory": "baitoInventory", "homecoming": "homecomingCall", "fan": "regularFanOranges",
    "ticket": "officeTicketQuota", "festival": "summerFestivalGig", "tv": "doukiOnTV", "renovation": "theaterRenovation",
    "classmate": "classmateInAudience", "fever": "partnerFever", "notebook": "lostNotebook", "yearend": "yearEndLive",
}
SW2PY = {v: k for k, v in KEYMAP.items()}
CONFIRMED = {  # Swift 確定発火 case → Python counts キー
    "justLostRehearsal": "justlost", "styleTalk": "styletalk", "justPassedFork": "passfork", "preTournamentEve": "eve",
    "earlyFormality": "early", "tsuukaBreak": "tsuuka", "namelessReservationSlip": "nameless", "taniguchiShortJob": "tani",
}
VARS = {"justLostStage": "jl", "didFireLostRehearsal": "lost_fired", "lossStreak": "loss", "styleTalkDone": "style_done",
        "justPassedStage": "jp", "didFirePassFork": "fork_fired", "didFireEve": "eve_fired", "didFireEarlyFormality": "early_done",
        "didFireTsuukaChoice": "tsuuka_done", "didFireNamelessSlip": "nameless_fired", "didFireTaniguchiJob": "tani_fired",
        "didFireRiftWarn": "False", "inviteWaiting": "False", "jobCount": "jobs", "riftWarned": "False"}
ALLOWED = {"and", "or", "not", "int", "bool", "True", "False", "money", "fame", "stamina", "compat", "week", "year", "netas",
           "ahead", "has", "high", "COMPAT_CAP", "loss", "jobs", "jl", "jp", "lost_fired", "style_done", "fork_fired",
           "eve_fired", "early_done", "tsuuka_done", "nameless_fired", "tani_fired"}

class Unreadable(Exception): pass

def tr(expr):
    e = expr.strip()
    e = re.sub(r"\bstate\.", "", e); e = re.sub(r"\$0\.", "", e)
    for k, v in VARS.items(): e = re.sub(rf"\b{k}\b", v, e)
    e = e.replace("m.week - week", "ahead").replace("m.highStakes", "high").replace("config.compatCap", "COMPAT_CAP")
    e = e.replace("noTournamentWithin3Weeks()", "(ahead > 3)")
    e = re.sub(r"Int\(([^()]+)\)", r"int(\1)", e)
    e = re.sub(r"\(\s*(\d+)\s*\.\.\.\s*(\d+)\s*\)\.contains\(((?:[^()]|\([^()]*\))+)\)", r"(\1 <= \3 <= \2)", e)
    e = re.sub(r"!(\w+)\.isEmpty", r"bool(\1)", e)
    e = re.sub(r"!(?!=)", " not ", e)
    e = e.replace("&&", " and ").replace("||", " or ").replace("true", "True").replace("false", "False")
    e = re.sub(r"(?<=\d)_(?=\d)", "", e)
    for t in re.findall(r"[A-Za-z_]\w*", e):
        if t not in ALLOWED: raise Unreadable(f"{expr.strip()} (未知: {t})")
    return compile(e.strip(), "<swift>", "eval")

def split_top(s):
    out, d, cur = [], 0, ""
    for ch in s:
        if ch in "([{": d += 1
        if ch in ")]}": d -= 1
        if ch == "," and d == 0: out.append(cur); cur = ""
        else: cur += ch
    out.append(cur); return [x.strip() for x in out if x.strip()]

def nocomment(t): return re.sub(r"//[^\n]*", "", t)
def cases(seg):
    """`case .a, .b:` ごとの本文 {kind: body}"""
    parts = re.split(r"\n\s*case ((?:\.\w+(?:,\s*)?)+):", "\n" + seg)
    out = {}
    for i in range(1, len(parts), 2):
        for k in parts[i].split(","): out[k.strip().lstrip(".")] = parts[i + 1]
    return out

unread = []   # 読めない条件
# ---------- Swift 読み取り ----------
csrc = open(args.choice, encoding="utf-8").read()
ssrc = open(args.session, encoding="utf-8").read()

# 週次プール
m = re.search(r"var isWeeklyRandom: Bool \{(.*?)\n    \}", csrc, re.S)
pool = set(re.findall(r"\.(\w+)", nocomment(m.group(1)).split("return true")[0])) if m else set()

# 帯
a = csrc.index("private static func weeklyBandFireable"); seg = nocomment(csrc[a:])
BAND = {}
for k, body in cases(seg).items():
    mm = re.match(r"\s*return (.*?)\s*(?:\n\s*(?:case |default)|\Z)", body, re.S)
    if not mm: continue
    try: BAND[k] = tr(mm.group(1))
    except Unreadable as ex: unread.append(f"帯 {k}: {ex}")

# 選択肢の gate（1つも選べないなら出さない共通ルール）
a = csrc.index("public static func choices(for"); b = csrc.index("public static func weeklyFireable")
GATES = {}   # kind -> [gate式 or None]（選択肢ごと）
for k, body in cases(nocomment(csrc[a:b])).items():
    chunks = body.split("ChoiceEventChoice(")[1:]
    gl = []
    for ch in chunks:
        g = re.search(r"gate:\s*\{\s*(.*?)\s*\}", ch, re.S)
        if g:
            try: gl.append(tr(g.group(1)))
            except Unreadable as ex: unread.append(f"gate {k}: {ex}"); gl.append("??")
        else: gl.append(None)
    GATES[k] = gl

# 追加ゲート（GameSession.weeklyExtraGate）
a = ssrc.index("private func weeklyExtraGate"); b = ssrc.index("/// 今後の本番1件", a)
EXTRA = {}   # kind -> callable(env)->bool
for k, body in cases(nocomment(ssrc[a:b])).items():
    if k == "default": continue
    lines = [l.strip() for l in body.strip().split("\n") if l.strip() and l.strip() != "}" and not l.strip().startswith("default")]
    try:
        steps = []
        for l in lines:
            g = re.match(r"guard (.*) else \{ return (\w+) \}$", l)
            if g:
                conds = []
                for c in split_top(g.group(1)):
                    conds.append(compile("has", "<s>", "eval") if c.startswith("let ") else tr(c))
                steps.append(("guard", conds, g.group(2) == "true"))
            elif l.startswith("return "): steps.append(("ret", tr(l[7:])))
            else: raise Unreadable(l)
        EXTRA[k] = steps
    except Unreadable as ex: unread.append(f"追加ゲート {k}: {ex}"); EXTRA[k] = "??"

def run_extra(k, env):
    st = EXTRA.get(k)
    if st is None: return True
    if st == "??": return None
    for s in st:
        if s[0] == "guard":
            if not all(eval(c, {}, env) for c in s[1]): return s[2]
        else: return bool(eval(s[1], {}, env))
    return True

# 確定発火の連鎖
a = ssrc.index("private func evaluateChoiceEventFire"); b = ssrc.index("private func rollWeeklyRandomEvent")
seg = nocomment(ssrc[a:b]); seg = seg[seg.index("#endif") + 6:]
femme = [False]
def fix_female(t):
    if "femaleCombo" in t: femme[0] = True
    return re.sub(r"!\(state\.femaleCombo[^)]*\)", "True", t)
CHAIN = []
for mm in re.finditer(r"(?:\bif|\} else if) (.*?) \{\s*(?:pendingChoiceEvent = \.(\w+)|inviteWaiting = false)", seg, re.S):
    cond, kind = mm.group(1), mm.group(2) or "weekendInvite"
    try:
        cs = []
        for c in split_top(fix_female(cond)):
            cs.append(compile("has", "<s>", "eval") if c.startswith("let m = ") else tr(c))
        CHAIN.append((kind, cs))
    except Unreadable as ex: unread.append(f"確定発火 {kind}: {ex}"); CHAIN.append((kind, None))
known = []   # 既知の差（終了コードに数えない・理由は文書 §発火条件）
if femme[0]: known.append("確定発火 preTournamentEve: femaleCombo 節（花の動画審査）は Python 鏡像に無い＝この節だけ未照合（True 扱い）")

def swift_confirmed(env):
    for kind, cs in CHAIN:
        if cs is None: return "??"
        if all(eval(c, {}, env) for c in cs): return kind
    return None

def swift_weekly(k, env):
    if k not in pool: return False
    if k not in BAND: return None
    if not eval(BAND[k], {}, env): return False
    e = run_extra(k, env)
    if e is None: return None
    if not e: return False
    gl = GATES.get(k, [])
    if not gl or any(g is None for g in gl): return True
    if any(g == "??" for g in gl): return None
    return any(eval(g, {}, env) for g in gl)

# ---------- 格子 ----------
rnd = random.Random(1108)
WEEKS = sorted({t + d for t in (1, 3, 6, 8, 10, 12, 14, 15, 16, 20, 24, 33, 36, 38) for d in (-1, 0, 1)} | {52})
MONEY = [0, 1499, 1500, 19999, 20000, 49999, 50000, 99999, 100000, 149999, 150000, 199999, 200000, 500000]
FAME = [0, 4, 5, 9, 10, 14, 15, 19, 20, 29, 30, 39, 40, 49, 50, 51, 80]
STAM = [0, 14, 15, 39, 40, 49, 50, 79, 80, 100]
COMPAT = [0, 7, 7.9, 8, 14, 14.9, 15, 19, 20]
AHEAD = [99, 1, 2, 3, 4, 5, 6, 9]

def mkenv(**kw): return kw

def pystate(env):
    s = SimpleNamespace(money=env["money"], fame=env["fame"], stamina=env["stamina"], compat=env["compat"],
                        netas=[1] if env["netas"] else [], _jobs=env["jobs"], sense=50, idea=50, expr=50, chara=50, mental=50)
    return s

bad_weekly = {}; n_weekly = {}
for _ in range(args.n):
    env = dict(money=rnd.choice(MONEY), fame=rnd.choice(FAME), stamina=rnd.choice(STAM), compat=rnd.choice(COMPAT),
               week=rnd.choice(WEEKS), year=rnd.choice([1, 2, 3]), netas=rnd.choice([0, 1]), jobs=rnd.choice([0, 2, 3, 4]),
               loss=rnd.choice([0, 0, 1, 2]), ahead=rnd.choice(AHEAD), COMPAT_CAP=20.0)
    env["has"] = env["ahead"] != 99
    env.update(high=True, jl=False, jp=False, lost_fired=False, style_done=False, fork_fired=False, eve_fired=False,
               early_done=False, tsuuka_done=False, nameless_fired=False, tani_fired=False)
    s = pystate(env); nxt = (env["week"] + env["ahead"], True) if env["has"] else None
    a_ = dict(loss=env["loss"])
    for pk, sk in KEYMAP.items():
        sw = swift_weekly(sk, env)
        if sw is None: continue
        py = bool(C._app_band(pk, s, env["week"], env["year"], env["ahead"], nxt, a_) and (pk != "yearend" or s.money >= 1500))
        n_weekly[pk] = n_weekly.get(pk, 0) + 1
        if sw != py:
            d = bad_weekly.setdefault(pk, [0, None, set()])
            d[0] += 1
            if d[1] is None: d[1] = {k: env[k] for k in ("year", "week", "money", "fame", "stamina", "compat", "netas", "jobs", "loss", "ahead")} | {"swift": sw, "python": py}
            d[2] |= {k for k in ("year", "week", "money", "fame", "stamina", "compat", "netas", "jobs", "loss", "ahead") if True}

# 確定発火
bad_conf = {}; n_conf = 0
FLAGS = ["lost_fired", "style_done", "fork_fired", "eve_fired", "early_done", "tsuuka_done", "nameless_fired", "tani_fired"]
for _ in range(args.n):
    env = dict(money=rnd.choice([0, 99999, 100000, 300000]), fame=20, stamina=rnd.choice([10, 14, 15, 50, 70]),
               compat=rnd.choice([0, 7, 8, 14, 15, 20]), week=rnd.choice([1, 2, 3, 4, 14, 15, 16, 38]),
               year=rnd.choice([1, 2]), netas=0, jobs=0, loss=rnd.choice([0, 1, 2, 3, 4]), ahead=rnd.choice(AHEAD),
               high=rnd.choice([True, False]), jl=rnd.choice([False, True]), jp=rnd.choice([False, True]), COMPAT_CAP=20.0)
    env["has"] = env["ahead"] != 99
    one = rnd.choice([None] + FLAGS)
    env.update({f: (f == one) for f in FLAGS})
    sw = swift_confirmed(env)
    if sw == "??": continue
    if sw in ("riftWarning", "weekendInvite"): sw = None
    sw = CONFIRMED.get(sw, sw) if sw else None
    s = pystate(env); st = C._app_state(s)
    st.update(loss=env["loss"], jl=env["jl"], jp=env["jp"], lost_fired=env["lost_fired"], style_done=env["style_done"],
              fork_fired=env["fork_fired"], eve_fired=env["eve_fired"], early_done=env["early_done"],
              tsuuka_done=env["tsuuka_done"], nameless_fired=env["nameless_fired"], tani_fired=env["tani_fired"], counts={})
    stages = [(env["week"] + env["ahead"], env["high"])] if env["has"] else []
    C._app_week_event(s, env["year"], env["week"], stages, False)
    py = next(iter(st["counts"]), None)
    n_conf += 1
    if py != sw:
        d = bad_conf.setdefault((sw, py), [0, None]); d[0] += 1
        if d[1] is None: d[1] = {k: env[k] for k in ("year", "week", "money", "stamina", "compat", "loss", "ahead", "high", "jl", "jp")} | {"flags": one}

# ---------- 集計 ----------
ok = bad = 0; lines = []
for pk, sk in KEYMAP.items():
    if pk not in n_weekly: continue
    if pk in bad_weekly:
        bad += 1; c, ex, _ = bad_weekly[pk]
        lines.append(f"不一致(週次) {sk}/{pk}: {c}/{n_weekly[pk]} 件 例 {ex}")
    else: ok += 1
conf_kinds = {sw: 0 for sw in CONFIRMED.values()}
for (sw, py), (c, ex) in sorted(bad_conf.items(), key=lambda x: str(x[0])):
    bad += 1; lines.append(f"不一致(確定発火) Swift={sw} Python={py}: {c}/{n_conf} 件 例 {ex}")
ok += 0 if bad_conf else 1
pyset = set(C.APP_POOL); swset = {SW2PY.get(k, "?" + k) for k in pool}
extra_py = sorted(pyset - set(SW2PY.values())); extra_sw = sorted(k for k in pool if k not in SW2PY)
print(f"週次抽選プール: Python {len(pyset)}種 / Swift isWeeklyRandom {len(pool)}種  Pythonだけ={extra_py} Swiftだけ={extra_sw}")
if extra_py or extra_sw: bad += 1; lines.append(f"不一致(プールの顔ぶれ) Pythonだけ={extra_py} Swiftだけ={extra_sw}")
print(f"COMPAT_CAP: Python B={C.B.COMPAT_CAP} / Swift 既定=20.0（スクリプト固定）" + ("" if C.B.COMPAT_CAP == 20 else "  <-- 不一致"))
if C.B.COMPAT_CAP != 20: bad += 1
print(f"一致 {ok} / 不一致 {bad} / 読めない {len(unread)} / 既知 {len(known)}（週次 {len(n_weekly)}種を {args.n} 状態で・確定発火 {n_conf} 状態で評価）")
for l in lines: print(l)
for u in unread: print("読めない:", u)
for u in known: print("既知の差（数えない）:", u)
sys.exit(1 if (bad or unread) else 0)
