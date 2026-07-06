#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
感度実験: 突発イベント層の総量予算（docs/dialogue_batch3_v0.md §8 の根拠データ）
- 正典バランスは「18種プール・キャリア内1回制」で計測済み（event_design_v0 §4-B: 初回優勝1.55%）
- 会話量産（batch3）で効果つきイベントが33種に増えると、1回制でも総バフ量が増えて易化する
- 対策案: EVENT_FIRE_CAP=18（効果発火はキャリア通算18回まで・超過分はフレーバー表示のみ）
  → プールが何種に増えても正典の効果予算を維持できるかを本実験で確認する
- 使い方: python3 exp_events.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】
"""

import sys

import sim_career as C

# batch3 の効果つきイベント15種の代表近似（dialogue_batch3_v0.md §5〜§6。効果の帯は既存18種と同じ小粒に揃える）
BATCH3_TABLE = [
    (5_000,  0, 0, None, 0),        # 流木拾いの休日（飛び道具バイト）
    (8_000, -5, 0, "idea", 1),      # 気球監視員（沈黙の8時間）
    (0,      0, 0, "mental", 1),    # 谷口との喧嘩→翌週回収（正味）
    (0,      0, 0, "sense", 1),     # 喫茶店マスターの一言
    (-1_500, 0, 0, "mental", 2),    # 験担ぎのカツ
    (0,      5, 0, None, 0),        # 銭湯の番台のサービス
    (-15_000, 0, 0, None, 0),       # 家電が壊れる
    (0,      0, 1, "chara", 1),     # アンコール少年・再来
    (0,     -5, 0, "expr", 2),      # 構成作家のダメ出し
    (0,      0, 0, "idea", 2),      # ネタ泥棒疑惑の逆転
    (20_000, 0, 0, None, 0),        # 谷口バイト表彰の臨時ボーナス
    (0,     10, 0, None, 0),        # 谷口の家族の差し入れ
    (0,      0, 0, "mental", -3),   # 行きつけ銭湯の閉店
    (0,      0, 2, None, 0),        # 路上ライブが配信に映り込む
    (-10_000, 0, 0, "sense", 2),    # 中古の名作ライブ映像全集
]

CONFIGS = [
    ("A 正典: 18種・1回制・上限なし",            C.EVENT_TABLE,                None),
    ("B 増量: 33種・1回制・上限なし",            C.EVENT_TABLE + BATCH3_TABLE, None),
    ("C 増量+予算: 33種・1回制・通算18回",       C.EVENT_TABLE + BATCH3_TABLE, 18),
    ("D 増量+予算: 33種・1回制・通算15回【採用】", C.EVENT_TABLE + BATCH3_TABLE, 15),
]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    print(f"=== イベント総量予算の検証 | {n}キャリア/設定 | シード{C.BASE_SEED} | "
          f"決勝{C.GP_FINAL_LINE:.0f}・準決{C.GP_ROUNDS[-1][1]:.0f} | 全て【仮】 ===")
    print("判定: Cの優勝率がAの帯（1.5〜2.8%）に収まれば、プール増量は上限だけで吸収できる")
    print()
    saved_table, saved_cap, saved_on = C.EVENT_TABLE, C.EVENT_FIRE_CAP, C.EVENTS_ON
    try:
        C.EVENTS_ON = True
        for label, table, cap in CONFIGS:
            C.EVENT_TABLE = table
            C.EVENT_FIRE_CAP = cap
            print(f"== {label} ==")
            for cls in C.BOTS:
                pol = cls()
                wins = finals = 0
                for i in range(n):
                    first, _s, _stage, ever_final = C.run_career(pol, C.BASE_SEED + i)
                    wins += first is not None
                    finals += ever_final
                print(f"  {pol.name:　<7}| 10年内優勝 {100.0*wins/n:5.2f}% / 決勝到達 {100.0*finals/n:5.1f}%")
            print()
    finally:
        C.EVENT_TABLE, C.EVENT_FIRE_CAP, C.EVENTS_ON = saved_table, saved_cap, saved_on

if __name__ == "__main__":
    main()
