#!/usr/bin/env python3
"""キュー93：経験点の配り方の調整（間合いが余らない）の実測。usage: python3 exp_exp_rebalance_v0.py [n=300] [variants=all]
式・既定値は変えない（案はこのスクリプト内の差し替えだけ。終了時に全部戻す）。数値は全て【仮】。
前提・ボット・詰まりの定義は exp_ability_stall_v0（ネタ込み NETA_ON/NETA_V2・イベント・場所・有料休み・知名度案G）と同じ。
案（オーナー 10/18 2b-回答2：交換は使わない・配り方で直す）:
  A   今のまま
  S   供給の付け替え：ネタ作り 閃3/語2・喫茶 閃3.5/語2.5・ファミレス 閃3/語2・勉強会 閃4/語5・ネタ見せ会 間4/胆3・ネタ合わせ 間2
  R   配合の付け替え（間合いを使う能力を増やす）：センス 閃.35/間.45/胆.20・表現 語.25/間.75・華 存.60/閃.20/間.20
  SR  S と R の両方
  R2  配合の需要比を供給比に合わせる（RECIPE2）
  「@x」は供給スケール EXP_SUPPLY_SCALE を x 倍（詰まりが消えて伸びた分を戻す）"""
import sys, copy
import balance_sim as B
import sim_career as C
import canon_v2 as V
import bots_v3
import exp_ability_stall_v0 as S
from exp_human import PCasual2
from bots_v3 import PRotate
from exp_places_v1 import Cafe
from exp_rests_v1 import Spa

SUPPLY = {
    "ネタ作り": (("cur:hirameki", 3), ("cur:goi", 2)),
    "喫茶店で書く": (("cur:hirameki", 3.5), ("cur:goi", 2.5)),
    "ファミレスで書く": (("cur:hirameki", 3), ("cur:goi", 2)),
    "作家の勉強会": (("cur:hirameki", 4), ("cur:goi", 5)),
    "ネタ見せ会": (("cur:maai", 4), ("cur:tanryoku", 3)),
    "ネタ合わせ": (("cur:maai", 2), None),  # sub(compat) はそのまま
}
RECIPE = {
    "sense": [("hirameki", 0.35), ("maai", 0.45), ("tanryoku", 0.20)],
    "expr": [("goi", 0.25), ("maai", 0.75)],
    "chara": [("sonzaikan", 0.60), ("hirameki", 0.20), ("maai", 0.20)],
}

# R2：配合の需要比を供給比（閃.23 語.08 間.31 存.09 胆.28・ローテ近似）に合わせる＝間合い・胆力を多くの能力で使う
RECIPE2 = {
    "sense": [("hirameki", 0.35), ("maai", 0.40), ("tanryoku", 0.25)],
    "idea": [("hirameki", 0.60), ("goi", 0.25), ("maai", 0.15)],
    "expr": [("goi", 0.20), ("maai", 0.60), ("tanryoku", 0.20)],
    "chara": [("sonzaikan", 0.50), ("hirameki", 0.20), ("maai", 0.30)],
    "mental": [("sonzaikan", 0.20), ("tanryoku", 0.80)],
}

def patch(v):
    saved = dict(tr=copy.deepcopy(B.TRAININGS), ptr=copy.deepcopy(B.PLACE_TRAININGS), rec=copy.deepcopy(B.ABILITY_RECIPE))
    if "S" in v:
        for name, (main, sub) in SUPPLY.items():
            for tbl in (B.TRAININGS, B.PLACE_TRAININGS):
                if name in tbl:
                    tbl[name]["main"] = main
                    if sub is not None: tbl[name]["sub"] = sub
    if "R2" in v:
        B.ABILITY_RECIPE.update(copy.deepcopy(RECIPE2))
    elif "R" in v:
        B.ABILITY_RECIPE.update(copy.deepcopy(RECIPE))
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
    return saved

def unpatch(saved):
    B.TRAININGS.clear(); B.TRAININGS.update(saved["tr"])
    B.PLACE_TRAININGS.clear(); B.PLACE_TRAININGS.update(saved["ptr"])
    B.ABILITY_RECIPE.clear(); B.ABILITY_RECIPE.update(saved["rec"])
    bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["A", "S", "R", "SR", "S@0.8", "SR@0.8", "SR@0.7"]
    modes = sys.argv[3].split(",") if len(sys.argv) > 3 else ["auto", "hand"]
    saved = {k: getattr(C, k) for k in S.KEYS if hasattr(C, k)}
    offr0 = list(B.OFFER_RATES)
    V.apply(); C.EVENTS_ON = True; C.NETA_ON = C.NETA_V2 = True
    for k, v in S.PRE.items(): setattr(C, k, v)
    B.OFFER_RATES = S.OFFER_NEW
    B.enable_places(True); B.enable_paid_rests(True)
    try:
        bots = [Spa(Cafe(PCasual2())), Spa(Cafe(PRotate())), C.CareerBalanced(), C.CareerSmart()]
        print(f"# n={n} careers/bot ネタ込み  stall=週末に経験点>=5 かつ伸び余地 かつ押せる＋0")
        for var in variants:
            base, _, sc = var.partition("@")
            sv = patch(base)
            try:
                for b in bots:
                    for mode in modes:
                        r = S.measure(b, n, mode, "A" + (f"@{sc}" if sc else ""))
                        print(f"RESULT|{var}|{b.name}|{mode}|win={r['win']:.1f}|fin={r['fin']:.1f}|ds={r['ds']:.1f}|"
                              f"st_y1={r['st_y1']:.1f}|st_y13={r['st_y13']:.1f}|slen={r['slen']:.1f}|"
                              f"bal={'/'.join(f'{x:.1f}' for x in r['bal'])}|unsp={'/'.join(f'{x:.0f}' for x in r['unspent'])}|"
                              f"ab3={'/'.join(f'{x:.0f}' for x in r['ab3'])}|j1={r['j1']:.1f}|j3={r['j3']:.1f}", flush=True)
            finally:
                unpatch(sv)
    finally:
        B.enable_places(False); B.enable_paid_rests(False)
        B.OFFER_RATES = offr0
        bots_v3.ISSUE = {t: bots_v3._issue(t) for t in B.TRAININGS}
        V.reset()
        for k, v in saved.items(): setattr(C, k, v)

if __name__ == "__main__":
    main()
