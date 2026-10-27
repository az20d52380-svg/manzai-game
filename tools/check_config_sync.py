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
    print(f"config sync: {len(PAIRS) - bad}/{len(PAIRS)} 一致")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
