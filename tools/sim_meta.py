#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
メタ周回シミュレータ v0（docs/meta_report_v0.md の根拠データ）
- 「キャリア→トロフィーpt獲得→才能限界D上昇→人脈Pで相方ティア解放→次周」の周回ループ全体を通しで回す
- 検証したい3点:
  (1) トロフィー取得カーブ（trophy_design_v1.md の想定: 初回8〜11pt）と初優勝・殿堂入りが何周目に来るか
  (2) GP挑戦資格「結成15年以内」【仮】の影響（王座陥落後の返り咲き期限）
  (3) 事務所モディファイアのEV中立性（agency_fanbase_design_v0.md §4-1）
- 人脈Pの獲得式・ティア解放閾値は本ファイルが初出の【仮】設計。結果を見て調整する
- 使い方: python3 sim_meta.py [フランチャイズ数]   （省略時 400）
"""

import copy
import random
import statistics
import sys

import balance_sim as B
import sim_career as C

RUNS          = 12    # 追う周回数
GP_YEAR_LIMIT = 15    # 【仮】挑戦者としてのGP出場は結成15年以内（実在準拠）。王者防衛は対象外
STEP          = 5     # 王者ライン = 決勝ライン + STEP×連覇数（dynasty_design_v0.md）
MAX_YEARS     = 25
TROPHY_CAP    = 30    # 才能ポイント総枠（trophy_design_v1.md）

# 相方ティア: (名前, 相性初期値, 相性上限)
TIERS = [("N", 5.0, 20.0), ("R", 10.0, 22.0), ("SR", 15.0, 25.0), ("SSR", 20.0, 30.0)]
TIER_THRESHOLDS = [0, 60, 140, 260]   # 旧・閾値解放モデル（GACHA_MODE=Falseで再現用に残置）

# 【v0.2】B案確定に伴う名鑑所有モデル（monetization_decision_v0.md §7）
# 周回の合間に日次無料＋人脈Pチケットでガチャを引き、所有した最高ティアの相方で次周に臨む
GACHA_MODE   = True
DAYS_PER_RUN = 7      # 【仮】1周に費やす実日数（ミドル層想定。日次無料=この回数/周）
TICKET_COST  = 50     # 人脈P→ガチャ1回【仮】
GACHA_RATES  = [("N", 0.605), ("R", 0.30), ("SR", 0.08), ("SSR", 0.015)]
GACHA_CATALOG = {"N": 6, "R": 5, "SR": 3, "SSR": 2}
DUPE_P       = {"N": 5, "R": 10, "SR": 20, "SSR": 40}
TIER_OF      = {"N": 0, "R": 1, "SR": 2, "SSR": 3}

def gacha_draw(rng, owned):
    """1回引く（気になるリスト=未所持の最高レア先頭を指名・同レア内重み2倍）。sim_gacha.pyと同型"""
    r = rng.random()
    acc = 0.0
    for rarity, rate in GACHA_RATES:
        acc += rate
        if r < acc:
            break
    chars = [f"{rarity}{i}" for i in range(GACHA_CATALOG[rarity])]
    target = None
    for tr, _ in reversed(GACHA_RATES):
        missing = [f"{tr}{i}" for i in range(GACHA_CATALOG[tr]) if f"{tr}{i}" not in owned]
        if missing:
            target = missing[0]
            break
    weights = [2.0 if c == target else 1.0 for c in chars]
    x = rng.random() * sum(weights)
    for c, w in zip(chars, weights):
        x -= w
        if x <= 0:
            return rarity, c
    return rarity, chars[-1]
DYNASTY_GATE_PT = 18                  # 王者編（優勝後の続行）の解禁に必要な累計pt【仮】。未解禁は初優勝で勇退

def jinmyaku_gain(best_stage, reached_final, titles, fame):
    """1キャリアで得る人脈P【仮v0.1】: 完走8 + 準決15 + 決勝20 + 優勝15×回数 + 知名度/20"""
    return 8 + (15 if best_stage >= 4 else 0) + (20 if reached_final else 0) + 15 * titles + int(fame) // 20

TOURNAMENT_TROPHY = {
    "春新人賞A": "春一番", "春新人賞B": "結成組の意地", "夏中堅賞": "真夏の頂",
    "大阪戎コンクール": "戎の福", "若手限定賞": "五年目の全力", "推薦制中堅賞": "選ばれる側へ",
}

def run_meta_career(pol, seed, D, tier, allow_dynasty=True):
    """1キャリア。allow_dynasty=False なら初優勝で勇退（王者編未解禁）"""
    _, start, cap = tier
    B.GROWTH_DECAY_D = D
    B.COMPAT_CAP = cap
    rng = random.Random(seed)
    s = C.new_state(compat=start)
    C.RUN_TRACK = track = {}
    streak = titles = max_streak = comebacks = dry = 0
    first, reached_final, best_stage, years = None, False, 0, 0
    for year in range(1, MAX_YEARS + 1):
        years = year
        defending = streak > 0
        if defending:
            won, stage, fin = C.run_year(pol, s, year, rng, seed_final=True,
                                         final_line=C.GP_FINAL_LINE + STEP * streak)
        elif year <= GP_YEAR_LIMIT:
            won, stage, fin = C.run_year(pol, s, year, rng)
        else:
            break                          # 挑戦資格切れ・無冠（元王者含む）は勇退【仮】
        best_stage = max(best_stage, stage)
        reached_final = reached_final or fin
        if won:
            if titles > 0 and streak == 0:
                comebacks += 1
            titles += 1
            streak += 1
            max_streak = max(max_streak, streak)
            if first is None:
                first = year
            dry = 0
            if not allow_dynasty:
                break                      # 王者編未解禁: 初優勝で勇退
        else:
            streak = 0
            if titles > 0:
                dry += 1
                if dry >= 3:
                    break                  # 王者経験後、無冠3年で勇退
            elif year >= C.YEARS:
                break                      # 無冠10年で完走（勇退）
    C.RUN_TRACK = None
    return dict(track=track, state=s, titles=titles, first=first, max_streak=max_streak,
                comebacks=comebacks, reached_final=reached_final, best_stage=best_stage, years=years)

def eval_trophies(res, meta):
    """トロフィーv1.1配分（trophy_design_v1.md v1.1改訂と同期・総枠30pt）。#雨天決行1ptはイベント未実装でシミュ対象外"""
    t = set()
    bs, tr, s = res["best_stage"], res["track"], res["state"]
    if bs >= 1:
        t.add(("初舞台の足音", 1))
    if bs >= 4:
        t.add(("準決勝の空気", 1))
    for tournament, trophy in TOURNAMENT_TROPHY.items():
        if tournament in tr.get("wins", set()):
            t.add((trophy, 1))
    if meta["bus_total"] >= 10:
        t.add(("夜行バスの常連", 1))
    if meta["train_total"] >= 100:
        t.add(("稽古の虫", 1))
    if s.compat >= B.COMPAT_CAP:
        t.add(("阿吽の呼吸", 1))
    if tr.get("sub30_pass"):
        t.add(("満身創痍のセンターマイク", 1))
    if tr.get("subzero_pass"):
        t.add(("どん底からの声援", 1))
    if res["reached_final"]:
        t.add(("決勝の照明", 1))
    if res["titles"] == 0 and res["years"] >= C.YEARS:
        t.add(("十年選手", 1))
    if res["comebacks"] > 0:
        t.add(("玉座奪還", 3))
    if tr.get("revival_pass"):
        t.add(("敗者復活の奇跡", 3))
    if tr.get("grand_slam"):
        t.add(("六冠の年", 3))
    if res["max_streak"] >= 5:
        t.add(("五連覇", 3))
    if res["titles"] >= 5:
        t.add(("通算五冠", 2))
    return t

def run_franchise(pol_cls, fseed):
    """1プレイヤーのRUNS周ぶん"""
    pol = pol_cls()
    earned = {}
    meta = dict(bus_total=0, train_total=0, jinmyaku=0)
    owned = {"N0"}   # 初期相方（谷口）は所持済み
    grng = random.Random(fseed * 77 + 1)
    log = []
    for run in range(1, RUNS + 1):
        pts = min(TROPHY_CAP, sum(earned.values()))
        if GACHA_MODE:
            # 周回の合間: 日次無料(DAYS_PER_RUN回)＋人脈Pチケットを引き、名鑑を更新
            pulls = DAYS_PER_RUN + int(meta["jinmyaku"] // TICKET_COST)
            meta["jinmyaku"] -= int(meta["jinmyaku"] // TICKET_COST) * TICKET_COST
            for _ in range(pulls):
                rarity, c = gacha_draw(grng, owned)
                if c in owned:
                    meta["jinmyaku"] += DUPE_P[rarity]
                else:
                    owned.add(c)
            tier_idx = max(TIER_OF[c[:-1]] for c in owned)
        else:
            tier_idx = max(i for i, th in enumerate(TIER_THRESHOLDS) if meta["jinmyaku"] >= th)
        res = run_meta_career(pol, fseed * 1000 + run, 120 + pts, TIERS[tier_idx],
                              allow_dynasty=(pts >= DYNASTY_GATE_PT))
        meta["bus_total"] += res["track"].get("bus", 0)
        meta["train_total"] += res["track"].get("trains", 0)
        for name, pt in eval_trophies(res, meta):
            earned.setdefault(name, pt)
        meta["jinmyaku"] += jinmyaku_gain(res["best_stage"], res["reached_final"],
                                          res["titles"], res["state"].fame)
        log.append(dict(run=run, pts=pts, tier=TIERS[tier_idx][0], titles=res["titles"],
                        first=res["first"], hall=res["max_streak"] >= 10))
    return log, earned

def meta_section(n):
    print(f"== メタ周回（{RUNS}周×{n}フランチャイズ・GP挑戦資格{GP_YEAR_LIMIT}年・王者STEP={STEP}） ==")
    saved = dict(GROWTH_DECAY_D=B.GROWTH_DECAY_D, COMPAT_CAP=B.COMPAT_CAP)
    try:
        for cls in C.BOTS:
            logs, earneds = [], []
            for f in range(n):
                log, earned = run_franchise(cls, C.BASE_SEED + f)
                logs.append(log)
                earneds.append(earned)
            print(f"[{cls().name}]")
            for k in range(RUNS):
                pts = statistics.median(log[k]["pts"] for log in logs)
                tiers = [log[k]["tier"] for log in logs]
                ssr = 100.0 * tiers.count("SSR") / n
                won_by = 100.0 * sum(1 for log in logs if any(r["titles"] > 0 for r in log[:k + 1])) / n
                hall_by = 100.0 * sum(1 for log in logs if any(r["hall"] for r in log[:k + 1])) / n
                print(f"  {k + 1:2d}周目開始: pt中央値 {pts:4.1f} / SSR率 {ssr:5.1f}% / "
                      f"初優勝済み {won_by:5.1f}% / 殿堂済み {hall_by:5.1f}%")
            counts = {}
            for e in earneds:
                for name in e:
                    counts[name] = counts.get(name, 0) + 1
            rare = sorted(counts.items(), key=lambda x: x[1])[:5]
            print("  12周後の未取得が多い順:", " / ".join(f"{nm} {100.0 * c / n:.0f}%" for nm, c in rare))
    finally:
        for k, v in saved.items():
            setattr(B, k, v)

# --- 事務所EV検証（初回キャリア・2000回） ---

AGENCIES = {
    # v0の実測で「稽古効果+1」(優勝率26.75%)と「オファー率半減」(9.8%)がEV破壊と判明。
    # 第2案: 効果は金額系(取り分・費用)中心に限定し、オファー率は±15%以内、稽古効果は不可侵とする
    "南々プロ(基準)":   {},
    "大鳥興業":         dict(income_mult=0.6, butai_cost=40_000, eigyo_fame=2),
    "柊屋芸能社":       dict(income_mult=1.2, travel_free=True),
    "気楽舎":           dict(income_mult=1.2, rate_mult=0.90),
    "太陽プロ":         dict(income_mult=1.1, rate_mult=1.05),
    "白虎堂":           dict(rate_mult=0.90, butai_stam=-20),
    "果林カンパニー":   dict(income_mult=1.3),
    "フリー":           dict(income_mult=2.0, rate_mult=0.75, butai_cost=100_000),
}

def agency_section(n):
    print(f"== 事務所EV中立性（初回キャリア×{n}・バランス型） ==")
    orig = dict(OFFER_MONEY=dict(B.OFFER_MONEY), OFFER_EXP=dict(B.OFFER_EXP),
                OFFER_RATES=list(B.OFFER_RATES), TRAININGS=copy.deepcopy(B.TRAININGS),
                BUS=dict(B.BUS), TRAIN=dict(B.TRAIN))
    try:
        for name, mod in AGENCIES.items():
            B.OFFER_MONEY = dict(orig["OFFER_MONEY"])
            B.OFFER_EXP = dict(orig["OFFER_EXP"])
            B.OFFER_RATES = list(orig["OFFER_RATES"])
            B.TRAININGS = copy.deepcopy(orig["TRAININGS"])
            B.BUS = dict(orig["BUS"])
            B.TRAIN = dict(orig["TRAIN"])
            if "income_mult" in mod:
                B.OFFER_MONEY["income"] = int(B.OFFER_MONEY["income"] * mod["income_mult"])
                B.OFFER_EXP["income"] = int(B.OFFER_EXP["income"] * mod["income_mult"])
            if "rate_mult" in mod:
                B.OFFER_RATES = [(cap, r * mod["rate_mult"]) for cap, r in B.OFFER_RATES]
            if "butai_cost" in mod:
                B.TRAININGS["ネタ見せ会"]["cost"] = mod["butai_cost"]
            if "butai_stam" in mod:
                B.TRAININGS["ネタ見せ会"]["stam"] = mod["butai_stam"]
            if "eigyo_fame" in mod:
                B.TRAININGS["フリーライブ"]["fame"] = mod["eigyo_fame"]
            if "train_bonus" in mod:
                for t in B.TRAININGS.values():
                    k, v = t["main"]
                    t["main"] = (k, v + mod["train_bonus"])
            if mod.get("travel_free"):
                B.BUS["cost"] = 0
                B.TRAIN["cost"] = 0
            r = C.run_config(C.CareerBalanced, n)
            print(f"  {name:　<9}| 優勝率 {100.0 - r['none_rate']:4.2f}% / 決勝到達 {r['final_rate']:5.1f}% / "
                  f"最終所持金 {B.yen(r['final_money']):>9}")
    finally:
        B.OFFER_MONEY = orig["OFFER_MONEY"]
        B.OFFER_EXP = orig["OFFER_EXP"]
        B.OFFER_RATES = orig["OFFER_RATES"]
        B.TRAININGS = orig["TRAININGS"]
        B.BUS = orig["BUS"]
        B.TRAIN = orig["TRAIN"]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    print(f"=== メタ周回検証 v0 | シード{C.BASE_SEED} | 数値は全て【仮】 ===")
    print()
    meta_section(n)
    print()
    agency_section(2000)

if __name__ == "__main__":
    main()
