"""GameConfig.swift・Calendar.swift の既定値と Python 正典（sim_career / balance_sim）の定数を突き合わせる。

swift test で直接参照されていない定数（10/27 時点の棚卸しで約30個）を中心に、
片方だけ変えて同期を忘れる事故を拾う。読むだけ・何も書き換えない。
使い方: cd tools && python3 check_config_sync.py   （不一致があれば終了コード1）
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import balance_sim as B
import sim_career as C

_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "GameCore", "Sources", "GameCore")
SWIFT = [os.path.join(_SRC, f) for f in ("GameConfig.swift", "Calendar.swift")]  # 大会の定数は Calendar.swift

# Swift の名前 → Python の値
PAIRS = {
    "careerYears":          C.YEARS,
    "champFame":            C.FAME_CHAMP,
    "fameFinalist":         C.FAME_FINALIST,
    "fameFinalBonus":       C.FAME_FINAL_BONUS,
    "gpRoundFame":          C.GP_ROUND_FAME,
    "gpPrize":              C.GP_PRIZE,
    "debtLifeStamina":      C.DEBT_LIFE_PEN[0],
    "debtLifeMental":       C.DEBT_LIFE_PEN[1],
    "riftHeal":             C.RIFT_HEAL,
    "riftJointStill":       C.RIFT_JOINT_STILL,
    "inviteMoney":          C.INVITE_MONEY,
    "inviteStamina":        C.INVITE_STAMINA,
    "inviteMental":         C.INVITE_MENTAL,
    "inviteIdea":           C.INVITE_IDEA,
    "injuryMentalHit":      C.INJURY_MENTAL,
    "weeklyEventRate":      C.EVENT_RATE,
    "weeklyEventCap":       C.APP_EVENT_CAP,
    "weeklyEventCapBaseYears":   C.APP_CAP_BASE_YEARS,
    "weeklyEventCapPerLateYear": C.APP_CAP_PER_YEAR,
    "capCurveBase":         C.CAP_CURVE[0],
    "capCurveSlope":        C.CAP_CURVE[1],
    "capCurveFloor":        C.CAP_CURVE[2],
    "growthEndYear":        C.GROWTH_END_YEAR,
    "netaSecondMinPolish":  C.V2_SECOND_MIN,
    "netaLivePolishShow":   C.V2_LIVE_SHOW,
    "netaLivePolishFree":   C.V2_LIVE_FREE,
    "netaBuzzAlpha":        C.V2_ALPHA,
    "netaBuzzPowerW":       C.V2_POWER_W,
    "netaBuzzPolishW":      C.V2_POLISH_W,
    "netaScoreCoefComp":    C.NETA_COEF_COMP,
    "netaScoreCoefBuzz":    C.V2_COEF_BUZZ,
    "netaScoreClamp":       C.NETA_CLAMP,
    "netaSecondPenalty":    C.NETA_SECOND_PEN,
    "netaTiredPenalty":     C.V2_TIRED_PEN,
    "netaTiredCap":         C.V2_TIRED_CAP,
    "itemDrinkStamina":     B.ITEM_DRINK_STAMINA,
    "itemDrinkLStamina":    B.ITEM_DRINK_L_STAMINA,
    "itemThroatInjuryMult": B.ITEM_THROAT_INJURY_MULT,
    # 較正A（11/02・calibration_all_1101_v0 §5）
    "gpRevivalLine":        C.GP_REVIVAL_LINE,
    "gpFinalLine":          C.GP_FINAL_LINE,
    "gpLateStartYear":      C.GP_LATE_START_YEAR,
    "gpLateLineBonus":      C.GP_LATE_LINE_BONUS,
    "lateGrowthDecay":      C.LATE_GROWTH_DECAY,
    "lateGrowthStartYear":  C.GP_LATE_START_YEAR,
    "tourneyExpK":          C.TOURNEY_EXP_K,
    "tourneyExpWeightRoad": C.TOURNEY_EXP_W["road"],
    "tourneyExpWeightRound": C.TOURNEY_EXP_W["round"],
    "tourneyExpWeightFinal": C.TOURNEY_EXP_W["final"],
    "tourneyExpUnit":       C.TOURNEY_EXP_UNIT,
    "tourneyExpSplit":      C.TOURNEY_EXP_SPLIT,
    "tourneyExpLoss":       C.TOURNEY_EXP_LOSS,
    "tourneyExpRoad":       C.TOURNEY_EXP_ROAD,
    "tourneyExpRoundStep":  C.TOURNEY_EXP_ROUND_STEP,
    "tourneyExpRevival":    C.TOURNEY_EXP_REVIVAL,
    "tourneyExpFinal":      C.TOURNEY_EXP_FINAL,
    # 周回 案2＋型1（11/02・calibration_meta_1102_v0 §5）
    "metaTopPoints":        C.META_TOP_POINTS,
    "metaCapLiftCoef":      C.META_CAP_LIFT_COEF,
    "metaCapLiftExp":       C.META_CAP_LIFT_EXP,
    "metaBudgetTop":        C.META_BUDGET_TOP,
    "metaTopExp":           C.META_TOP_EXP,
    "metaStartCompatCoef":  C.META_START_COMPAT_COEF,
    "metaStartCompatExp":   C.META_START_COMPAT_EXP,
    "metaStartCompatCap":   C.META_START_COMPAT_CAP,
    "metaStartExpPerPoint": C.META_START_EXP_PER_POINT,
    "metaStartExpCap":      C.META_START_EXP_CAP,
    "metaStartExpTop":      C.META_START_EXP_TOP,
    "metaStartMoneyPerPoint": C.META_START_MONEY_PER_POINT,
    "metaStartMoneyCap":    C.META_START_MONEY_CAP,
}

def swift_defaults(paths):
    out = {}
    for path in paths:
        out.update({k: v for k, v in _defaults(path).items() if k not in out})
    return out

def _defaults(path):
    out = {}
    pat = re.compile(r"public (?:static )?(?:var|let) (\w+)\s*(?::\s*[\w.]+)?\s*=\s*([^/\n]+)")
    for line in open(path, encoding="utf-8"):
        m = pat.search(line)
        if m and m.group(1) not in out:
            out[m.group(1)] = m.group(2).strip()
    return out

def parse(v):
    v = v.replace("_", "")
    if v in ("true", "false"):
        return v == "true"
    try:
        return float(v)
    except ValueError:
        return None

# THE HANA の段（週・名前・ライン・賞金・知名度）。golden の女性分岐は決勝まで届かないので、ここで突き合わせる（code_review_1108f 中1）
_HANA_RE = re.compile(r'TournamentSpec\(name:\s*"([^"]+)",\s*week:\s*(\d+),\s*line:\s*([\d.]+),\s*prize:\s*([\d_]+),\s*fame:\s*([\d.]+),\s*osaka:\s*(true|false),\s*eligibility:\s*\.hana\(round:\s*(\d+)\)')

def check_hana():
    sw = {}
    for line in open(os.path.join(_SRC, "Calendar.swift"), encoding="utf-8"):
        m = _HANA_RE.search(line)
        if m:
            nm, wk, ln, pr, fm, osk, rd = m.groups()
            sw[int(wk)] = dict(name=nm, line=float(ln), prize=int(pr.replace("_", "")), fame=float(fm), osaka=osk == "true", hana=int(rd))
    bad = 0
    if set(sw) != set(C.HANA_TOURNAMENTS):
        print(f"NG HANA の週: Swift {sorted(sw)} / Python {sorted(C.HANA_TOURNAMENTS)}"); bad += 1
    for w, t in C.HANA_TOURNAMENTS.items():
        s = sw.get(w)
        if s is None:
            continue
        for k in ("name", "line", "prize", "fame", "osaka", "hana"):
            if (s[k] != t[k]) if k in ("name", "osaka", "hana", "prize") else abs(float(s[k]) - float(t[k])) > 1e-12:
                print(f"NG HANA 週{w} {k}: Swift {s[k]} / Python {t[k]}"); bad += 1
    return bad, 1 + len(C.HANA_TOURNAMENTS)

# 道中の大会と GP の回戦（週・名前・ライン・賞金・知名度・大阪・資格）。golden のボットが出ない大会（推薦制など）もここで突き合わせる
_TOUR_RE = re.compile(r'TournamentSpec\(name:\s*"([^"]+)",\s*week:\s*(\d+),\s*line:\s*([\d.]+),\s*prize:\s*([\d_]+),\s*fame:\s*([\d.]+),\s*osaka:\s*(true|false),\s*eligibility:\s*\.(always|careerYearAtMost|fameAtLeast)(?:\(([\d.]+)\))?')

class _S:
    def __init__(self, fame): self.fame = fame

def check_tournaments():
    sw = {}
    gp = None
    for line in open(os.path.join(_SRC, "Calendar.swift"), encoding="utf-8"):
        m = _TOUR_RE.search(line)
        if m:
            nm, wk, ln, pr, fm, osk, el, arg = m.groups()
            sw[int(wk)] = dict(name=nm, line=float(ln), prize=int(pr.replace("_", "")), fame=float(fm), osaka=osk == "true", el=el, arg=float(arg) if arg else None)
        g = re.search(r"public var gpRounds: \[\(week: Int, line: Double\)\] = \[(.*?)\]", line)
        if g:
            gp = [tuple(float(x) for x in t) for t in re.findall(r"\((\d+),\s*([\d.]+)\)", g.group(1))]
    bad = 0
    if set(sw) != set(C.TOURNAMENTS):
        print(f"NG 大会の週: Swift {sorted(sw)} / Python {sorted(C.TOURNAMENTS)}"); bad += 1
    for w, t in C.TOURNAMENTS.items():
        s = sw.get(w)
        if s is None:
            continue
        for k in ("name", "line", "prize", "fame", "osaka"):
            if (s[k] != t[k]) if k in ("name", "osaka", "prize") else abs(float(s[k]) - float(t[k])) > 1e-12:
                print(f"NG 大会 週{w} {k}: Swift {s[k]} / Python {t[k]}"); bad += 1
        for year in range(1, C.YEARS + 2):
            for fame in (0, 29.9, 30, 50, 100):
                want = t["ok"](year, _S(fame))
                got = {"always": True, "careerYearAtMost": s["arg"] is not None and year <= s["arg"],
                       "fameAtLeast": s["arg"] is not None and fame >= s["arg"]}[s["el"]]
                if want != got:
                    print(f"NG 大会 週{w} 資格: {year}年目・知名度{fame} で Swift {got} / Python {want}"); bad += 1
                    break
            else:
                continue
            break
    py_gp = [(float(w), float(l)) for w, l, _ in C.GP_ROUNDS]
    if gp != py_gp:
        print(f"NG GP の回戦: Swift {gp} / Python {py_gp}"); bad += 1
    return bad, 2 + len(C.TOURNAMENTS)

def main():
    sw = swift_defaults(SWIFT)
    bad = 0
    for name, py in PAIRS.items():
        raw = sw.get(name)
        val = parse(raw) if raw is not None else None
        if val is None:
            print(f"?? {name}: Swift 側で既定値を読めない（{raw!r}）"); bad += 1
        elif isinstance(py, bool) or isinstance(val, bool):
            if bool(py) != val or isinstance(py, bool) != isinstance(val, bool):
                print(f"NG {name}: Swift {raw} / Python {py}"); bad += 1
        elif abs(float(py) - val) > 1e-12:
            print(f"NG {name}: Swift {raw} / Python {py}"); bad += 1
    bad_h, n_h = check_hana()
    bad += bad_h
    bad_t, n_t = check_tournaments()
    bad += bad_t; n_h += n_t
    print(f"config sync: {len(PAIRS) + n_h - bad}/{len(PAIRS) + n_h} 一致")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
