#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GameCore同期用 golden生成器【正典v2 2026-07-05改訂】
- SwiftのSplitMix64と同一実装の乱数で、大会・グランプリ・オファー込みの3年を決定的に実行し、
  週ごとの全状態をSwiftテスト用リテラルとして出力する
- ここで定義する「乱数消費と週処理の順序」が正典。GameCore/Sources/GameCore/Career.swift（と WeekRunner.swift）は必ずこれに従う:
   0) 年初: 体力全回復 → 成長予算の更新（キャリア累計 = Σ_{k=1..min(年,15)} max(2.0, 6.0−0.4×(k−1))・乱数消費なし・使用量はリセットしない）
   1) 大会週: 出場判定(資格→大阪なら交通費支払可否)→ perform(2draw: 出来ブレ→ハマった夜)
   2) 1)で行動していなければ GP回戦週: perform(2draw)
   3) 第47週: 敗者復活なら perform(2draw)→通過で決勝へ / 決勝進出なら perform(2draw)
   4) ここまで無行動なら: オファー抽選(1draw、当選時さらに1draw)
      → 療養中なら完全休養(残週-1・消費なし・オファーは受けられない)
      → 当選していれば受諾
      → 非当選: 週パターンの行動に体力ゲート(体力20未満の稽古→完全休養に差し替え・消費なし)
        → 体調ダウン判定(体力20未満のキツいバイトのみ1draw。発生時: 完全休養+メンタル-5・以後2週療養)
        → 実行（有料稽古が払えない時は完全休養にフォールバック。借金中は稽古効果×0.5）
   5) 週末: 4週ごとに生活費 → 所持金<0なら生活苦(体力-10/メンタル-3) → -100万未満で夜逃げ(キャリア終了。goldenシードでは起きない前提=assert)
- perform = 出来ブレuniform(±B) 1draw → ハマった夜判定 1draw（10%で+12）。この2draw構造は全本番共通
- 使い方: python3 gen_golden.py > /tmp/golden.txt  → CareerGoldenTests.swift に貼る
"""

import balance_sim as B
import sim_career as C

MASK = (1 << 64) - 1

class SplitMix64:
    """Swift実装 (RandomSource.swift) と同一。random()の値もビット一致する"""
    def __init__(self, seed):
        self.state = seed & MASK

    def next_u64(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return z ^ (z >> 31)

    def random(self):
        return (self.next_u64() >> 11) * (1.0 / 9007199254740992.0)

    def uniform(self, a, b):
        return a + (b - a) * self.random()

    def choice(self, seq):
        return seq[min(int(self.random() * len(seq)), len(seq) - 1)]

# 週パターン（10週周期・Swiftテストと同一の並び）
PATTERN = [("train", "ネタ作り"), ("train", "ネタ合わせ"), ("job", "標準"),
           ("rest", "完全休養"), ("train", "フリーライブ"), ("job", "キツい"),
           ("rest", "気分転換"), ("train", "ネタ見せ会"), ("job", "楽"),
           ("rest", "相方と過ごす")]

def year_budget(year):
    base, slope, floor = C.CAP_CURVE
    return sum(max(floor, base - slope * (k - 1)) for k in range(1, min(year, C.GROWTH_END_YEAR) + 1))

def run_year(s, year, rng, log=None):
    s.stamina = 100.0
    B.YEAR_GROWTH_CAP = year_budget(year)   # キャリア累計予算（s._ygはリセットしない）
    gp_stage, gp_alive, finalist, revival = 0, True, False, False
    for week in range(1, B.WEEKS + 1):
        acted = False

        t = C.TOURNAMENTS.get(week)
        if t and t["ok"](year, s):
            can_pay = (not t["osaka"]) or s.money >= B.BUS["cost"]
            if can_pay:
                if t["osaka"]:
                    s.money -= B.BUS["cost"]
                    B.add(s, "stamina", B.BUS["stam"])
                ok, _ = B.perform(s, t["line"], rng)
                if ok:
                    s.money += t["prize"]
                    B.add(s, "fame", t["fame"])
                acted = True

        if not acted and gp_alive and gp_stage < len(C.GP_ROUNDS) and week == C.GP_ROUNDS[gp_stage][0]:
            ok, _ = B.perform(s, C.GP_ROUNDS[gp_stage][1], rng)
            acted = True
            if ok:
                B.add(s, "fame", C.GP_ROUND_FAME)
                gp_stage += 1
                if gp_stage == len(C.GP_ROUNDS):
                    finalist = True
            else:
                if gp_stage == len(C.GP_ROUNDS) - 1:
                    revival = True
                gp_alive = False

        if week == C.GP_FINAL_WEEK:
            if revival:
                ok, _ = B.perform(s, C.GP_REVIVAL_LINE, rng)
                acted = True
                if ok:
                    B.add(s, "fame", C.GP_ROUND_FAME)
                    finalist = True
            if finalist:
                eff_line = C.GP_FINAL_LINE - C.FAME_FINAL_BONUS * (s.fame - 50) / 50
                ok, _ = B.perform(s, eff_line, rng)
                acted = True
                if ok:
                    s.money += C.GP_PRIZE
                    B.add(s, "fame", C.FAME_CHAMP)
                    return True

        if not acted:
            offer = B.roll_offer(s, rng)
            if getattr(s, "_inj", 0) > 0:
                s._inj -= 1                       # 療養中（オファーは受けられない）
                B.do_rest(s, "完全休養")
            elif offer is not None:
                B.do_offer(s, offer)
            else:
                act, arg = PATTERN[(week - 1) % len(PATTERN)]
                if act == "train" and s.stamina < C.STAMINA_GATE:
                    act, arg = "rest", "完全休養"   # 体力ゲート（谷口が止める）
                if s.stamina < C.INJURY_TH and (act == "train" or (act == "job" and arg == "キツい")):
                    if rng.random() < (C.INJURY_TH - s.stamina) * C.INJURY_P_PER:
                        act, arg = "rest", "完全休養"   # 体調ダウン発生
                        s._inj = C.INJURY_REST - 1
                        B.add(s, "mental", C.INJURY_MENTAL)
                if act == "train":
                    if not B.do_training(s, arg):
                        B.do_rest(s, "完全休養")
                elif act == "job":
                    B.do_job(s, arg)
                else:
                    B.do_rest(s, arg)

        if week % B.LIVING_INTERVAL == 0:
            s.money -= B.LIVING_COST
            if C.DEBT_LIFE_PEN is not None and s.money < 0:
                dst, dmt = C.DEBT_LIFE_PEN
                B.add(s, "stamina", dst)
                B.add(s, "mental", dmt)
            assert s.money >= C.BANKRUPT_LINE, f"goldenシードで夜逃げが発生（{year}年{week}週）。シードを変えること"

        if log is not None:
            log.append((year, week, s))
            log[-1] = (year, week, snapshot(s))
    return False

def snapshot(s):
    return (s.money, s.stamina, s.fame, s.sense, s.idea, s.expr, s.chara, s.mental, s.compat)

def swift_row(year, week, snap):
    money, rest = snap[0], snap[1:]
    vals = ", ".join(f"{v!r}" for v in rest)
    return f"        ({year}, {week}, {money}, {vals}),"

def main():
    seed = 424242
    rng = SplitMix64(seed)
    s = B.S()
    print(f"// gen_golden.py seed={seed} / 正典v2: 準決{C.GP_ROUNDS[-1][1]} 決勝{C.GP_FINAL_LINE} 復活{C.GP_REVIVAL_LINE} "
          f"/ 上限カーブ{C.CAP_CURVE} ハマ{B.BURST_P}/{B.BURST_BONUS} / D={B.GROWTH_DECAY_D}")
    print("// (year, week, money, stamina, fame, sense, idea, expr, chara, mental, compat)")
    log = []
    for year in (1, 2, 3):
        champion = run_year(s, year, rng, log if year == 1 else None)
        assert not champion, f"golden用シードで{year}年目に優勝してしまった。シードを変えること"
        if year == 1:
            for y, w, snap in log:
                print(swift_row(y, w, snap))
        else:
            print(f"// year {year} end:")
            print(swift_row(year, 48, snapshot(s)))

if __name__ == "__main__":
    main()
