#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 人間プレイヤー近似（下手な・偏ったボット）の初回キャリア分布
- 検証台帳の残項目「人間プレイヤー補正」への回答。既存2ボット（バランス型・調整型）は最適寄り＝上限。
  下限と偏りを測るため、初見の人間にありがちな4プレイスタイルを追加して同条件（イベント込み正典）で回す:
    ランダム型   … 毎週その場の思いつき（balance_sim.PRandom流用）
    バイト特化   … 金だけ稼ぐ。稽古ゼロ（balance_sim.PWork流用）
    稽古特化     … 無料稽古だけ回す。金策ゼロ（balance_sim.PTrain流用）
    のんびり型   … 初見近似。体力が尽きてから休む・有料稽古は貯金が潤沢な時だけ・オファーは必ず受ける
- 使い方: python3 exp_human.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import statistics
import sys

import balance_sim as B
import sim_career as C

class PCasual(B.Policy):
    """のんびり型: 初見プレイヤーの近似。計画性がなく、反応的にしか動かない"""
    name = "のんびり型"

    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)          # オファーは光って見えるので必ず受ける
        if s.stamina < 25:
            return ("rest", "完全休養")     # 尽きてから休む（事前調整をしない）
        if s.money < 100_000:
            return ("job", "標準")          # 金が減ると不安になって働く
        if week % 5 == 0:
            return ("rest", "気分転換")     # なんとなく休む週
        if s.money >= 800_000:
            return ("train", "ネタ見せ会")  # 貯金が潤沢な時だけ有料稽古に手を出す
        return ("train", B.FREE_ROT[week % 3])

    def transport(self, s):
        return B.TRAIN if s.money >= 100_000 else B.BUS

class PCasual2(PCasual):
    """のんびり改: のんびり型＋「大会バッジを見て前週に休む」だけ覚えた初心者（UIが教える最低限）"""
    name = "のんびり改"

    def choose(self, s, week, offer, rng):
        if (week + 1) in C.EVENT_WEEKS and s.stamina < 60:
            return ("rest", "完全休養")
        return super().choose(s, week, offer, rng)

HUMAN_BOTS = (B.PRandom, B.PWork, B.PTrain, PCasual)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    print(f"=== 人間近似ボットの初回キャリア | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"イベント込み正典(決勝{C.GP_FINAL_LINE:.0f}) | 全て【仮】 ===")
    print("比較: 最適寄りボット(バランス型/調整型)=優勝1.50〜1.55%・決勝25〜35%が上限帯")
    print()
    saved_on = C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        for cls in tuple(C.BOTS) + HUMAN_BOTS:
            pol = cls()
            wins = finals = 0
            stages, jitsus, moneys = [], [], []
            for i in range(n):
                first, s, best_stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
                if first is not None:
                    wins += 1
                finals += ever_final
                stages.append(best_stage)
                jitsus.append(B.jitsuryoku(s))
                moneys.append(s.money)
            med_stage = statistics.median(stages)
            dist = [100.0 * sum(1 for x in stages if x >= k) / n for k in range(1, 6)]
            print(f"== {pol.name} ==")
            print(f"  優勝 {100.0*wins/n:5.2f}% / 決勝到達 {100.0*finals/n:5.1f}% / 最高到達回戦中央値 {med_stage:.1f}")
            print(f"  回戦到達率: 1回戦突破 {dist[0]:.0f}% / 2回戦 {dist[1]:.0f}% / 3回戦 {dist[2]:.0f}% / "
                  f"準々 {dist[3]:.0f}% / 準決突破 {dist[4]:.0f}%")
            print(f"  10年目実力値中央値 {statistics.median(jitsus):.1f} / 最終所持金中央値 {B.yen(statistics.median(moneys))}")
            print(flush=True)
    finally:
        C.EVENTS_ON = saved_on

if __name__ == "__main__":
    main()
