#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Q1 命題4検証: 停滞層(ever_final==False)ゲート付きレバーで G3漏れが消えるか。
experiment-only。canonical本体無編集。exp_lastyear のレバー機構(_yg -= X)は不変で、
発動条件に gate(stalled限定) を足すだけ。finally完全復元。全て【仮】。"""
import sys, random, math
sys.path.insert(0, "/home/user/manzai-game/tools")
import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread
import exp_lastyear as L

BASE_BURST_P = B.BURST_P
_ORIG_GP = C._gp_perform
TH, BP, FLOOR = 3, 0.30, 8
XS = [0, 1, 2, 3, 4]


def run_one(pol, seed, pity_on, init_ability, compat, X, gate):
    """gate=False: 全year10コンビにX適用(=既存exp_lastyear). gate=True: 停滞層のみX適用."""
    rng = random.Random(seed)
    s = C.new_state(init_ability, compat)
    if C.EVENTS_ON:
        C.RUN_EVENTS_FIRED = set()
    if C.BOREDOM_ON:
        C.RUN_BOREDOM = {}
    prev_stage = 0; dry = 0; ever_final = False
    won_career = False; stalled = False
    st_reached = False; st_won = False
    applied = False  # このキャリアでXが実際に適用されたか(診断)

    for year in range(1, C.YEARS + 1):
        if year == C.YEARS:
            stalled = not ever_final
            if X and (stalled or not gate):
                if not hasattr(s, "_yg"):
                    s._yg = 0.0
                s._yg -= X
                applied = True

        active = pity_on and (dry >= TH) and (year >= FLOOR) and (not ever_final)
        B.BURST_P = BP if active else BASE_BURST_P
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        ever_final = ever_final or finalist
        dry = 0 if finalist else dry + 1

        if year == C.YEARS and stalled:
            st_reached = finalist; st_won = won

        if getattr(s, "_bankrupt", False):
            break
        if won:
            won_career = True; break

    return dict(won=won_career, ever_final=ever_final, stalled=stalled,
                st_reached=st_reached, st_won=st_won, applied=applied)


def scan(pol_cls, n, pity_on, trophy_pt, compat_cap, init_ability, compat_start, X, gate):
    V.apply(trophy_pt=trophy_pt)
    B.COMPAT_CAP = compat_cap
    if pity_on:
        C._gp_perform = L._gp_final_at_base
    try:
        pol = pol_cls()
        wins = finals = 0
        st_n = st_reached = st_won = 0
        applied_n = 0
        for i in range(n):
            r = run_one(pol, C.BASE_SEED + i, pity_on, init_ability, compat_start, X, gate)
            wins += r["won"]; finals += r["ever_final"]
            applied_n += r["applied"]
            if r["stalled"]:
                st_n += 1
                st_reached += r["st_reached"]; st_won += r["st_won"]
        pct = lambda a, b: (100.0 * a / b) if b else float("nan")
        return dict(won=pct(wins, n), final=pct(finals, n), st_n=st_n,
                    st_reached=pct(st_reached, st_n), st_won=pct(st_won, st_n),
                    applied_n=applied_n)
    finally:
        C._gp_perform = _ORIG_GP
        B.BURST_P = BASE_BURST_P
        B.COMPAT_CAP = 20
        V.reset()


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 800
    IA0, CS0 = 10, 5
    IA30, CS30, CAP30 = 20, 20, 24
    try:
        print(f"=== 命題4検証: 停滞層ゲート有/無の弁別 | n={n} | 全て【仮】 ===\n")

        # G3漏れ検査: 30ptやり込み。ゲート無し vs ゲート有りで全キャリア優勝を弁別
        print("【A】G3漏れ検査 [裏天井ON・30ptやり込み(SSR相方)] 基準G3≈62.1%")
        print(f"{'X':<3}| gate無 全体優勝 | gate有 全体優勝 | 停滞層n | gate有 適用件数 | gate有 停滞層優勝")
        print("-" * 96)
        for X in XS:
            ru = scan(PSpread, n, True, 30, CAP30, IA30, CS30, X, gate=False)
            rg = scan(PSpread, n, True, 30, CAP30, IA30, CS30, X, gate=True)
            print(f"{X:<3}| {ru['won']:6.2f}%       | {rg['won']:6.2f}%       | "
                  f"{rg['st_n']:4d}    | {rg['applied_n']:4d}          | {rg['st_won']:6.2f}%",
                  flush=True)
        print()

        # G4蘇生が gate有 でも保たれるか(分散・0pt初回帯・停滞層最終年)
        print("【B】G4蘇生の保存 [裏天井ON・0pt初回帯・分散] gate有 停滞層最終年 到達/優勝")
        print(f"{'X':<3}| gate無 停滞層 到達/優勝 | gate有 停滞層 到達/優勝 | 停滞層n | gate有 全体優勝(G2)")
        print("-" * 96)
        for X in XS:
            ru = scan(PSpread, n, True, 0, 20, IA0, CS0, X, gate=False)
            rg = scan(PSpread, n, True, 0, 20, IA0, CS0, X, gate=True)
            print(f"{X:<3}| {ru['st_reached']:5.1f}% / {ru['st_won']:5.2f}%      | "
                  f"{rg['st_reached']:5.1f}% / {rg['st_won']:5.2f}%      | {rg['st_n']:4d}    | "
                  f"{rg['won']:5.2f}%", flush=True)
        print()

        # G1のんびり(0pt初回帯)も gate有で不変か
        print("【C】G1不変検査 [裏天井ON・0pt初回帯・のんびり] gate有")
        print(f"{'X':<3}| gate無 全体 到達/優勝 | gate有 全体 到達/優勝 | 停滞層n | gate有 停滞層最終年 到達/優勝")
        print("-" * 96)
        for X in XS:
            ru = scan(PCasual2, n, True, 0, 20, IA0, CS0, X, gate=False)
            rg = scan(PCasual2, n, True, 0, 20, IA0, CS0, X, gate=True)
            print(f"{X:<3}| {ru['final']:5.1f}% / {ru['won']:5.2f}%     | "
                  f"{rg['final']:5.1f}% / {rg['won']:5.2f}%     | {rg['st_n']:4d}    | "
                  f"{rg['st_reached']:5.1f}% / {rg['st_won']:5.2f}%", flush=True)
    finally:
        V.reset(); B.COMPAT_CAP = 20; B.BURST_P = BASE_BURST_P


if __name__ == "__main__":
    main()
