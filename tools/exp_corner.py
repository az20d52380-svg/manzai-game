#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
角の同時成立裁定 — 30pt × SSR相方(cap24) × 裏天井 × 得意A × 絆 の受け皿
================================================================================
本命1問(reformulated・本編10年):
  「30pt × SSR相方(cap24) × 裏天井 × 得意A × 絆 の各ボーナスが本編10年で"同時充足
   する"解はあるか。無ければどの帯を犠牲にするか。」
新しい合格規範(【仮】・Fableが最終確定):
  (i)   0pt初回帯が不変（アンカー: のんびり 優勝≈0.3%/到達≈23.1% / やり込み 優勝≈2.7%/到達≈41.5%）
  (ii)  角(全部ON・やり込み)の優勝が"必勝化"しない上限規範（暫定 <90%）
  (iii) 各レバー単独ON→全部ONの寄与が加算的で、乗算的に暴走しないこと

正典非干渉(構造保証):
  - gen_golden は balance_sim / sim_career しか import しない（確認済）。本モジュールは
    exp_*.py なので golden への波及はゼロ。
  - すべて experiment-only: 一時的にグローバル/属性を上書き→finallyで完全復元。
    exp_pity3.py の型（canon_v2.apply / B.COMPAT_CAP / B.BURST_P / C._gp_perform ラップ）を土台に、
    得意A(exp_talent_ability) と 絆(compat_start 底上げ) を重ねる。

各レバーの機構（確認済フック点）:
  - 30pt          : canon_v2.apply(30) が CAP_CURVE を +0.02/pt lift（才能解放=上限持ち上げ）。V.reset()で復元。
  - SSR相方(cap24): B.COMPAT_CAP = 24（既定20＝相性上限+4）。finallyで20へ。
  - 裏天井        : 確定式(MODE C・TH3・FLOOR8・BP0.30・決勝本番は素・初到達で恒久解除)。
                    B.BURST_P 一時上書き + C._gp_perform ラップ→finally復元（exp_pity3の型）。
  - 得意A(方式A)  : exp_talent_ability.apply(1.20)。稽古効率+20%を演技系4能力(sense/idea/expr/chara)限定。
                    mental/compat/stamina/fame には絶対かけない（モジュール側で保証済）。
  - 絆(bond)      : ★角の中で最も機構が薄い＝最も仮★。score=jitsuryoku+compat+roll+pen で
                    compat が直接スコアに乗る（balance_sim.py:190）。絆ボーナス≒追加compat を
                    compat_start の底上げ(+BOND_COMPAT_START)で近似する。
                    後述の通り late-game は COMPAT_CAP に飲まれ得る＝寄与が薄いのが仕様上の帰結。

いじらない（golden破壊）: sim_career.run_year 本体・gen_golden・balance_sim の add/成長中核・
  CAP_CURVE 定数本体・canon_v2 の数値。本台は上書き→finally復元のみ。

使い方: python3 exp_corner.py [N=600]
数値は全て【仮】。確定フリップ(golden同期)はMacへ引き継ぐ前提。
"""
import random
import sys

import balance_sim as B
import sim_career as C
import canon_v2 as V
import exp_talent_ability as T
from exp_human import PCasual2
from exp_human_fix import PSpread

# --- 谷口N（初プレイ・canonical §2 アンカー基準） ---
INIT_ABILITY = 10        # 能力5種 一律（得意Aは"稽古効率"のレバー＝初期値は谷口のまま）
BASE_COMPAT_START = 5    # コンビ相性 初期（谷口N）

# --- 裏天井 確定式（exp_pity3 と同一） ---
BASE_BURST_P = B.BURST_P
_ORIG_GP = C._gp_perform
TH, BP, FLOOR = 3, 0.30, 8

# --- 得意A ---
TALENT_MULT = 1.20       # 【仮】稽古効率倍率（演技系4能力限定）

# --- 絆（最も仮） ---
BOND_COMPAT_START = 8    # 【仮】絆ボーナス≒追加compat を compat_start 底上げで近似（5→13）


def _gp_final_at_base(s, line, rng, final):
    """裏天井: 決勝の本番だけ BURST_P を素に戻す（MODE C・exp_pity3 と同一）。"""
    if final and B.BURST_P != BASE_BURST_P:
        saved = B.BURST_P
        B.BURST_P = BASE_BURST_P
        try:
            return _ORIG_GP(s, line, rng, final)
        finally:
            B.BURST_P = saved
    return _ORIG_GP(s, line, rng, final)


def run_one(pol, seed, pity_on, init_ability, compat_start):
    """1キャリア(本編10年)。exp_pity3.run_one と同じ per-career 初期化＋年頭の裏天井ゲート。
    返り値: (won:bool, ever_final:bool)。ever_final=キャリア中に一度でも決勝到達。"""
    rng = random.Random(seed)
    s = C.new_state(init_ability, compat_start)
    if C.EVENTS_ON:
        C.RUN_EVENTS_FIRED = set()
    if C.BOREDOM_ON:
        C.RUN_BOREDOM = {}
    prev_stage = 0
    dry = 0
    ever_final = False
    for year in range(1, C.YEARS + 1):
        active = pity_on and (dry >= TH) and (year >= FLOOR) and (not ever_final)
        B.BURST_P = BP if active else BASE_BURST_P
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1
        if getattr(s, "_bankrupt", False):
            break
        if won:
            return True, ever_final
    return False, ever_final


def scan(pol_cls, n, trophy_pt, compat_cap, pity_on, talent_on, bond_on):
    """レバーを合成適用→実測→finallyで完全復元。返り値:(優勝率%, 決勝到達率%)。
    baseline(全レバーOFF: trophy0/cap20/no-pity/no-talent/no-bond) は
    canon_v2.apply(0)＝canonical §2 の計測条件を再現する（アンカー継承）。"""
    V.apply(trophy_pt=trophy_pt)          # 30pt: CAP lift（0でも EVENTS_ON=True の正典条件）
    B.COMPAT_CAP = compat_cap             # SSR: 相性上限
    if talent_on:
        T.apply(TALENT_MULT)              # 得意A: do_training ラップ
    if pity_on:
        C._gp_perform = _gp_final_at_base  # 裏天井: 決勝本番の素戻しラップ
    compat_start = BASE_COMPAT_START + (BOND_COMPAT_START if bond_on else 0)  # 絆: compat_start 底上げ
    try:
        pol = pol_cls()
        wins = finals = 0
        for i in range(n):
            won, ever = run_one(pol, C.BASE_SEED + i, pity_on, INIT_ABILITY, compat_start)
            wins += won
            finals += ever
        return 100.0 * wins / n, 100.0 * finals / n
    finally:
        if pity_on:
            C._gp_perform = _ORIG_GP
        if talent_on:
            T.reset()
        B.COMPAT_CAP = 20
        B.BURST_P = BASE_BURST_P
        V.reset()


# レバー構成: (label, trophy_pt, compat_cap, pity, talent, bond)
def _cfg(trophy=0, cap=20, pity=False, talent=False, bond=False):
    return dict(trophy_pt=trophy, compat_cap=cap, pity_on=pity, talent_on=talent, bond_on=bond)


STACK = [   # 積み上げ（単独→合成）: 1レバーずつ累積ON
    ("① baseline (0pt/谷口N)",      _cfg()),
    ("② +30pt",                     _cfg(trophy=30)),
    ("③ +SSR相方(cap24)",           _cfg(trophy=30, cap=24)),
    ("④ +裏天井",                   _cfg(trophy=30, cap=24, pity=True)),
    ("⑤ +得意A",                    _cfg(trophy=30, cap=24, pity=True, talent=True)),
    ("⑥ +絆 (=角/全部ON)",          _cfg(trophy=30, cap=24, pity=True, talent=True, bond=True)),
]

SINGLES = [  # 単独寄与: baseline に1レバーだけ乗せる（加算/乗算の弁別用）
    ("baseline",     _cfg()),
    ("30pt のみ",    _cfg(trophy=30)),
    ("SSR のみ",     _cfg(cap=24)),
    ("裏天井 のみ",  _cfg(pity=True)),
    ("得意A のみ",   _cfg(talent=True)),
    ("絆 のみ",      _cfg(bond=True)),
]


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    pols = [PCasual2, PSpread]

    print(f"=== 角の同時成立裁定 | n={n}/設定 | シード{C.BASE_SEED}起点 | 本編{C.YEARS}年 | 数値は全て【仮】 ===")
    print(f"レバー: 30pt(CAP+{V.TROPHY_LIFT_PER_PT}/pt) / SSR(cap20→24) / 裏天井(TH{TH}/FLOOR{FLOOR}/BP{BP}/決勝除外/初到達解除)"
          f" / 得意A(稽古×{TALENT_MULT}/演技系4能力) / 絆(compat_start 5→{BASE_COMPAT_START+BOND_COMPAT_START}=最も仮)")
    print()

    # ---- (3) アンカー検証: 全レバーOFF(0pt) が canonical §2 に一致 ----
    print("--- (3) アンカー検証: 全レバーOFF(0pt) = canonical §2 ---")
    print(f"{'プレイ型':<10}| 実測 到達 / 優勝        | 基準(canonical §2)")
    print("-" * 66)
    ref = {"のんびり改": "到達≈23.1% / 優勝≈0.3%", "分散稽古型": "到達≈41.5% / 優勝≈2.7%"}
    for cls in pols:
        w, f = scan(cls, n, **SINGLES[0][1])
        name = getattr(cls(), "name", cls.__name__)
        print(f"{name:<10}| 到達 {f:5.1f}% / 優勝 {w:5.2f}%   | {ref.get(name,'')}")
    print()

    # ---- (2)+(c) 積み上げスキャン（単独→合成） ----
    print("--- (c) 積み上げスキャン: 1レバーずつ累積ON（marginal=直前段からの優勝差） ---")
    for cls in pols:
        name = getattr(cls(), "name", cls.__name__)
        print(f"[{name}]")
        print(f"{'段階':<26}| 決勝到達 | 優勝    | marginalΔ優勝")
        print("-" * 66)
        prev_w = None
        for label, cfg in STACK:
            w, f = scan(cls, n, **cfg)
            dtxt = "  (基準)" if prev_w is None else f"  {w-prev_w:+6.2f}"
            print(f"{label:<26}| {f:6.1f}% | {w:6.2f}% |{dtxt}", flush=True)
            prev_w = w
        print()

    # ---- (d)+(e) 角セル & 加算/乗算判定（単独寄与 vs 合成） ----
    print("--- (d)(e) 単独寄与 Σ vs 角の合成寄与（加算/乗算の弁別） ---")
    for cls in pols:
        name = getattr(cls(), "name", cls.__name__)
        base_w, base_f = scan(cls, n, **SINGLES[0][1])
        singles_w = {}
        for label, cfg in SINGLES[1:]:
            w, f = scan(cls, n, **cfg)
            singles_w[label] = w - base_w
        corner_w, corner_f = scan(cls, n, **STACK[-1][1])
        sum_singles = sum(singles_w.values())
        corner_delta = corner_w - base_w
        print(f"[{name}]  baseline 優勝={base_w:.2f}% 到達={base_f:.1f}%")
        for k, v in singles_w.items():
            print(f"    単独寄与 {k:<10}: 優勝 Δ{v:+6.2f}")
        print(f"    Σ(単独寄与)            = {sum_singles:+6.2f}")
        print(f"    角(全部ON) 優勝        = {corner_w:.2f}%  到達={corner_f:.1f}%  (baseからΔ{corner_delta:+.2f})")
        ratio = (corner_delta / sum_singles) if abs(sum_singles) > 1e-9 else float('nan')
        verdict = ("加算的(合成≒Σ単独)" if corner_delta <= sum_singles * 1.15 + 1.0
                   else "超加算/乗算疑い(合成>Σ単独)")
        nec = ">90%=必勝化" if corner_w > 90 else "<90%=必勝化せず"
        print(f"    合成Δ/Σ単独 = {ratio:.2f}  → {verdict}")
        print(f"    必勝化判定(規範ii): 角優勝 {corner_w:.2f}% → {nec}")
        print()


if __name__ == "__main__":
    main()
