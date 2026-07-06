#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 王者編（連覇モード）の飽きられ係数の探索（docs/dynasty_design_v0.md の根拠データ）
- 仕様案: 初優勝で勇退せず「王者編」へ。王者は予選免除（決勝シード）だが、
  王者ライン = 決勝95 + STEP×現連覇数【仮】が年々上がる（客と審査の期待インフレ=飽きられ）
- 防衛失敗で連覇リセット→翌年は1回戦から（返り咲き挑戦）。初優勝後、無冠が3年続くと勇退
- 採用値: STEP=5・トロフィー総枠30pt(D最大150)。詳細は docs/dynasty_design_v0.md §2 / trophy_design_v1.md
  （当初のSTEP=6はN相方の10連覇を数学的に不可能にするため緩和した）
- 使い方: python3 exp_renpa.py [キャリア数/設定]   （省略時 1000）
- 数値は全て【仮】
"""

import random
import statistics
import sys

import balance_sim as B
import sim_career as C

MAX_YEARS    = 25   # 王者編込みの最長キャリア【仮】
RETIRE_AFTER = 3    # 初優勝後、無冠がこの年数続いたら勇退【仮】
STEPS = (4, 5, 6, 8)

TIERS = [
    ("SSR相方(20→30)", dict(COMPAT_CAP=30), dict(compat_start=20, init_ability=20)),
    ("N相方 (5→20)",   dict(COMPAT_CAP=20), dict(compat_start=5,  init_ability=20)),
]

def run_dynasty(pol, seed, step, kwargs, heritage=0):
    """heritage: 挑戦年（無冠時）の決勝ライン += heritage×通算優勝数【仮】=「元王者への期待と飽き」"""
    rng = random.Random(seed)
    s = C.new_state(kwargs.get("init_ability"), kwargs.get("compat_start"))
    streak = titles = max_streak = comebacks = dry = 0
    first = None
    for year in range(1, MAX_YEARS + 1):
        defending = streak > 0
        if defending:
            line = C.GP_FINAL_LINE + step * streak
        elif titles:
            line = C.GP_FINAL_LINE + heritage * titles
        else:
            line = None
        won, _, _ = C.run_year(pol, s, year, rng, seed_final=defending, final_line=line)
        if won:
            if titles > 0 and streak == 0:
                comebacks += 1
            titles += 1
            streak += 1
            max_streak = max(max_streak, streak)
            if first is None:
                first = year
            dry = 0
        else:
            streak = 0
            if titles > 0:
                dry += 1
                if dry >= RETIRE_AFTER:
                    break
    return dict(first=first, titles=titles, max_streak=max_streak,
                comebacks=comebacks, money=s.money)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    print(f"=== 王者編（連覇）検証 | 最長{MAX_YEARS}年 無冠{RETIRE_AFTER}年で勇退 | "
          f"トロフィー全解放想定 D=140 | {n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
    print("目標: SSRで10連覇が現実的(数%〜数十%) / Nで10連覇ほぼ0% / 返り咲きがドラマとして発生")
    print()
    saved = dict(GROWTH_DECAY_D=B.GROWTH_DECAY_D, COMPAT_CAP=B.COMPAT_CAP)
    try:
        B.GROWTH_DECAY_D = 140
        for step in STEPS:
            lines = " / ".join(f"{C.GP_FINAL_LINE + step * k:.0f}" for k in range(1, 10))
            print(f"== 飽きられSTEP={step}（防衛k回目のライン: {lines}） ==")
            for tier_name, overrides, kwargs in TIERS:
                for k, v in overrides.items():
                    setattr(B, k, v)
                for cls in C.BOTS:
                    pol = cls()
                    outs = [run_dynasty(pol, C.BASE_SEED + i, step, kwargs) for i in range(n)]
                    won_outs = [o for o in outs if o["first"] is not None]
                    pct10 = 100.0 * sum(1 for o in outs if o["max_streak"] >= 10) / n
                    med_streak = statistics.median(o["max_streak"] for o in outs)
                    med_titles = statistics.median(o["titles"] for o in outs)
                    cb = 100.0 * sum(1 for o in outs if o["comebacks"] > 0) / n
                    money = statistics.median(o["money"] for o in outs)
                    first = statistics.median(o["first"] for o in won_outs) if won_outs else None
                    print(f"  {tier_name} {pol.name:　<7}| 10連覇 {pct10:5.1f}% / 最高連覇中央値 {med_streak:4.1f} / "
                          f"通算優勝 {med_titles:4.1f} / 返り咲き経験 {cb:5.1f}% / "
                          f"初優勝 {first}年 / 最終所持金 {B.yen(money)}")
                for k, v in saved.items():
                    if k != "GROWTH_DECAY_D":
                        setattr(B, k, v)
            print()
        print(f"== 返り咲き難度スキャン（STEP=6固定・挑戦年の決勝ライン={C.GP_FINAL_LINE:.0f}+H×通算優勝数） ==")
        for heritage in (0, 2, 4):
            print(f"[H={heritage}]")
            for tier_name, overrides, kwargs in TIERS:
                for k, v in overrides.items():
                    setattr(B, k, v)
                for cls in C.BOTS:
                    pol = cls()
                    outs = [run_dynasty(pol, C.BASE_SEED + i, 6, kwargs, heritage=heritage) for i in range(n)]
                    pct10 = 100.0 * sum(1 for o in outs if o["max_streak"] >= 10) / n
                    med_streak = statistics.median(o["max_streak"] for o in outs)
                    med_titles = statistics.median(o["titles"] for o in outs)
                    cb = 100.0 * sum(1 for o in outs if o["comebacks"] > 0) / n
                    print(f"  {tier_name} {pol.name:　<7}| 10連覇 {pct10:5.1f}% / 最高連覇中央値 {med_streak:4.1f} / "
                          f"通算優勝 {med_titles:4.1f} / 返り咲き経験 {cb:5.1f}%")
                for k, v in saved.items():
                    if k != "GROWTH_DECAY_D":
                        setattr(B, k, v)
    finally:
        for k, v in saved.items():
            setattr(B, k, v)

if __name__ == "__main__":
    main()
