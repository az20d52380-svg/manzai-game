#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
正典v2の設定ヘルパ（docs/canonical_v2_spec.md）
- 【2026-07-05フリップ済み】v2の採用値は balance_sim.py / sim_career.py の既定値になった。
  本モジュールは (a)トロフィーpt（才能解放=上限カーブの持ち上げ）の注入 (b)イベント層ON（正典計測条件）
  (c)実験後の原状復帰 のためのヘルパとして残す。
- 数値は全て【仮】
"""

import balance_sim as B
import sim_career as C

TROPHY_LIFT_PER_PT = 0.02       # トロフィー1ptあたり上限カーブ+0.02/年
DYNASTY_STEP = 2.0              # 王者ライン = 決勝 + STEP×連覇数【仮】
CHAMPION_GROWTH_END = 25        # 王者の特権: 初優勝後は成長期限が解除される（canonical_v2_spec §2-B）

BASE_CURVE = C.CAP_CURVE        # (6.0, 0.4, 2.0)
BASE_GROWTH_END = C.GROWTH_END_YEAR

def apply(trophy_pt=0):
    """正典v2の計測条件を適用（イベント層ON＋トロフィーptの才能解放）"""
    lift = TROPHY_LIFT_PER_PT * trophy_pt
    C.CAP_CURVE = (BASE_CURVE[0] + lift, BASE_CURVE[1], BASE_CURVE[2] + lift)
    C.GROWTH_END_YEAR = BASE_GROWTH_END
    C.EVENTS_ON = True

def reset():
    """既定値（=v2）へ戻す（イベント層は既定OFF=golden条件）"""
    C.CAP_CURVE = BASE_CURVE
    C.GROWTH_END_YEAR = BASE_GROWTH_END
    C.EVENTS_ON = False
    B.YEAR_GROWTH_CAP = None
