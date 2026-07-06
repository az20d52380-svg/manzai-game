#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 挑戦者側の「飽きられ」機構（docs/dynasty_design_v0.md §3 の実装前検証）
- 3機構を個別／複合でONにし、イベント込み正典の初回分布（優勝1.4〜1.7%・決勝25〜35%）が壊れないかを測る
  A 客層二層化: 準決まで=コア客(センス・発想×1.1) / 決勝・敗者復活=お茶の間(表現・華×1.1)、重み再正規化
  B 飽きられデバフ: 同一回戦3年連続敗退→その回戦の実効ライン+3（通過で解除）
  C 波乱の年: 毎年1/6でその年のGP全ライン±3
- 使い方: python3 exp_challenger.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import statistics
import sys

import sim_career as C

CONFIGS = [
    ("基準（機構なし・正典）",  dict()),
    ("A 客層二層化",            dict(AUDIENCE_SPLIT=True)),
    ("B 飽きられデバフ",        dict(BOREDOM_ON=True)),
    ("C 波乱の年",              dict(UPSET_ON=True)),
    ("A+B+C 複合",              dict(AUDIENCE_SPLIT=True, BOREDOM_ON=True, UPSET_ON=True)),
]
FLAGS = ("AUDIENCE_SPLIT", "BOREDOM_ON", "UPSET_ON")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    print(f"=== 挑戦者「飽きられ」機構の検証 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"イベント込み正典(決勝{C.GP_FINAL_LINE:.0f}) | 全て【仮】 ===")
    print("判定: 各機構ON後も優勝1〜2%帯・決勝到達25〜35%帯を維持できるか（dynasty §3の【設計上の懸念】）")
    print()
    saved = {k: getattr(C, k) for k in FLAGS}
    saved_on = C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        for label, flags in CONFIGS:
            for k in FLAGS:
                setattr(C, k, flags.get(k, False))
            print(f"== {label} ==")
            for cls in C.BOTS:
                pol = cls()
                wins, finals, win_years, bored = 0, 0, [], 0
                for i in range(n):
                    b0 = C.CHALLENGER_STATS["boredom_applied"]
                    first, _s, _stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
                    if first is not None:
                        wins += 1
                        win_years.append(first)
                    finals += ever_final
                    bored += C.CHALLENGER_STATS["boredom_applied"] > b0
                med = statistics.median(win_years) if win_years else None
                extra = f" / 飽きられ経験 {100.0*bored/n:4.1f}%" if flags.get("BOREDOM_ON") else ""
                print(f"  {pol.name:　<7}| 優勝 {100.0*wins/n:5.2f}% / 決勝到達 {100.0*finals/n:5.1f}% / "
                      f"初優勝中央値 {med}年{extra}")
            print()
    finally:
        C.EVENTS_ON = saved_on
        for k, v in saved.items():
            setattr(C, k, v)

if __name__ == "__main__":
    main()
