#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
部屋(§90)・特技(§106)・お店の品の Python⇄Swift 一致確認用 golden 生成器（乱数なし・決定的）。
既存の gen_golden.py / golden とは独立。式は一切変えず、balance_sim / sim_career の関数をそのまま呼んで
各ステップ後の状態を JSON に書く。→ GameCore/Tests/GameCoreTests/Resources/golden_features.json
Swift側: FeatureGoldenTests.swift が同じ台本を GameCore で再生して全値比較する。
使い方: cd tools && python3 gen_golden_features.py
"""
import json, pathlib
import balance_sim as B
import sim_career as C

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "GameCore/Tests/GameCoreTests/Resources/golden_features.json"
import os
if os.environ.get("GOLDEN_FEATURES_OUT"): OUT = pathlib.Path(os.environ["GOLDEN_FEATURES_OUT"])   # check_golden_sync が一時ファイルへ書かせて突き合わせる

CUR = ["hirameki", "goi", "maai", "sonzaikan", "tanryoku"]

def new_state(init):
    s = B.S()
    for k, v in init.items():
        if k == "room": s.room = v
        elif k == "skills": s.skills = set(v)
        elif k.startswith("exp_"): setattr(s, k, v)
        else: setattr(s, k, v)
    return s

def snap(s):
    d = dict(money=float(s.money), stamina=float(s.stamina), fame=float(s.fame), mental=float(s.mental),
             compat=float(s.compat), rift=float(getattr(s, "rift", 0.0) or 0.0),
             sento=float(getattr(s, "sento_tickets", None) or 0),
             shinkansen=1.0 if getattr(s, "shinkansen_active", None) else 0.0,
             skills=sorted(getattr(s, "skills", ())),
             counts={k: v for k, v in sorted((getattr(s, "item_counts", None) or {}).items())})
    for c in CUR: d["exp_" + c] = float(getattr(s, "exp_" + c))
    return d

def run(name, init, ops):
    s = new_state(init)
    steps = []
    for op in ops:
        o = op["op"]; val = None
        if o == "set":
            for k, v in op["v"].items(): setattr(s, k, v)
        elif o == "rest": B.do_rest(s, op["name"])
        elif o == "buy": val = 1.0 if B.buy_item(s, op["item"]) else 0.0
        elif o == "learn": val = 1.0 if B.learn_skill(s, op["skill"]) else 0.0
        elif o == "week_end":
            if op["week"] % B.LIVING_INTERVAL == 0:
                B.pay_living(s)
        elif o == "living_due": val = float(B.living_cost(s) + B.rent_due(s))
        elif o == "move_room": val = 1.0 if B.move_room(s, op["to"]) else 0.0
        elif o == "new_year": B.reset_yearly_items(s)
        elif o == "fame": B.add(s, "fame", op["amt"])
        elif o == "rift":
            s._joint = op.get("joint", False)
            C.rift_weekend(s, op["year"], op["compat0"])
        elif o == "injury_prob":
            val = (C.INJURY_TH - s.stamina) * C.INJURY_P_PER * B.throat_mult(s) * (B.SKILL_INJURY_MULT if B.has_skill(s, "体が資本") else 1.0)
        else: raise SystemExit("unknown op " + o)
        steps.append(dict(op=op, state=snap(s), value=val))
    return dict(name=name, init=init, steps=steps)

# ---------------------------------------------------------------------------------------------
# 拡張台本（10/19）：ネタの補正・飽き・書く/ライブの伸び（NETA_V2＝アプリと同じ式）／追加の札・テレビ慣れ。乱数なし（追加の札は
# シード→ハッシュのみで本編の乱数は消費しない決定論）。Python の関数をそのまま呼ぶ。生成器内でだけ NETA_V2 を立て、終わったら戻す。
# ---------------------------------------------------------------------------------------------
def _mk_neta(d):
    return dict(comp=float(d["comp"]), buzz=float(d["buzz"]), fresh=0.0, used=set(), tired=int(d.get("tired", 0)))

def neta_bonus_cases():
    out = []
    # 補正＝(完成度-50)×0.04＋(手応え-50)×0.02 を±5で頭打ち、飽き1段ごとに-1
    for comp, buzz in ((30, 0), (50, 50), (80, 60), (100, 100), (0, 0), (60, 40), (100, 0), (0, 100)):
        for tired in (0, 1, 2, 3):
            n = _mk_neta(dict(comp=comp, buzz=buzz, tired=tired))
            out.append(dict(kind="bonus", comp=float(comp), buzz=float(buzz), tired=tired, value=float(C._neta_bonus(n, "x"))))
    # 決勝：1本目はボットと同じく補正最大を選ぶ／2本目は残りの完成度最大。2本目が無い・60未満は-3
    sets = [
        [], [dict(comp=70, buzz=50)],
        [dict(comp=70, buzz=50), dict(comp=59.9, buzz=0)],
        [dict(comp=70, buzz=50), dict(comp=60, buzz=0)],
        [dict(comp=40, buzz=20), dict(comp=90, buzz=80, tired=2)],
        [dict(comp=90, buzz=80, tired=2), dict(comp=75, buzz=10, tired=1), dict(comp=65, buzz=90)],
        [dict(comp=100, buzz=100), dict(comp=100, buzz=100, tired=1)],
    ]
    for sp in sets:
        s = B.S(); s.netas = [_mk_neta(x) for x in sp]
        adj = C._neta_line_adj(s, "x", None, final=True)
        pick = next((i for i, n in enumerate(s.netas) if n.get("used_y")), None)
        second = None
        if pick is not None:
            others = [i for i in range(len(s.netas)) if i != pick]
            if others: second = max(others, key=lambda i: s.netas[i]["comp"])
        out.append(dict(kind="final", netas=[dict(comp=float(x["comp"]), buzz=float(x["buzz"]), tired=int(x.get("tired", 0))) for x in sp],
                        pick=pick, second=second, value=float(-adj)))
    return out

def neta_grow_scripts():
    """書く場所ごとの完成度の伸び（新規2本→最低完成度に上乗せ・100で頭打ち）と、ネタ見せ会/フリーライブの手応え・完成度の伸び"""
    out = []
    trains = ["ネタ作り", "喫茶店で書く", "ファミレスで書く", "ネタ作り", "喫茶店で書く", "ファミレスで書く"]
    trains += ["ネタ見せ会", "フリーライブ", "ネタ見せ会", "フリーライブ", "フリーライブ"] + ["ファミレスで書く", "ネタ見せ会"] * 8
    for name, init in (("grow_default", {}), ("grow_strong", dict(sense=60.0, idea=55.0, expr=50.0, chara=45.0))):
        s = B.S()
        for k, v in init.items(): setattr(s, k, v)
        s.netas = []
        steps = []
        for tr in trains:
            before = [dict(n) for n in s.netas]
            C._neta_on_train(s, tr)
            if len(s.netas) > len(before): idx = len(s.netas) - 1; ev = "new"
            else:
                diff = [i for i, (a, b) in enumerate(zip(before, s.netas)) if a["comp"] != b["comp"] or a["buzz"] != b["buzz"]]
                ev = "touch"
                idx = diff[0] if diff else min(range(len(s.netas)), key=lambda i: before[i]["comp"])   # 100頭打ちで変化なしの週
            steps.append(dict(train=tr, idx=idx, ev=ev, polish=[n["comp"] for n in s.netas], buzz=[n["buzz"] for n in s.netas]))
        out.append(dict(name=name, init=init, steps=steps))
    return out

def offer_scripts():
    out = {"extra": [], "fatigue": []}
    seeds = [1, 12345, 2**40 + 7, 2**63 + 12345, 0xFFFFFFFFFFFFFFF0]
    for first in ("ひな壇", "ラジオ", "ロケ", "営業"):
        for fame in (0.0, 29.9, 30.0, 54.9, 55.0, 99.0):
            for seed in seeds:
                for (y, w) in ((1, 5), (3, 48)):
                    got = C.extra_offers(seed, y, w, fame, first)
                    out["extra"].append(dict(seed=str(seed), year=y, week=w, fame=fame, first=first,
                                             names=[o["name"] for o in got],
                                             income=[float(o["income"]) for o in got], gfame=[float(o["fame"]) for o in got],
                                             stam=[float(o["stam"]) for o in got]))
    # テレビ慣れ：直近6週に4回受けた次から、受けるたびに センス・表現 -0.5。窓（今週-受けた週<6）の境目と所持金・知名度の加算
    seqs = {"dense": [1, 2, 3, 4, 5, 6, 7], "window_edge": [1, 2, 3, 4, 10, 11, 12, 13, 14], "sparse": [1, 7, 13, 19, 25, 31]}
    for nm, wks in seqs.items():
        for fame0 in (0.0, 50.0):
            for sp in B.OFFERS_NAMED:
                s = B.S(); s.fame = fame0; s.money = 1000
                steps = []
                for wk in wks:
                    s._wk = wk
                    B.do_offer(s, sp)
                    steps.append(dict(wk=wk, money=float(s.money), fame=float(s.fame), stamina=float(s.stamina),
                                      sense=float(s.sense), expr=float(s.expr), weeks=list(s.offer_weeks)))
                out["fatigue"].append(dict(name=f"{nm}_f{int(fame0)}_{sp['name']}", fame0=fame0, offer=sp["name"], steps=steps))
    return out

# ---------------------------------------------------------------------------------------------
# 選択イベントの効果（10/19・docs/golden_event_effects_1019_v0.md）：決まった開始状態に、sim の方針が選ぶ側の効果を
# EVENTS_APP=True の _app_apply / _others_apply で当てた後の状態。乱数なし。side は sim の分岐（体力・所持金）と同じ条件を
# ここで写したラベル（Swift はこの側の effects を applyEventEffect で当てる＝側の取り違えは状態の食い違いとして表に出る）。
# 方針が何も起こさない状態（ticket の体力<50かつ所持金<6000／yearend の所持金<1500）は対象外。sim が選ばない側は対象外。
# ---------------------------------------------------------------------------------------------
EV_STATES = {
    "hi":   dict(sense=40.0, idea=30.0, expr=35.0, chara=25.0, mental=60.0, stamina=90.0, money=500_000, compat=5.0, fame=40.0),
    "lo":   dict(sense=10.0, idea=10.0, expr=12.0, chara=8.0, mental=20.0, stamina=20.0, money=800, compat=3.0, fame=5.0),
    "edge": dict(sense=119.0, idea=118.0, expr=117.5, chara=119.0, mental=99.0, stamina=55.0, money=60_000, compat=19.5, fame=98.0),
}
# (python key, Swift ChoiceEventKind, 適用関数, 側を返す関数(s)→'A'/'B'/'C'/None)
_EV = [
    ("justlost",  "justLostRehearsal", "app", lambda s: "A" if s.stamina >= 50 else ("C" if s.money >= 1500 else "B")),
    ("styletalk", "styleTalk",         "app", lambda s: "B"),
    ("passfork",  "justPassedFork",    "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("eve",       "preTournamentEve",  "app", lambda s: "A" if s.stamina >= 60 else "B"),
    ("tsuuka",    "tsuukaBreak",       "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("early",     "earlyFormality",    "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("tani",      "taniguchiShortJob", "app", lambda s: "A" if s.stamina >= 35 else "B"),
    ("brokedrink","brokeDrinkingInvite","app", lambda s: "A" if s.money >= 10_000 else "B"),
    ("meishi",    "senpaiMeishi",      "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("peerchair", "peerFoldedChair",   "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("lasttrain", "lastTrainReview",   "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("wrote",     "wroteOneTonight",   "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("photo",     "photoShootOffer",   "app", lambda s: "A" if s.stamina >= 50 else "B"),
    ("kouhai",    "kouhaiInvite",      "oth", lambda s: "A" if s.money >= 50_000 else "B"),
    ("senpai",    "senpaiAllNight",    "oth", lambda s: "A" if s.stamina >= 60 else "B"),
    ("crew",      "stageCrewChairs",   "oth", lambda s: "A" if s.stamina >= 50 else "B"),
    ("postcard",  "writerPostcards",   "oth", lambda s: "A" if s.stamina >= 50 else "B"),
    ("douki",     "doukiJointLive",    "oth", lambda s: "A" if (s.money >= 50_000 and s.stamina >= 50) else "B"),
    ("inventory", "baitoInventory",    "oth", lambda s: "A" if s.stamina >= 50 else "B"),
    ("homecoming","homecomingCall",    "oth", lambda s: "A" if s.money >= 50_000 else "B"),
    ("fan",       "regularFanOranges", "oth", lambda s: "A" if s.money >= 30_000 else "B"),
    ("ticket",    "officeTicketQuota", "oth", lambda s: "A" if s.stamina >= 50 else ("B" if s.money >= 6000 else None)),
    ("festival",  "summerFestivalGig", "oth", lambda s: "A" if s.stamina >= 55 else "B"),
    ("tv",        "doukiOnTV",         "oth", lambda s: "A" if (s.stamina >= 50 or s.money < 1000) else "B"),
    ("renovation","theaterRenovation", "oth", lambda s: "A" if (s.money >= 50_000 and s.stamina >= 50) else "B"),
    ("classmate", "classmateInAudience","oth", lambda s: "A" if s.stamina >= 50 else "B"),
    ("fever",     "partnerFever",      "oth", lambda s: "A" if s.money >= 2000 else "B"),
    ("notebook",  "lostNotebook",      "oth", lambda s: "A" if (s.stamina >= 50 and s.money >= 1500) else "B"),
    ("yearend",   "yearEndLive",       "oth", lambda s: "A" if s.money >= 50_000 else ("B" if s.money >= 1500 else None)),
]

def event_effect_cases():
    out = []
    saved = C.EVENTS_APP
    C.EVENTS_APP = True
    try:
        for sn, init in EV_STATES.items():
            for key, kind, fn, side in _EV:
                s = B.S()
                for k, v in init.items(): setattr(s, k, v)
                s.money = int(s.money)
                sd = side(s)
                if sd is None: continue
                (C._app_apply if fn == "app" else C._others_apply)(s, key)
                out.append(dict(state=sn, init=init, key=key, kind=kind, side=sd,
                                post=dict(sense=float(s.sense), idea=float(s.idea), expr=float(s.expr), chara=float(s.chara),
                                          mental=float(s.mental), stamina=float(s.stamina), money=float(s.money),
                                          compat=float(s.compat), fame=float(s.fame)),
                                neta_boost=int(getattr(s, "_neta_boost", 0) or 0), preocc=int(getattr(s, "_preocc", 0) or 0)))
    finally:
        C.EVENTS_APP = saved
    return out

# ---------------------------------------------------------------------------------------------
# 体調ダウン（乱数の抽選）×喉のケア用品×特技「体が資本」（10/19・docs/golden_injury_1019_v0.md）：gen_golden.run_year（乱数込みの1年・
# 大会/GP/オファー/誘い込み）を、体力を低く保つ台本で回し、週ごとの全状態と体調ダウン回数を記録する。
# 同じ乱数列でも「確率×0.5（用品）／×0.7（特技）」で抽選の当たり外れが変わる種を選んだ（用品なし3回→用品1回／特技2回／両方1回）。
# ---------------------------------------------------------------------------------------------
INJURY_PATTERN = [("train", "ネタ作り"), ("train", "ネタ合わせ"), ("train", "フリーライブ"), ("job", "キツい"), ("train", "ネタ見せ会"),
                  ("job", "キツい"), ("train", "ネタ作り"), ("job", "キツい"), ("rest", "完全休養")]
INJURY_SEEDS = [52, 54]

def injury_scripts():
    import gen_golden as G
    out = []
    saved = getattr(B, "YEAR_GROWTH_CAP", None)
    try:
        for seed in INJURY_SEEDS:
            for item, skill in ((False, False), (True, False), (False, True), (True, True)):
                s = B.S()
                if item: assert B.buy_item(s, "喉のケア用品")
                if skill: s.skills = {"体が資本"}
                log, tr = [], {}
                champ, stage = G.run_year(s, 1, G.SplitMix64(seed), log=log, trace=tr, pattern=INJURY_PATTERN)
                assert not champ and len(log) == 48
                out.append(dict(name=f"injury_seed{seed}_{'item' if item else 'noitem'}_{'skill' if skill else 'noskill'}",
                                seed=str(seed), item=item, skill=skill, injuries=tr.get("injuries", 0), stage=stage,
                                weeks=[[float(v) for v in snap] for (_, _, snap) in log]))
    finally:
        B.YEAR_GROWTH_CAP = saved
    return out

def ext_main():
    saved = (C.NETA_V2,)
    C.NETA_V2 = True
    try:
        return dict(neta_bonus=neta_bonus_cases(), neta_grow=neta_grow_scripts(), offers=offer_scripts(), event_effects=event_effect_cases(), injury=injury_scripts())
    finally:
        C.NETA_V2, = saved

def main():
    S = []
    # 1-3 部屋ごと×家で休む（完全休養・気分転換・相方と過ごす）
    for room in (0, 1, 2):
        ops = [{"op": "set", "v": {"stamina": 20.0, "mental": 10.0}}]
        for r in ("完全休養", "気分転換", "相方と過ごす"):
            ops += [{"op": "set", "v": {"stamina": 20.0}}, {"op": "rest", "name": r}]
        S.append(run(f"room{room}_home_rests", dict(room=room), ops))
    # 4 月末の支払い（部屋×やりくり上手）
    ops = []
    for sk in (False, True):
        if sk: ops.append({"op": "set", "v": {"exp_goi": 2.0, "exp_maai": 4.0}}); ops.append({"op": "learn", "skill": "やりくり上手"})
        ops += [{"op": "living_due"}] + [{"op": "week_end", "week": w} for w in (3, 4, 8)]
    S.append(run("living_room0_yarikuri", dict(room=0, money=1_000_000), ops))
    for room in (1, 2):
        ops = [{"op": "living_due"}, {"op": "week_end", "week": 4},
               {"op": "set", "v": {"exp_goi": 2.0, "exp_maai": 4.0}}, {"op": "learn", "skill": "やりくり上手"},
               {"op": "living_due"}, {"op": "week_end", "week": 8}]
        S.append(run(f"living_room{room}_yarikuri", dict(room=room, money=1_000_000), ops))
    # 6b 【候補 q9】家賃はその月に住んだ一番上の部屋の額（月末だけ安い部屋に戻す抜け道を塞ぐ）
    S.append(run("rent_peak_move_down", dict(room=2, money=1_000_000), [
        {"op": "move_room", "to": 0}, {"op": "living_due"}, {"op": "week_end", "week": 4},   # 月の途中で下げても上の部屋の額
        {"op": "living_due"}, {"op": "week_end", "week": 8}]))                               # 次の月は今の部屋の額
    S.append(run("rent_peak_up_then_down", dict(room=0, money=1_000_000), [
        {"op": "move_room", "to": 2}, {"op": "move_room", "to": 1}, {"op": "living_due"}, {"op": "week_end", "week": 4},
        {"op": "move_room", "to": 0}, {"op": "living_due"}, {"op": "week_end", "week": 8},
        {"op": "living_due"}, {"op": "week_end", "week": 12}]))
    S.append(run("rent_peak_cannot_afford", dict(room=0, money=149_000), [   # 上の部屋(15万)に届かず・生活費は払える
        {"op": "move_room", "to": 2}, {"op": "living_due"}, {"op": "week_end", "week": 4}]))  # 上げられない時は記録しない
    # 7 体が資本×喉のケア用品の体調ダウン確率の係数
    ops = []
    for st in (0.0, 20.0, 40.0, 49.0):
        ops += [{"op": "set", "v": {"stamina": st}}, {"op": "injury_prob"}]
    ops += [{"op": "set", "v": {"exp_tanryoku": 4.0, "exp_sonzaikan": 3.0, "money": 100000}}, {"op": "learn", "skill": "体が資本"}]
    for st in (0.0, 20.0, 40.0): ops += [{"op": "set", "v": {"stamina": st}}, {"op": "injury_prob"}]
    ops += [{"op": "buy", "item": "喉のケア用品"}]
    for st in (0.0, 20.0, 40.0): ops += [{"op": "set", "v": {"stamina": st}}, {"op": "injury_prob"}]
    ops += [{"op": "new_year"}, {"op": "set", "v": {"stamina": 20.0}}, {"op": "injury_prob"}]
    S.append(run("injury_mult_skill_throat", dict(), ops))
    # 8 愛され芸人の知名度の伸び（低・中・高の知名度、負の増分は不変）
    ops = []
    for f in (3.0, 30.0, 60.0):
        ops += [{"op": "set", "v": {"fame": f}}, {"op": "fame", "amt": 2.0}, {"op": "fame", "amt": -1.0}]
    S.append(run("fame_base", dict(), ops))
    ops = [{"op": "set", "v": {"exp_sonzaikan": 6.0}}, {"op": "learn", "skill": "愛され芸人"}]
    for f in (3.0, 30.0, 60.0):
        ops += [{"op": "set", "v": {"fame": f}}, {"op": "fame", "amt": 2.0}, {"op": "fame", "amt": -1.0}]
    S.append(run("fame_aisare", dict(), ops))
    # 9-10 相方思いのすれ違い（相性が上がらない週が続く・二人の週・相性が上がった週・年1の上限）
    for sk in (False, True):
        ops = []
        if sk: ops += [{"op": "set", "v": {"exp_sonzaikan": 3.0, "exp_maai": 4.0}}, {"op": "learn", "skill": "相方思い"}]
        for c in (5.0, 5.0, 10.0, 15.0, 20.0):
            ops.append({"op": "set", "v": {"compat": c}}); ops.append({"op": "rift", "year": 3, "compat0": c})
        ops += [{"op": "rift", "year": 3, "compat0": 5.0, "joint": True},
                {"op": "set", "v": {"compat": 8.0}}, {"op": "rift", "year": 3, "compat0": 5.0},
                {"op": "set", "v": {"compat": 5.0}}] + [{"op": "rift", "year": 1, "compat0": 5.0}] * 3 + [{"op": "rift", "year": 3, "compat0": 5.0}] * 3
        S.append(run("rift_" + ("aitaomoi" if sk else "base"), dict(rift=60.0, compat=5.0), ops))
    # 11 栄養ドリンク・回復ドリンク大（購入後の体力・回数・上限・年明けリセット）
    ops = [{"op": "set", "v": {"stamina": 10.0}}]
    ops += [{"op": "buy", "item": "栄養ドリンク"}] * 7 + [{"op": "buy", "item": "回復ドリンク大"}] * 5
    ops += [{"op": "new_year"}, {"op": "buy", "item": "栄養ドリンク"}, {"op": "buy", "item": "回復ドリンク大"}]
    S.append(run("items_drinks", dict(money=500_000), ops))
    # 12 銭湯の回数券（4回の休みに +10・使い切るまで再購入不可・部屋との重ね掛け）
    for room in (0, 2):
        ops = [{"op": "buy", "item": "銭湯の回数券"}, {"op": "buy", "item": "銭湯の回数券"}]
        for i in range(5): ops += [{"op": "set", "v": {"stamina": 20.0}}, {"op": "rest", "name": ["完全休養", "気分転換", "相方と過ごす"][i % 3]}]
        ops += [{"op": "buy", "item": "銭湯の回数券"}]
        S.append(run(f"items_sento_room{room}", dict(money=100_000, room=room), ops))
    # 14 新幹線回数券・喉のケア・中古IC(売らない)・お金不足・年明けリセット
    ops = [{"op": "buy", "item": "新幹線回数券"}, {"op": "buy", "item": "新幹線回数券"},
           {"op": "buy", "item": "喉のケア用品"}, {"op": "buy", "item": "喉のケア用品"},
           {"op": "buy", "item": "中古のICレコーダー"}, {"op": "buy", "item": "ネタ作家の勉強会"},
           {"op": "new_year"}, {"op": "buy", "item": "新幹線回数券"}, {"op": "buy", "item": "喉のケア用品"}]
    S.append(run("items_shinkansen_throat", dict(money=700_000), ops))
    ops = [{"op": "buy", "item": "栄養ドリンク"}, {"op": "buy", "item": "新幹線回数券"}]
    S.append(run("items_no_money", dict(money=2_999), ops))
    # 16 特技を覚える（費用・不足・重複）
    ops = [{"op": "learn", "skill": "愛され芸人"},
           {"op": "set", "v": {"exp_tanryoku": 5.0, "exp_sonzaikan": 10.0, "exp_goi": 2.0, "exp_maai": 8.0}}]
    for k in ("体が資本", "愛され芸人", "やりくり上手", "相方思い", "体が資本", "相方思い"):
        ops.append({"op": "learn", "skill": k})
    S.append(run("skills_learn", dict(), ops))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    ext = ext_main()
    OUT.write_text(json.dumps(dict(version=2, scripts=S, ext=ext), ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {OUT} ({len(S)} scripts, {sum(len(x['steps']) for x in S)} steps; ext: {len(ext['neta_bonus'])} neta cases, {len(ext['neta_grow'])} grow, {len(ext['offers']['extra'])} extra, {len(ext['offers']['fatigue'])} fatigue, {len(ext['event_effects'])} event effects)")

if __name__ == "__main__":
    main()
