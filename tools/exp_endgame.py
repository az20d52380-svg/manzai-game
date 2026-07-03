#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 能力上限120化に伴うグランプリ通過ラインの再設計（docs/endgame_design_v0.md の根拠データ）
- 目的: 「初プレイ（メタボーナスなし）は10年で優勝なしが基本、ただし決勝の舞台には手が届く」
        「トロフィー・相方ガチャを積んだ周回では優勝が現実的になる」を同時に満たすライン集合を探す
- 前提: balance_sim v0.2（成長逓減D=120・能力上限120 組み込み済み）
- ラインセット × メタ進行シナリオ × 2ボット の全組み合わせを走査
- 使い方: python3 exp_endgame.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import sys

import balance_sim as B
import sim_career as C

# (1回戦, 2回戦, 3回戦, 準々, 準決, 敗者復活, 決勝)
LINE_SETS = {
    "A 現行(85)":  (30, 45, 55, 65, 75, 80, 85),
    "B 中辛(95)":  (30, 45, 60, 72, 85, 92, 95),
    "C 辛口(100)": (30, 50, 62, 75, 90, 97, 100),
    "D 激辛(105)": (35, 50, 65, 78, 95, 102, 105),
    "E 極辛(110)": (35, 55, 70, 82, 100, 108, 110),
}

# メタ進行シナリオ（未設計システムの近似。init_ability=トロフィー周回ボーナス、compat_fixed=相方ガチャ）
SCENARIOS = [
    ("S0 初回(素)",                dict()),
    ("S1 トロフィー+10",           dict(init_ability=20)),
    ("S2 当たり相方(相性20固定)",  dict(compat_fixed=20)),
    ("S3 フル強化(能力25/相性25)", dict(init_ability=25, compat_fixed=25)),
]

_ORIG = (C.GP_ROUNDS, C.GP_REVIVAL_LINE, C.GP_FINAL_LINE)

def apply_lines(lines):
    r1, r2, r3, qf, sf, rev, fin = lines
    C.GP_ROUNDS = [
        (30, r1, "GP1回戦"),
        (39, r2, "GP2回戦"),
        (41, r3, "GP3回戦"),
        (43, qf, "GP準々決勝"),
        (45, sf, "GP準決勝"),
    ]
    C.GP_REVIVAL_LINE = rev
    C.GP_FINAL_LINE = fin

def restore_lines():
    C.GP_ROUNDS, C.GP_REVIVAL_LINE, C.GP_FINAL_LINE = _ORIG

def show(r):
    n = r["n"]
    med = f"{r['median']:.0f}年" if r["median"] <= C.YEARS else "なし"
    y1 = 100.0 * r["dist"][0] / n
    print(f"    {r['name']:　<8}| 中央値 {med:>4} / 優勝なし {r['none_rate']:5.1f}% / "
          f"1年目 {y1:4.2f}% / 準決到達 {r['semi_rate']:5.1f}% / 決勝到達 {r['final_rate']:5.1f}%")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else C.N_CAREERS
    print(f"=== 上限120×通過ライン走査 | 逓減D={B.GROWTH_DECAY_D} 上限{B.ABILITY_CAP}(メンタル{B.MENTAL_CAP}) | "
          f"{n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
    print("目標: S0で優勝なし9割前後かつ決勝到達は1〜3割 / S3で中央値6年前後・優勝なし5%未満")
    print()
    try:
        for set_name, lines in LINE_SETS.items():
            print(f"== ラインセット {set_name}: 1回{lines[0]}/2回{lines[1]}/3回{lines[2]}/準々{lines[3]}"
                  f"/準決{lines[4]}/復活{lines[5]}/決勝{lines[6]} ==")
            apply_lines(lines)
            for sc_name, kwargs in SCENARIOS:
                print(f"  [{sc_name}]")
                for cls in C.BOTS:
                    show(C.run_config(cls, n, **kwargs))
            print()
    finally:
        restore_lines()

if __name__ == "__main__":
    main()
