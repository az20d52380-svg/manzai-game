"""選択肢イベントの効果を Swift（ChoiceEvent.swift）と Python 鏡像（sim_career._app_apply / _others_apply）で突き合わせる。

Python 側は方針（if/else）込みなので、状態を何通りも作って実行し、前後の差分が Swift のどれかの
選択肢の effects と完全一致するかを見る（クランプが効かない中間値の状態を使う）。
読むだけ・何も書き換えない。EVENTS_APP はメモリ上でのみ True にする。
使い方: cd tools && python3 check_event_parity.py   （不一致/未対応/読めない効果があれば終了コード1）
"""
import os, re, sys, itertools
from types import SimpleNamespace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_career as C

C.EVENTS_APP = True   # メモリ上のみ（ファイルは変えない）
SW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "GameCore", "Sources", "GameCore", "ChoiceEvent.swift")

# Python キー → Swift case（コメントの 0011〜0057 番号に対応。sim_career の OTHERS_EVENTS／APP_UNIQUE／_app_apply のキー）
KEYMAP = {
    "brokedrink": "brokeDrinkingInvite", "meishi": "senpaiMeishi", "peerchair": "peerFoldedChair",
    "lasttrain": "lastTrainReview", "wrote": "wroteOneTonight", "photo": "photoShootOffer",
    "justlost": "justLostRehearsal", "styletalk": "styleTalk", "passfork": "justPassedFork",
    "eve": "preTournamentEve", "tsuuka": "tsuukaBreak", "early": "earlyFormality", "tani": "taniguchiShortJob",
    "kouhai": "kouhaiInvite", "senpai": "senpaiAllNight", "crew": "stageCrewChairs", "postcard": "writerPostcards",
    "douki": "doukiJointLive", "inventory": "baitoInventory", "homecoming": "homecomingCall", "fan": "regularFanOranges",
    "ticket": "officeTicketQuota", "festival": "summerFestivalGig", "tv": "doukiOnTV", "renovation": "theaterRenovation",
    "classmate": "classmateInAudience", "fever": "partnerFever", "notebook": "lostNotebook", "yearend": "yearEndLive",
}
ABIL = {"センス": "sense", "発想": "idea", "表現": "expr", "華": "chara", "メンタル": "mental"}
CONFIG = {"config.netaBoostWeeks": 2, "config.photoShootPreoccupyWeeks": 1, "config.regularJobCeilingCost": 1.5}   # GameConfig.swift 既定（L368/L373）
NOT_PY = {"riftWarning", "weekendInvite", "regularEmployment", "namelessReservationSlip",
          "lineupTop", "greenroomSilentTen", "luckyThirdLine"}   # Python 鏡像の対象外（別実装／廃止／フレーバー）

# ---------------- Swift 読み取り ----------------
def split_args(s):
    out, d, cur = [], 0, ""
    for ch in s:
        if ch == "(": d += 1
        if ch == ")": d -= 1
        if ch == "," and d == 0: out.append(cur.strip()); cur = ""
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def parse_effects(body, unreadable, where):
    effs = []
    for m in re.finditer(r"\.(\w+)\(((?:[^()]|\([^()]*\))*)\)", body):
        name, args = m.group(1), split_args(m.group(2))
        try:
            def num(a):
                a = a.strip()
                if a in CONFIG: return CONFIG[a]
                if a.startswith("-") and a[1:] in CONFIG: return -CONFIG[a[1:]]
                return float(a.replace("_", ""))
            if name == "ability" and len(args) == 2 and args[0].lstrip(".") in ABIL:
                effs.append((ABIL[args[0].lstrip(".")], num(args[1])))
            elif name in ("compat", "stamina", "fame", "money"):
                effs.append((name, num(args[0])))
            elif name in ("weakestSkillPlus", "weakerSenseIdeaPlus"):
                effs.append((name, num(args[0])))
            elif name == "growthCeiling": effs.append(("_growth_ceiling", num(args[0])))   # Python 鏡像は成長天井を持たない（比較対象外・記録のみ）
            elif name == "rift": effs.append(("_rift", num(args[0])))
            elif name == "netaBoostNextWeek": effs.append(("_neta_boost", num(args[0])))
            elif name == "preoccupyNextWeek": effs.append(("_preocc", num(args[0])))
            else: raise ValueError
        except Exception:
            unreadable.append(f"{where}: .{name}({m.group(2)}) ??")
    return effs

def read_swift():
    src = open(SW, encoding="utf-8").read()
    a = src.index("public static func choices(for"); b = src.index("public static func weeklyFireable")
    seg = re.sub(r"//[^\n]*", "", src[a:b])
    unreadable, table = [], {}
    parts = re.split(r"\n\s*case ((?:\.\w+(?:,\s*)?)+):", seg)
    for i in range(1, len(parts), 2):
        kinds = [k.strip().lstrip(".") for k in parts[i].split(",")]
        body = parts[i + 1]
        chs = {}
        for m in re.finditer(r'ChoiceEventChoice\(id:\s*"(\w)",\s*effects:\s*\[(.*?)\]\s*(?:,\s*gate:[^)]*)?\s*\)', body, re.S):
            chs[m.group(1)] = parse_effects(m.group(2), unreadable, f"{kinds[0]}/{m.group(1)}")
        for k in kinds: table[k] = chs
    return table, unreadable

def swift_delta(effs, st):
    """Swift の effects を状態 st に適用した差分（クランプなし）。"""
    d = {}
    for k, v in effs:
        if k == "weakestSkillPlus":
            t = min(["sense", "idea", "expr", "chara"], key=lambda x: getattr(st, x)); d[t] = d.get(t, 0) + v
        elif k == "weakerSenseIdeaPlus":
            t = "sense" if st.sense <= st.idea else "idea"; d[t] = d.get(t, 0) + v
        else: d[k] = d.get(k, 0) + v
    return {k: v for k, v in d.items() if v}

# ---------------- Python 実行 ----------------
LAYOUTS = [dict(sense=40, idea=50, expr=60, chara=70), dict(sense=55, idea=45, expr=65, chara=35)]
STAMINA = [20, 30, 35, 40, 45, 49, 50, 52, 54, 55, 56, 59, 60, 65, 80]
MONEY = [0, 500, 999, 1000, 1200, 1499, 1500, 1800, 1999, 2000, 5000, 5999, 6000, 7999, 8000, 9999, 10000,
         29999, 30000, 49999, 50000, 80000, 150000]
KEYS = ["money", "stamina", "fame", "sense", "idea", "expr", "chara", "mental", "compat", "_neta_boost", "_preocc"]

def mkstate(lay, stam, money):
    return SimpleNamespace(money=money, stamina=stam, fame=50, mental=50, compat=10, _neta_boost=0, _preocc=0, **lay)

def run(pykey):
    fn = C._app_apply if pykey in APP_KEYS else C._others_apply
    seen = {}   # frozenset(delta) -> 代表状態
    for lay, stam, money in itertools.product(LAYOUTS, STAMINA, MONEY):
        s = mkstate(lay, stam, money); before = {k: getattr(s, k) for k in KEYS}
        fn(s, pykey)
        d = {k: getattr(s, k) - before[k] for k in KEYS if getattr(s, k) != before[k]}
        seen.setdefault(tuple(sorted(d.items())), (lay, stam, money, s))
    return seen

def py_keys():
    src = open(C.__file__, encoding="utf-8").read()
    def keys(fname):
        i = src.index(f"def {fname}("); j = src.index("\ndef ", i + 5)
        return set(re.findall(r'k == "(\w+)"', src[i:j]))
    return keys("_app_apply"), keys("_others_apply")

APP_KEYS, OTH_KEYS = py_keys()

SW_LATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "GameCore", "Sources", "GameCore", "ChoiceEventLate.swift")

def read_late(unreadable):
    """終盤イベント40本（ChoiceEventLate.swift の lateChoices）→ {kind: {id: (effects, gate額)}}。gate は `$0.money >= N` だけ読める"""
    if not os.path.exists(SW_LATE): return None
    src = open(SW_LATE, encoding="utf-8").read()
    seg = re.sub(r"//[^\n]*", "", src[src.index("static func lateChoices"):])
    out = {}
    parts = re.split(r"\n\s*case ((?:\.\w+(?:,\s*)?)+):", seg)
    for i in range(1, len(parts), 2):
        kinds = [k.strip().lstrip(".") for k in parts[i].split(",")]
        chs = {}
        for m in re.finditer(r'ChoiceEventChoice\(id:\s*"(\w)",\s*effects:\s*\[(.*?)\]\s*(?:,\s*gate:\s*\{(.*?)\})?\s*\)', parts[i + 1], re.S):
            gate = 0
            if m.group(3):
                g = re.fullmatch(r"\s*\$0\.money >= ([\d_]+)\s*", m.group(3))
                if g: gate = int(g.group(1).replace("_", ""))
                else: unreadable.append(f"{kinds[0]}/{m.group(1)}: gate {{{m.group(3)}}} ??")
            chs[m.group(1)] = (parse_effects(m.group(2), unreadable, f"{kinds[0]}/{m.group(1)}"), gate)
        for k in kinds: out[k] = chs
    return out

def check_late(unreadable):
    """late_events_data.py の表／_late_pick／_late_apply と Swift lateChoices を突き合わせる。(一致, 不一致行リスト, 件数)"""
    from late_events_data import LATE_EVENTS as LE
    sw = read_late(unreadable)
    if sw is None: return None
    ok, rows = 0, []
    norm = lambda effs: sorted((k, float(v)) for k, v in effs)
    for k in sorted(set(LE) | set(sw)):
        if k not in LE or k not in sw:
            rows.append(f"{k}: " + ("Swift に無い" if k not in sw else "Python 表に無い")); continue
        for cid in sorted(set(LE[k]) & {"A", "B"} | set(sw[k])):
            if cid not in sw[k] or cid not in LE[k]:
                rows.append(f"{k}/{cid}: 片側に選択肢が無い"); continue
            pe, pg = LE[k][cid]["eff"], LE[k][cid]["gate"]; se, sg = sw[k][cid]
            if norm(pe) == norm(se) and pg == sg: ok += 1
            else: rows.append(f"{k}/{cid}: Python eff={pe} gate={pg} / Swift eff={se} gate={sg}")
        # 実行側：_late_apply の差分が Swift のどちらかの選択肢（選べる方）と一致するか
        for lay, stam, money in itertools.product(LAYOUTS, STAMINA, MONEY):
            s = mkstate(lay, stam, money); before = {x: getattr(s, x) for x in KEYS}
            C._late_apply(s, k)
            d = {x: getattr(s, x) - before[x] for x in KEYS if getattr(s, x) != before[x]}
            avail = [cid for cid, (e, g) in sw[k].items() if money >= g]
            if not avail:
                if d: rows.append(f"{k}: 選べる選択肢が無い状態(所持金{money})で Python が効果 {d}"); break
                continue
            if not any(swift_delta(sw[k][cid][0], mkstate(lay, stam, money)) == d for cid in avail):
                rows.append(f"{k}: 体力{stam}/所持金{money} で Python の差分 {d} がどの選択肢とも違う"); break
        else: ok += 1
    return ok, rows, len(LE)

def main():
    table, unreadable = read_swift()
    ok = bad = noop = 0; rows = []; unreached = []
    for pk in sorted(APP_KEYS | OTH_KEYS):
        sk = KEYMAP.get(pk)
        if sk is None or sk not in table:
            rows.append((pk, sk or "(対応なし)", "-", "Swift に対応 case が無い／選択肢が読めない")); bad += 1; continue
        seen = run(pk); hit = set()
        for dkey, (lay, stam, money, st0) in sorted(seen.items(), key=lambda x: str(x[0])):
            d = dict(dkey); st = mkstate(lay, stam, money)
            m = [cid for cid, effs in table[sk].items() if swift_delta(effs, st) == d]
            if m: ok += 1; hit.update(m)
            elif not d: noop += 1   # ボットが何も選ばない状態（イベントは出るが効果なし）
            else:
                bad += 1
                exp = {cid: swift_delta(e, st) for cid, e in table[sk].items()}
                rows.append((pk, sk, f"体力{stam}/所持金{money}/{'セ<発' if lay['sense']<lay['idea'] else '発<セ'}", f"Python={d} Swift={exp}"))
        for cid in table[sk]:
            if cid not in hit and table[sk][cid]: unreached.append(f"{sk}/{cid}")
    mapped = set(KEYMAP.values())
    nopy = sorted(k for k, v in table.items() if v and k not in mapped and k not in NOT_PY)
    print(f"一致 {ok} / 不一致・未対応 {bad} / ボットが何もしない状態 {noop}（Python キー {len(APP_KEYS|OTH_KEYS)}・Swift case {len(table)}）")
    for r in rows: print("不一致:", " | ".join(r))
    for u in unreadable: print("読めない効果:", u)
    shown = list(unreadable)
    if unreached: print("Python ボットが一度も選ばない Swift 選択肢:", ", ".join(unreached))
    if nopy: print("Python 側に鏡像が無い Swift case（選択肢あり）:", ", ".join(nopy))
    late = check_late(unreadable)
    if late is None: print("終盤イベント: ChoiceEventLate.swift が無い（本体ブランチ）＝対象外")
    else:
        lok, lrows, ln = late
        print(f"終盤イベント{ln}本: 一致 {lok} / 不一致 {len(lrows)}（選択肢の効果・お金gate 80件＋_late_apply の実行 {ln}本）")
        for r in lrows: print("不一致(終盤):", r)
        bad += len(lrows)
    for u in unreadable[len(shown):]: print("読めない効果:", u)
    return 1 if (bad or unreadable) else 0

if __name__ == "__main__":
    sys.exit(main())
