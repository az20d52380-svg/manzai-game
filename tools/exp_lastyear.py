#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
「ラストイヤーの奇跡」 — 最終年(10年目)だけ伸びしろを +X 解放するレバーのQ1受け皿
================================================================================
問い(Q1): 「10年通っても決勝に一度も立てなかった停滞コンビ」が、最終年に限って
少しだけ伸びしろを取り戻したら、"ラストイヤーの奇跡"は起きるか？初回帯の頭は
壊れないか？やり込みの優勝は跳ねないか？

- レバー(唯一正しい実装): 最終年(year==YEARS==10)の run_year 呼び出し「直前」に
  s._yg を X 下げる。budget = YEAR_GROWTH_CAP - s._yg (balance_sim.py:126) なので
  _yg を下げる = その年の伸びしろ +X。CAREER_BUDGET では run_year が年頭に _yg を
  リセットしない(sim_career.py:361 `if not hasattr` ガードのみ)ため +X はその年だけ生きる。
  * 罠(踏まない): (1)run_year前に B.YEAR_GROWTH_CAP を代入しても年頭で上書き消滅
    (2)CAP_CURVE の基準に +X すると累計で全10年に乗り約+10X → 最終年限定にならない。
  * s._yg 操作は draw 非消費 = 乱数消費順不変 = golden 非干渉。new_state はキャリア毎に
    作り直すので状態汚染なし。
- 実験のみ: canon_v2.apply(trophy)/B.COMPAT_CAP/B.BURST_P/C._gp_perform を一時操作し
  finally で完全復元。sim_career/gen_golden 本体は未編集 = golden 非干渉。数値は全て【仮】。
- 裏天井は確定式(exp_pity3 と同型: MODE C・TH3・FLOOR8・BP0.30・決勝除外・初到達で恒久解除)。
- 停滞層の分離集計: 9年目終了時 ever_final==False で最終年に来た層に限り、
  「最終年"単体"の決勝到達/優勝」を集計(既存 run_one は全キャリアwonのみ=不足のため拡張)。
- 使い方: python3 exp_lastyear.py [N=700]
================================================================================
"""
import math
import random
import sys

import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread

BASE_BURST_P = B.BURST_P
_ORIG_GP = C._gp_perform
TH, BP, FLOOR = 3, 0.30, 8          # 裏天井 確定式(exp_pity3 §6 と揃える)
XS = [0, 1, 2, 3, 4]               # ラストイヤー緩和量(実力値換算・X=0 は緩和OFF)

# canonical §2 アンカー(トロフィー0pt・裏天井/得意OFF・0pt初回帯=谷口N)
ANCHOR = {"のんびり改": (23.1, 0.3), "分散稽古型": (41.5, 2.7)}


def _gp_final_at_base(s, line, rng, final):
    """MODE C: 準決以下だけ BURST_P を上書きし、決勝の本番は素の BURST_P に戻す。"""
    if final and B.BURST_P != BASE_BURST_P:
        saved = B.BURST_P; B.BURST_P = BASE_BURST_P
        try: return _ORIG_GP(s, line, rng, final)
        finally: B.BURST_P = saved
    return _ORIG_GP(s, line, rng, final)


def _cum_cap(year):
    """CAREER_BUDGET の year 年目頭の累計成長上限(実力値換算)。診断用。
    注意: 現在の C.CAP_CURVE を読むため、直前の V.apply(trophy) の残りに左右される。
    トロフィー別に確定値が欲しいときは _cum_cap_for を使う。"""
    base, slope, floor = C.CAP_CURVE
    return sum(max(floor, base - slope * (k - 1))
               for k in range(1, min(year, C.GROWTH_END_YEAR) + 1))


def _cum_cap_for(year, trophy_pt):
    """C.CAP_CURVE の現在状態に依存せず、trophy_pt から累計上限を確定計算(診断ヘッダ用)。"""
    lift = V.TROPHY_LIFT_PER_PT * trophy_pt
    base, slope, floor = V.BASE_CURVE[0] + lift, V.BASE_CURVE[1], V.BASE_CURVE[2] + lift
    return sum(max(floor, base - slope * (k - 1))
               for k in range(1, min(year, C.GROWTH_END_YEAR) + 1))


def run_one(pol, seed, pity_on, init_ability, compat, X):
    """1キャリア。全キャリアの won/ever_final に加え、停滞層(9年目終了時 ever_final==False)
    の「最終年単体」到達/優勝と、10年目頭の残成長予算を返す。"""
    rng = random.Random(seed)
    s = C.new_state(init_ability, compat)
    # run_career と同じ per-career グローバル初期化(無いとイベント状態が漏れて汚染)
    if C.EVENTS_ON:
        C.RUN_EVENTS_FIRED = set()
    if C.BOREDOM_ON:
        C.RUN_BOREDOM = {}
    prev_stage = 0; dry = 0; ever_final = False
    won_career = False
    stalled = False            # 9年目終了時点 ever_final==False で最終年に来たか
    st_reached = False         # 停滞層の最終年"単体"で決勝に立ったか
    st_won = False             # 停滞層の最終年"単体"で優勝したか
    yr10_budget = None         # 10年目頭の残成長予算(累計上限 − _yg)。診断用

    for year in range(1, C.YEARS + 1):
        # --- 最終年の直前フック: 停滞判定 → 残予算診断 → レバー(_yg を X 下げる) ---
        if year == C.YEARS:
            stalled = not ever_final                      # ここまで一度も決勝に立てず最終年へ
            yr10_budget = _cum_cap(year) - getattr(s, "_yg", 0.0)
            if X:
                if not hasattr(s, "_yg"):
                    s._yg = 0.0
                s._yg -= X                                # 伸びしろ +X (この年だけ生きる)

        active = pity_on and (dry >= TH) and (year >= FLOOR) and (not ever_final)
        B.BURST_P = BP if active else BASE_BURST_P
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1

        if year == C.YEARS and stalled:                   # 停滞層の最終年"単体"の結果
            st_reached = finalist
            st_won = won

        if getattr(s, "_bankrupt", False):
            break
        if won:
            won_career = True
            break

    return dict(won=won_career, ever_final=ever_final,
                stalled=stalled, st_reached=st_reached, st_won=st_won,
                yr10_budget=yr10_budget)


def scan(pol_cls, n, pity_on, trophy_pt, compat_cap, init_ability, compat_start, X):
    """1設定 × X を n キャリア回す。全キャリア到達/優勝 と 停滞層の最終年到達/優勝 を返す。"""
    V.apply(trophy_pt=trophy_pt)
    B.COMPAT_CAP = compat_cap
    if pity_on:
        C._gp_perform = _gp_final_at_base
    try:
        pol = pol_cls()
        wins = finals = 0
        st_n = st_reached = st_won = 0
        bud_sum = 0.0; bud_cnt = 0            # 最終年に来た全キャリアの残予算
        st_bud_sum = 0.0; st_bud_cnt = 0      # 停滞層だけの残予算
        for i in range(n):
            r = run_one(pol, C.BASE_SEED + i, pity_on, init_ability, compat_start, X)
            wins += r["won"]; finals += r["ever_final"]
            if r["yr10_budget"] is not None:
                bud_sum += r["yr10_budget"]; bud_cnt += 1
            if r["stalled"]:
                st_n += 1
                st_reached += r["st_reached"]; st_won += r["st_won"]
                st_bud_sum += r["yr10_budget"]; st_bud_cnt += 1
        pct = lambda a, b: (100.0 * a / b) if b else float("nan")
        return dict(
            won=pct(wins, n), final=pct(finals, n),
            st_n=st_n,
            st_reached=pct(st_reached, st_n), st_won=pct(st_won, st_n),
            budget=(bud_sum / bud_cnt if bud_cnt else float("nan")),
            st_budget=(st_bud_sum / st_bud_cnt if st_bud_cnt else float("nan")),
        )
    finally:
        C._gp_perform = _ORIG_GP
        B.BURST_P = BASE_BURST_P


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 700
    IA0, CS0 = 10, 5                  # 0pt初回帯(谷口N)
    IA30, CS30, CAP30 = 20, 20, 24    # 30pt やり込み(SSR相方)

    try:
        # ============================================================
        # ① アンカー検証: 裏天井OFF・X=0・0pt初回帯 が canonical §2 に一致するか
        # ============================================================
        print(f"=== ラストイヤーの奇跡 | n={n}/設定 | 裏天井=確定式(TH3/FLOOR8/BP0.30/決勝除外/初到達解除) | 全て【仮】 ===\n")
        print("① アンカー検証 [裏天井OFF・X=0・0pt初回帯(谷口N)] — canonical §2 と突合")
        print(f"{'プレイ型':<10}| 実測 到達 / 優勝    | canon §2 到達 / 優勝 | 判定")
        print("-" * 74)
        for cls in (PCasual2, PSpread):
            r = scan(cls, n, False, 0, 20, IA0, CS0, 0)
            name = cls().name
            af, aw = ANCHOR[name]
            ok = (abs(r["final"] - af) <= 3.0) and (abs(r["won"] - aw) <= 1.5)
            print(f"{name:<10}| {r['final']:5.1f}% / {r['won']:5.2f}%   | "
                  f"{af:5.1f}% / {aw:5.2f}%    | {'一致(ノイズ内)' if ok else '要確認'}",
                  flush=True)
        print()

        # ============================================================
        # ② 用量反応: 裏天井ON・0pt初回帯 で X=0→+4 をスキャン
        #    G1/G2 = 全キャリア到達/優勝(初回帯の頭・年1-9は X 非依存で不変)
        #    G4     = 停滞層(9年目終了 ever_final==False)の「最終年単体」到達/優勝
        # ============================================================
        print("② ラストイヤー用量反応 [裏天井ON・0pt初回帯] — 年1-9は X 非依存で不変、効くのは10年目のみ")
        print(f"{'型':<10}| X | 全キャリア 到達/優勝(G1/G2) | 停滞層n | 停滞層 最終年 到達/優勝(G4)")
        print("-" * 92)
        for cls in (PCasual2, PSpread):
            name = cls().name
            for X in XS:
                r = scan(cls, n, True, 0, 20, IA0, CS0, X)
                print(f"{name:<10}| {X} | {r['final']:5.1f}% / {r['won']:5.2f}%           | "
                      f"{r['st_n']:4d}    | {r['st_reached']:5.1f}% / {r['st_won']:5.2f}%",
                      flush=True)
            print()

        # ============================================================
        # ③ G3 漏れ検査: 30pt やり込み優勝(基準62.1%)がレバーで跳ねないか(1行/X)
        # ============================================================
        print("③ G3 漏れ検査 [裏天井ON・30pt やり込み(SSR相方)] — 全キャリア優勝が跳ねないか(基準≈62.1%)")
        print(f"{'X':<3}| 全キャリア優勝(G3) | 停滞層n | 停滞層 最終年 優勝")
        print("-" * 60)
        for X in XS:
            r = scan(PSpread, n, True, 30, CAP30, IA30, CS30, X)
            print(f"{X:<3}| {r['won']:5.1f}%            | {r['st_n']:4d}    | {r['st_won']:5.2f}%",
                  flush=True)
        print()

        # ============================================================
        # ④ 診断: 「10年目の残成長予算≈0」 (累計上限 − _yg を最終年頭でログ)
        # ============================================================
        print("④ 診断: 10年目頭の残成長予算(累計上限 − _yg)[裏天井ON・X=0]")
        print(f"    累計成長上限(10年目頭): 0pt={_cum_cap_for(10,0):.1f} / 30pt={_cum_cap_for(10,30):.1f} (実力値換算)")
        print(f"{'型':<10}| trophy | 累計上限 | 最終年到達 全体 残予算 | 停滞層 残予算")
        print("-" * 70)
        for cls, pt, cap, ia, cs in [
            (PCasual2, 0, 20, IA0, CS0),
            (PSpread, 0, 20, IA0, CS0),
            (PSpread, 30, CAP30, IA30, CS30),
        ]:
            r = scan(cls, n, True, pt, cap, ia, cs, 0)
            stb = "n/a" if math.isnan(r["st_budget"]) else f"{r['st_budget']:+.2f}"
            print(f"{cls().name:<10}| {pt:4d}pt | {_cum_cap_for(10,pt):6.1f}   | "
                  f"{r['budget']:+.2f}                 | {stb}",
                  flush=True)
    finally:
        V.reset()
        B.COMPAT_CAP = 20
        B.BURST_P = BASE_BURST_P


if __name__ == "__main__":
    main()
