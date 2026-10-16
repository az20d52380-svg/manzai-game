#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GoldenTests.swift（12週台本・乱数不使用・エンジン単体＝成長予算なし）の期待値を Python 正典から出す。
使い方: cd tools && python3 gen_golden_12wk.py  → script の Expected(...) 行と末尾の派生値を GoldenTests.swift に貼る。
（CLAUDE.md 規律A: golden は手で書かない。docs/gamecore_design.md「golden値の再生成」の手順を切り出したもの）"""
import balance_sim as B
import sim_career as C

SCRIPT = [("train", "ネタ作り"), ("train", "ネタ合わせ"), ("train", "フリーライブ"), ("job", "標準"),
          ("rest", "完全休養"), ("train", "ネタ見せ会"), ("train", "ランニング・サウナ"), ("job", "キツい"),
          ("rest", "相方と過ごす"), ("train", "ネタ作り"), ("job", "楽"), ("rest", "気分転換")]

def main():
    s = B.S()
    s._yg = 0.0
    yc = B.YEAR_GROWTH_CAP
    B.YEAR_GROWTH_CAP = None   # GameConfig() 既定の growthBudget=nil（エンジン単体）
    try:
        for week, (act, arg) in enumerate(SCRIPT, 1):
            if act == "train":
                assert B.do_training(s, arg), f"week {week}: 稽古費が払えない想定外"
            elif act == "job":
                B.do_job(s, arg)
            else:
                B.do_rest(s, arg)
            B.pour_all(s)
            if week % B.LIVING_INTERVAL == 0:
                s.money -= B.LIVING_COST
                if s.money < 0 and C.DEBT_LIFE_PEN is not None:
                    B.add(s, "stamina", C.DEBT_LIFE_PEN[0]); B.add(s, "mental", C.DEBT_LIFE_PEN[1])
            f = lambda v: repr(v) if v != int(v) else str(int(v))
            print(f"Expected(money: {s.money}, stamina: {f(s.stamina)}, fame: {f(s.fame)}, sense: {f(s.sense)}, "
                  f"idea: {f(s.idea)}, expr: {f(s.expr)}, chara: {f(s.chara)}, mental: {f(s.mental)}, compat: {f(s.compat)})")
        print(f"blurWidth {B.blur_width(s.mental)!r}")
        print(f"jitsuryoku {B.jitsuryoku(s)!r}")
    finally:
        B.YEAR_GROWTH_CAP = yc

if __name__ == "__main__":
    main()
