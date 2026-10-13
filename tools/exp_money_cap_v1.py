#!/usr/bin/env python3
"""money_items_neta_v1 §6-4 の判断待ち②「年の回数上限」を実測（決定ではない・数値は全て【仮】）。
usage: python3 exp_money_cap_v1.py [n] [上限,...] [期間の週数（4=月・48=年）]
exp_money_all_v1 の「全部あり」と同じボットに、有料の行動（練習の場所・教室・サウナ・温泉）ごとに「月（4週）k回まで」の上限をかける。
上限に当たったら無料の同系統に置き換える（喫茶店・ファミレス・勉強会→ネタ作り／ボイトレ→フリーライブ／サウナ・温泉→完全休養）。"""
import sys
import balance_sim as B
import canon_v2 as V
import bots_v3
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate
from exp_places_v1 import Cafe, run
from exp_rests_v1 import Spa

FALLBACK = {"喫茶店で書く": "ネタ作り", "ファミレスで書く": "ネタ作り", "作家の勉強会": "ネタ作り", "ボイトレ": "フリーライブ",
            "サウナ": "完全休養", "温泉に一泊": "完全休養"}

class Cap:
    def __init__(self, base, k, period=4):
        self.base, self.k, self.period = base, k, period; self.name = base.name; self.key = None; self.used = {}
    def __getattr__(self, a):
        return getattr(self.base, a)
    def choose(self, s, week, offer, rng):
        act, arg = self.base.choose(s, week, offer, rng)
        key = (id(s), week, getattr(s, "year", None))
        if self.key is None or key[0] != self.key[0] or week < self.key[1]:
            self.used = {}          # 新しいキャリア／新しい年
        self.key = key
        if arg in FALLBACK:
            m = (arg, (week - 1) // self.period)
            if self.used.get(m, 0) >= self.k:
                return (act, FALLBACK[arg])
            self.used[m] = self.used.get(m, 0) + 1
        return (act, arg)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    ks = [int(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else [1, 2]
    per = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    lab = "月" if per == 4 else ("年" if per == 48 else f"{per}週")
    V.apply()
    try:
        B.enable_places(True); B.enable_paid_rests(True)
        bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
        for k in ks:
            for pol in (Cap(Spa(Cafe(PCasual2())), k, per), Cap(Spa(Cafe(PRotate())), k, per), Cap(Spa(PNeedV3()), k, per)):
                w, f, m = run(pol, n)
                print(f"{lab}{k}回まで\t{pol.name}\t初回優勝{w:.1f}%\t決勝到達{f:.1f}%\t最終所持金{m:.0f}万", flush=True)
    finally:
        B.enable_places(False); B.enable_paid_rests(False)
        bots_v3.ISSUE = {k: bots_v3._issue(k) for k in B.TRAININGS}
        V.reset()

if __name__ == "__main__":
    main()
