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
                s.money -= B.living_cost(s) + B.room_rent(s)
        elif o == "living_due": val = float(B.living_cost(s) + B.room_rent(s))
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
    OUT.write_text(json.dumps(dict(version=1, scripts=S), ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {OUT} ({len(S)} scripts, {sum(len(x['steps']) for x in S)} steps)")

if __name__ == "__main__":
    main()
