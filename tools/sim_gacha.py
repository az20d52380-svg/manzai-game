#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ガチャ経済シミュレータ v0（docs/gacha_report_v0.md の根拠データ）
- B案確定（monetization_decision_v0.md §7）を受け、無料プレイヤーの名鑑コンプ速度を実測する
- モデル: 1日1回無料 + ミッション + 人脈Pチケット（キャリア成果・ダブり変換の還流込み）
- 気になるリスト（指名の同レア内2倍）を「未所持の最高レアを常に指名」の最適運用で回す
- 検証目標: ミドル層（月3周ペース）で全16体コンプが3〜5ヶ月（monetization §7 の設計目標）
- 使い方: python3 sim_gacha.py [試行数]   （省略時 2000）
- 数値は全て【仮】
"""

import random
import statistics
import sys

# --- カタログとレート【仮】（monetization_decision_v0.md §7） ---
CATALOG = {"N": 6, "R": 5, "SR": 3, "SSR": 2}          # ローンチ16体
RATES = [("N", 0.60), ("R", 0.30), ("SR", 0.08), ("SSR", 0.02)]
DUPE_P = {"N": 5, "R": 10, "SR": 20, "SSR": 40}         # ダブり→人脈P変換【仮】
TICKET_COST = 50                                         # 人脈P→ガチャ1回【仮】
PULLS_DAILY_MONTH = 30                                   # 1日1回無料
PULLS_MISSION_MONTH = 5                                  # 月間ミッション【仮】
P_PER_CAREER = 35                                        # 1周あたりの人脈P獲得中央値（メタ実測の初回帯）【仮】

PROFILES = {"ライト(1周/月)": 1, "ミドル(3周/月)": 3, "ヘビー(7周/月)": 7}
MAX_MONTHS = 60

def draw(rng, owned):
    """1回引く。気になるリスト＝未所持の最高レア1体を指名（同レア内で重み2倍）"""
    r = rng.random()
    acc = 0.0
    for rarity, rate in RATES:
        acc += rate
        if r < acc:
            break
    chars = [f"{rarity}{i}" for i in range(CATALOG[rarity])]
    # 指名: 未所持の最高レアの先頭1体（このレアが出た時だけ効く）
    target = None
    for tr, _ in reversed(RATES):
        missing = [f"{tr}{i}" for i in range(CATALOG[tr]) if f"{tr}{i}" not in owned]
        if missing:
            target = missing[0]
            break
    weights = [2.0 if c == target else 1.0 for c in chars]
    total = sum(weights)
    x = rng.random() * total
    for c, w in zip(chars, weights):
        x -= w
        if x <= 0:
            return rarity, c
    return rarity, chars[-1]

def trial(rng, careers_per_month):
    owned = set()
    p_bank = 0.0
    got_ssr_all = got_all = None
    total_chars = sum(CATALOG.values())
    for month in range(1, MAX_MONTHS + 1):
        p_bank += careers_per_month * P_PER_CAREER
        pulls = PULLS_DAILY_MONTH + PULLS_MISSION_MONTH + int(p_bank // TICKET_COST)
        p_bank -= int(p_bank // TICKET_COST) * TICKET_COST
        for _ in range(pulls):
            rarity, c = draw(rng, owned)
            if c in owned:
                p_bank += DUPE_P[rarity]
            else:
                owned.add(c)
        if got_ssr_all is None and all(f"SSR{i}" in owned for i in range(CATALOG["SSR"])):
            got_ssr_all = month
        if got_all is None and len(owned) == total_chars:
            got_all = month
            break
    return got_ssr_all or MAX_MONTHS + 1, got_all or MAX_MONTHS + 1

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    print(f"=== ガチャ経済検証 v0 | 名鑑16体(N6/R5/SR3/SSR2) SSR率2% | 日次30+ミッション5+人脈Pチケット/月 | "
          f"{n}試行 | 全て【仮】 ===")
    print("目標: ミドル層で全16体コンプ3〜5ヶ月（『めちゃくちゃやれば無料で全部』の成立速度）")
    for name, cpm in PROFILES.items():
        rng = random.Random(20260704)
        results = [trial(rng, cpm) for _ in range(n)]
        ssr = statistics.median(r[0] for r in results)
        comp = statistics.median(r[1] for r in results)
        comp90 = sorted(r[1] for r in results)[int(n * 0.9)]
        print(f"  {name:　<10}| SSR2体そろう中央値 {ssr:4.1f}ヶ月 / 全16体コンプ中央値 {comp:4.1f}ヶ月 "
              f"(下振れ90%タイル {comp90:.0f}ヶ月)")

if __name__ == "__main__":
    main()
