#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ネタ補正をアプリ（GameCore）と同じ式で測り直す（2026-10-14・AUTOPILOT キュー50）
- 旧 exp_neta は sim_career の旧v0「新鮮さ fresh」版で測っていた。アプリは buzz 版（NETA_V2・sim_career 冒頭のコメント）
- 計測：基準（ネタ層なし）／旧v0／アプリ同式（いちばん点の高いネタを必ず掛ける）／アプリ同式・マイナスなら掛けない／アプリ同式・ランダム
- 使い方: python3 exp_neta_v2.py [キャリア数]（省略時 300）。要約は1行ずつ。数値は全て【仮】
"""

import statistics
import sys

import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from bots_v3 import PNeedV3, PRotate

CONFIGS = [
    ("基準（ネタ層なし）",            dict()),
    ("旧v0（fresh版）",               dict(NETA_ON=True)),
    ("アプリ同式・必ず掛ける",        dict(NETA_ON=True, NETA_V2=True)),
    ("アプリ同式・マイナスは掛けない", dict(NETA_ON=True, NETA_V2=True, NETA_SKIP_NEGATIVE=True)),
    ("アプリ同式・ランダム",          dict(NETA_ON=True, NETA_V2=True, NETA_RANDOM_PICK=True)),
]
FLAGS = ("NETA_ON", "NETA_V2", "NETA_SKIP_NEGATIVE", "NETA_RANDOM_PICK")


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    print(f"=== ネタ補正 アプリ同式の再計測 | {n}キャリア/設定 | シード{C.BASE_SEED} | 全て【仮】 ===")
    saved = {k: getattr(C, k) for k in FLAGS}
    saved_on = C.EVENTS_ON
    V.apply()   # いまの正典（v3 経験点）。exp_places_v1 と同じ回し方
    try:
        C.EVENTS_ON = True
        for label, flags in CONFIGS:
            for k in FLAGS:
                setattr(C, k, flags.get(k, False))
            for pol in (PCasual2(), PRotate(), PNeedV3()):
                wins, finals, win_years = 0, 0, []
                for i in range(n):
                    first, _s, _stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
                    if first is not None:
                        wins += 1
                        win_years.append(first)
                    finals += ever_final
                med = statistics.median(win_years) if win_years else None
                print(f"{label}｜{pol.name}｜優勝 {100.0*wins/n:5.2f}% 決勝到達 {100.0*finals/n:5.1f}% 初優勝中央値 {med}年")
    finally:
        V.reset()
        C.EVENTS_ON = saved_on
        for k, v in saved.items():
            setattr(C, k, v)


if __name__ == "__main__":
    main()
