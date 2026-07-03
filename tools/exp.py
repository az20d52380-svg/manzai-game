#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""感度実験: 通過ライン / 交通手段 / 相性成長 が結果にどう効くか"""
import balance_sim as B

N = 2000

def run(pol_cls, **over):
    saved = {k: getattr(B, k) for k in over}
    for k, v in over.items():
        setattr(B, k, v)
    r = B.simulate(pol_cls, N)
    for k, v in saved.items():
        setattr(B, k, v)
    return r

class Bus(B.PBalanced):
    name = "強制バス"
    def transport(self, s):
        return B.BUS

class Shin(B.PBalanced):
    name = "強制新幹線"
    def transport(self, s):
        return B.TRAIN

print("== 実験1: 大阪戎の通過ライン感度（バランス型） ==")
for line in (30, 35, 40, 45):
    r = run(B.PBalanced, OSAKA_LINE=line)
    print(f"  ライン{line}: 通過 {r['osaka_win']:5.1f}%")

print("== 実験2: 交通手段の差（ライン40・バランス型） ==")
for cls in (Bus, Shin):
    r = run(cls)
    print(f"  {cls.name}: 通過 {r['osaka_win']:5.1f}% / 最終所持金 {B.yen(r['money'])}")

print("== 実験3: 相性成長のON/OFF（バランス型） ==")
for flag in (True, False):
    r = run(B.PBalanced, COMPAT_GROWS=flag)
    print(f"  成長{'あり(上限20)' if flag else 'なし(固定+5) '}: 戎通過 {r['osaka_win']:5.1f}% / GP予選 {r['gpq']:4.1f}%")

print("== 実験4: GP予選ラインの感度（バランス型） ==")
for line in (45, 50, 55, 60):
    r = run(B.PBalanced, GPQ_LINE=line)
    print(f"  ライン{line}: 予選通過 {r['gpq']:5.1f}%")
