#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GoldenTests.swift の12週台本の期待値を Swift の貼れる形で標準出力に出す（キュー108）。
使い方: cd tools && python3 gen_golden12.py  → 出力行で GoldenTests.swift の script 表を置き換える。
手順: docs/gamecore_design.md「golden値の再生成」。同期確認は check_golden_sync.py。"""
import balance_sim as B
import sim_career as C
import exp_decay

# GoldenTests.swift の script と同じ12手（種別, 名前）
SCRIPT = [
    ("train", "ネタ作り"), ("train", "ネタ合わせ"), ("train", "フリーライブ"),
    ("job", "標準"), ("rest", "完全休養"), ("train", "ネタ見せ会"),
    ("train", "ランニング・サウナ"), ("job", "キツい"), ("rest", "相方と過ごす"),
    ("train", "ネタ作り"), ("job", "楽"), ("rest", "気分転換"),
]
FIELDS = [("money", "money"), ("stamina", "stamina"), ("fame", "fame"), ("sense", "sense"),
          ("idea", "idea"), ("expr", "expr"), ("chara", "chara"), ("mental", "mental"),
          ("compat", "compat")]


def num(v, is_int):
    if is_int:
        return str(int(v))
    return str(int(v)) if float(v).is_integer() else repr(float(v))


def rows():
    exp_decay.install_decay(120)
    s = B.S()
    out = []
    for week, (kind, name) in enumerate(SCRIPT, 1):
        if kind == "train":
            assert B.do_training(s, name), f"week {week}: 稽古費が払えない"
        elif kind == "job":
            B.do_job(s, name)
        else:
            B.do_rest(s, name)
        B.pour_all(s)
        if week % B.LIVING_INTERVAL == 0:
            B.pay_living(s)
            if C.DEBT_LIFE_PEN is not None and s.money < 0:   # 生活苦（Swift applyWeekEnd・gen_golden.py と同じ）
                dst, dmt = C.DEBT_LIFE_PEN
                B.add(s, "stamina", dst)
                B.add(s, "mental", dmt)
        body = ", ".join(f"{sw}: {num(getattr(s, py), sw == 'money')}" for sw, py in FIELDS)
        out.append(f"(.{kind}(.{name}), Expected({body})),")
    return out


if __name__ == "__main__":
    print("\n".join(rows()))
