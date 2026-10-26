#!/usr/bin/env python3
"""確定で出るイベント7種（justlost/styletalk/passfork/eve/tsuuka/early/tani）の効き目を、効果の種類ごとに外して分解する
（events_app_ablation_v0 §3「未検証：どの経路が一番効くか」の続き）。usage: python3 exp_det_path_v0.py [n]
EVENTS_APP=True・全部入り・ネタ込み（exp_money_after_merge_v0.one）。研究用・golden 不変。結果は docs/det_event_path_1026_v0.md。"""
import sys
from multiprocessing import Pool

DET = {"justlost", "styletalk", "passfork", "eve", "tsuuka", "early", "tani"}
CASES = {"今": set(), "能力なし": {"sense", "idea", "expr", "chara"}, "相性なし": {"compat"}, "メンタルなし": {"mental"},
         "知名度なし": {"fame"}, "お金なし": {"money"}, "体力なし": {"stamina"},
         "全部なし": {"sense", "idea", "expr", "chara", "compat", "mental", "fame", "money", "stamina"}}
BOTS = ["PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]

def one(args):
    case, bot, n = args
    import sim_career as C, exp_money_after_merge_v0 as M
    C.EVENTS_APP = True
    off = CASES[case]; st = {"in": False}
    oe, oapp = C._ev_add, C._app_apply
    def ev(s, key, amt):
        if st["in"] and key in off: return
        return oe(s, key, amt)
    def app(s, k):
        if k not in DET: return oapp(s, k)
        st["in"] = True; m0 = s.money
        try: return oapp(s, k)
        finally:
            st["in"] = False
            if "money" in off: s.money = m0
    C._ev_add, C._app_apply = ev, app
    _, _, _, r = M.one(("all", True, bot, n))
    return case, bot, r

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, [(c, b, n) for c in CASES for b in BOTS], chunksize=1)
    print("| 外した効果 | ボット | 優勝% | 決勝% | 10年目所持金の中央(万) |")
    print("|---|---|---|---|---|")
    for c, b, r in res:
        print(f"| {c} | {b[:8]} | {r['win']:.1f} | {r['fin']:.1f} | {r['y10'][1]:.0f} |")
