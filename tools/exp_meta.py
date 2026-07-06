#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 周回メタボーナスの設計形の検証（docs/endgame_design_v0.md の根拠データ）
- exp_endgame.py の発見: 初期能力加算・相性固定のボーナスは「序盤の加速」にしかならず、
  逓減で終盤の到達点が揃うため、決勝ライン95では周回しても優勝できない（フル強化でも優勝率2%未満）
- 仮説: 周回ボーナスは天井を上げる形にする
    (1) トロフィー → 逓減D（才能限界）を引き上げる（成長の漸近線が上がる）
    (2) 相方ガチャ → 相性の初期値と成長上限を引き上げる（スコアへの恒久加点）
- 本実験はメタ段階M0〜M4のラダーで、各段階の「初優勝年」がきれいに階段状に下がるかを見る
- 使い方: python3 exp_meta.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import sys

import balance_sim as B
import sim_career as C
from exp_endgame import LINE_SETS, apply_lines, restore_lines, show

# メタ進行ラダー: (名前, モジュール上書き{定数:値}, run_configキーワード)
#   D↑ = トロフィーによる才能限界の解放 / COMPAT_CAP・compat_start↑ = 相方ガチャ / init_ability↑ = おまけの快適性
LADDER = [
    ("M0 初回(素)",              {},                                        {}),
    ("M1 トロフィー小(D125)",    dict(GROWTH_DECAY_D=125),                  {}),
    ("M2 相方当たり(15→上限25)", dict(COMPAT_CAP=25),                       dict(compat_start=15)),
    ("M3 中期(D130+相方25)",     dict(GROWTH_DECAY_D=130, COMPAT_CAP=25),   dict(compat_start=15, init_ability=15)),
    ("M4 フル(D140+相方30)",     dict(GROWTH_DECAY_D=140, COMPAT_CAP=30),   dict(compat_start=20, init_ability=20)),
]

TEST_SETS = ("B 中辛(95)", "C 辛口(100)")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else C.N_CAREERS
    print(f"=== 周回メタラダー検証 | 上限{B.ABILITY_CAP} | {n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
    print("目標: M0=優勝なし9割超（決勝到達1〜3割） → M2/M3で優勝が現実化 → M4で中央値6年前後")
    print()
    saved = {k: getattr(B, k) for k in ("GROWTH_DECAY_D", "COMPAT_CAP")}
    try:
        for set_name in TEST_SETS:
            lines = LINE_SETS[set_name]
            print(f"== ラインセット {set_name}: 1回{lines[0]}/2回{lines[1]}/3回{lines[2]}/準々{lines[3]}"
                  f"/準決{lines[4]}/復活{lines[5]}/決勝{lines[6]} ==")
            apply_lines(lines)
            for name, overrides, kwargs in LADDER:
                for k, v in saved.items():
                    setattr(B, k, overrides.get(k, v))
                print(f"  [{name}]")
                for cls in C.BOTS:
                    show(C.run_config(cls, n, **kwargs))
            print()
    finally:
        restore_lines()
        for k, v in saved.items():
            setattr(B, k, v)

if __name__ == "__main__":
    main()
