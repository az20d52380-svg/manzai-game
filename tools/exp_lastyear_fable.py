#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fable追加集計（Q1裁定用・2026-07-05）: 既存台 exp_lastyear_gate.scan を呼ぶだけの
セル追加＝レバー機構は一切変えない（experiment-only・golden非干渉・復元はscan側のfinally）。
(a) 裏天井OFF/ON × X の層分解 —「立たせる(裏天井)」と「伸ばす(+X)」を弁別
(b) 停滞層の最終年"条件付き"優勝率(st_won/st_reached) — 二重救済の漏れ検出器
(c) Wilson 95%CI — 30pt停滞層n=43等の小標本の明示
(d) G2上昇の成分分解 — ΔG2が停滞層蘇生そのものであることの確認
全て【仮】。使い方: python3 exp_lastyear_fable.py [N=800]
"""
import math
import sys

import exp_lastyear_gate as G
from exp_human import PCasual2
from exp_human_fix import PSpread

XS = (0, 1, 2, 3, 4)


def wilson(pct, n):
    """百分率と分母から Wilson 95%CI 文字列（表示用）。"""
    if not n or math.isnan(pct):
        return "n/a"
    p = pct / 100.0
    z = 1.96
    den = 1 + z * z / n
    c = (p + z * z / (2 * n)) / den
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return f"[{100 * (c - h):.2f},{100 * (c + h):.2f}]"


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 800
    IA0, CS0 = 10, 5
    IA30, CS30, CAP30 = 20, 20, 24
    print(f"=== Fable追加集計 | n={n} | レバー=停滞層ゲート付き(ever_final==False のみ X) | 全て【仮】 ===\n")

    # 【D】裏天井OFF/ON × X の層分解（分散・0pt初回帯・gate有）
    print("【D】層の分解 [分散・0pt初回帯・gate有] 裏天井OFF/ON × X")
    print(f"{'裏天井':<3}| X | 全体優勝(G2) 95%CI        | 停滞層n | 停滞層 到達/優勝  優勝CI          | 条件付き優勝")
    print("-" * 108)
    rows_on = {}
    for pity in (False, True):
        for X in XS:
            r = G.scan(PSpread, n, pity, 0, 20, IA0, CS0, X, gate=True)
            cond = (r["st_won"] / r["st_reached"] * 100.0) if r["st_reached"] else float("nan")
            if pity:
                rows_on[X] = (r, cond)
            print(f"{'ON' if pity else 'OFF':<4}| {X} | {r['won']:5.2f}% {wilson(r['won'], n):<19}| {r['st_n']:4d}    | "
                  f"{r['st_reached']:5.1f}% / {r['st_won']:5.2f}% {wilson(r['st_won'], r['st_n']):<15}| {cond:5.1f}%",
                  flush=True)
        print()

    # 【D2】G2上昇の成分分解（裏天井ON・gate有）: ΔG2 ≒ 停滞層シェア×Δ停滞層優勝 か
    print("【D2】G2上昇の成分分解 [裏天井ON・gate有] 全体優勝 = 停滞層寄与 + 非停滞層寄与")
    r0, _ = rows_on[0]
    base_st_contrib = r0["st_won"] * r0["st_n"] / n
    base_rest = r0["won"] - base_st_contrib
    print(f"{'X':<3}| G2     | 停滞層寄与(st_won×st_n/n) | 非停滞層寄与 | ΔG2(vs X=0) | Δのうち停滞層分")
    print("-" * 96)
    for X in XS:
        r, _ = rows_on[X]
        st_contrib = r["st_won"] * r["st_n"] / n
        rest = r["won"] - st_contrib
        print(f"{X:<3}| {r['won']:5.2f}% | {st_contrib:5.2f}pt                   | {rest:5.2f}pt      | "
              f"{r['won'] - r0['won']:+5.2f}pt     | {st_contrib - base_st_contrib:+5.2f}pt", flush=True)
    print()

    # 【E】G1側（のんびり改・0pt初回帯・裏天井ON・gate有）: 不動の確認
    print("【E】G1不動確認 [のんびり改・0pt初回帯・裏天井ON・gate有]")
    print(f"{'X':<3}| 全体 到達/優勝(G1) 95%CI          | 停滞層n | 停滞層 到達/優勝")
    print("-" * 80)
    for X in (0, 2, 4):
        r = G.scan(PCasual2, n, True, 0, 20, IA0, CS0, X, gate=True)
        print(f"{X:<3}| {r['final']:5.1f}% / {r['won']:5.2f}% {wilson(r['won'], n):<14}| {r['st_n']:4d}    | "
              f"{r['st_reached']:5.1f}% / {r['st_won']:5.2f}%", flush=True)
    print()

    # 【F】G3のCI（30ptやり込み・裏天井ON・gate有）: 小標本(停滞層n≈43)の明示
    print("【F】G3とCI [30ptやり込み(SSR相方)・裏天井ON・gate有] 基準G3≈62.1%")
    print(f"{'X':<3}| 全体優勝(G3) 95%CI          | 停滞層n | 停滞層 最終年 優勝 95%CI")
    print("-" * 84)
    for X in XS:
        r = G.scan(PSpread, n, True, 30, CAP30, IA30, CS30, X, gate=True)
        print(f"{X:<3}| {r['won']:5.2f}% {wilson(r['won'], n):<19}| {r['st_n']:4d}    | "
              f"{r['st_won']:6.2f}% {wilson(r['st_won'], r['st_n'])}", flush=True)


if __name__ == "__main__":
    main()
