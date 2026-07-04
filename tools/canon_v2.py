#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
正典v2の設定ヘルパ（docs/human_calibration_v0.md §5 / docs/rule_holes_v0.md）
- apply() で v2 の採用フラグ一式（生活ルール・年齢カーブ上限・2層ブレ・圧縮ライン）を sim に適用する
- 数値は全て【仮】。最終アンカーは exp_v2_anchor.py で確定した値をここに反映する
- 注意: balance_sim / sim_career の既定値は旧正典のまま（golden 保護）。v2 実験は必ず本モジュール経由で
"""

import balance_sim as B
import sim_career as C

# --- 成長経済 ---
CAP_CURVE = (6.0, 0.4, 2.0)     # 年間成長上限 = max(2.0, 6.0 − 0.4×(年−1))
TROPHY_LIFT_PER_PT = 0.02       # トロフィー1ptあたり上限カーブ+0.02/年

# --- 生活ルール ---
DEBT_TRAIN_FACTOR = 0.5         # 借金中は稽古効果半減（段階1）
DEBT_LIFE_PEN = (-10, -3)       # 生活費未払い月の生活苦（体力, メンタル）
BANKRUPT_LINE = -1_000_000      # 夜逃げライン（段階3）
STAMINA_GATE = 20.0             # 稽古ハードゲート（谷口が止める）
INJURY = dict(on=True)          # キツいバイトの体調ダウン制（確率・週数は sim_career 既定）

# --- 勝負の運 ---
BURST_P = 0.10                  # ハマった夜の発生率
BURST_BONUS = 12.0              # ハマった夜の加点

# --- 大会ライン（旧正典の0.55倍圧縮＋GP上位はA案アンカー） ---
TOURNAMENT_SCALE = 0.55
GP_ROUNDS = [(30, 18, "GP1回戦"), (39, 26, "GP2回戦"), (41, 34, "GP3回戦"), (43, 45, "GP準々決勝")]
GP_SF = (45, 74, "GP準決勝")    # 【確定 2026-07-05・exp_v2_anchor】
GP_FINAL_LINE = 80              # 【確定 2026-07-05・exp_v2_anchor】やり込み2.1%・のんびり改0.3%/到達22%
GP_REVIVAL_OFFSET = -4          # 敗者復活 = 決勝-4

_orig_tlines = None

def apply(trophy_pt=0):
    """v2一式を適用。trophy_pt で才能解放（上限カーブの持ち上げ）を注入"""
    global _orig_tlines
    lift = TROPHY_LIFT_PER_PT * trophy_pt
    C.CAP_CURVE = (CAP_CURVE[0] + lift, CAP_CURVE[1], CAP_CURVE[2] + lift)
    B.DEBT_TRAIN_FACTOR = DEBT_TRAIN_FACTOR
    C.DEBT_LIFE_PEN = DEBT_LIFE_PEN
    C.BANKRUPT_LINE = BANKRUPT_LINE
    C.STAMINA_GATE = STAMINA_GATE
    C.INJURY_ON = INJURY["on"]
    B.BURST_P = BURST_P
    B.BURST_BONUS = BURST_BONUS
    C.EVENTS_ON = True
    if _orig_tlines is None:
        _orig_tlines = {w: t["line"] for w, t in C.TOURNAMENTS.items()}
    for w, t in C.TOURNAMENTS.items():
        t["line"] = round(_orig_tlines[w] * TOURNAMENT_SCALE)
    C.GP_ROUNDS = GP_ROUNDS + [GP_SF]
    C.GP_FINAL_LINE = GP_FINAL_LINE
    C.GP_REVIVAL_LINE = GP_FINAL_LINE + GP_REVIVAL_OFFSET

def reset():
    """旧正典（既定値）へ戻す"""
    C.CAP_CURVE = None
    B.YEAR_GROWTH_CAP = None
    B.DEBT_TRAIN_FACTOR = None
    C.DEBT_LIFE_PEN = None
    C.BANKRUPT_LINE = None
    C.STAMINA_GATE = None
    C.INJURY_ON = False
    B.BURST_P = None
    C.EVENTS_ON = False
    if _orig_tlines is not None:
        for w, t in C.TOURNAMENTS.items():
            t["line"] = _orig_tlines[w]
