#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: ネタ資産システム（docs/neta_system_design_v0.md §6 の検証計画A/B/C）
- ボットのネタ運用は「2本を作って磨き、大会は補正最大のネタを選ぶ」最小戦略（実プレイヤーの下位近似）
- 計測A: ネタ補正ありなしで初回分布がどう動くか（目標: 優勝率1〜2%帯・決勝25〜35%帯の維持）
- 計測B: 決勝2本制ペナルティ(-3)の効き（目標: 決勝到達は維持したまま決勝突破だけ絞る）
- 計測C: ネタ選択をランダム化した差（=プレイヤースキルの寄与幅。±5クランプの妥当性）
- 使い方: python3 exp_neta.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import statistics
import sys

import sim_career as C

CONFIGS = [
    ("基準（ネタ層なし・正典）",       dict()),
    ("A ネタ層ON（賢い選択）",         dict(NETA_ON=True)),
    ("B ネタ層ON・2本制ペナルティなし", dict(NETA_ON=True, NETA_SECOND_PEN=0.0)),
    ("C ネタ層ON・ランダム選択",       dict(NETA_ON=True, NETA_RANDOM_PICK=True)),
]
FLAGS = ("NETA_ON", "NETA_RANDOM_PICK", "NETA_SECOND_PEN")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    print(f"=== ネタ資産システムの検証 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"イベント込み正典(決勝{C.GP_FINAL_LINE:.0f}) | 全て【仮】 ===")
    print("見方: 決勝突破率=優勝キャリア÷決勝経験キャリア。Bとの差が「2本目がなかった」敗因の量")
    print()
    saved = {k: getattr(C, k) for k in FLAGS}
    saved_on = C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        for label, flags in CONFIGS:
            for k in FLAGS:
                setattr(C, k, flags.get(k, saved[k] if k == "NETA_SECOND_PEN" else False))
            if "NETA_SECOND_PEN" in flags:
                C.NETA_SECOND_PEN = flags["NETA_SECOND_PEN"]
            print(f"== {label} ==")
            for cls in C.BOTS:
                pol = cls()
                wins, finals, win_years = 0, 0, []
                for i in range(n):
                    first, _s, _stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
                    if first is not None:
                        wins += 1
                        win_years.append(first)
                    finals += ever_final
                med = statistics.median(win_years) if win_years else None
                brk = f"{100.0*wins/finals:4.1f}%" if finals else "  - "
                print(f"  {pol.name:　<7}| 優勝 {100.0*wins/n:5.2f}% / 決勝到達 {100.0*finals/n:5.1f}% / "
                      f"決勝突破率 {brk} / 初優勝中央値 {med}年")
            print()
    finally:
        C.EVENTS_ON = saved_on
        for k, v in saved.items():
            setattr(C, k, v)

if __name__ == "__main__":
    main()
