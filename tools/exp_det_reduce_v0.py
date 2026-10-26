#!/usr/bin/env python3
"""判断 §3 の案B（確定で出るイベントの効き目を下げる）の当て先候補で、帯が EVENTS_APP=False（これまでの物差し）に戻るか。
usage: python3 exp_det_reduce_v0.py [n]   全部入り・ネタ込み。研究用・golden 不変。結果は docs/det_event_path_1026_v0.md §案B。"""
import sys
from multiprocessing import Pool

ABIL = {"sense", "idea", "expr", "chara"}
CASES = ["旧の物差し", "今", "B1 能力+2→+1", "B2 結成初期の相性+2→+1", "B1+B2", "B1+B2+負けた後の相性+2→+1"]
BOTS = ["PRotate", "PNeedV3", "金→力 全振り(やり込み改)"]

def one(args):
    case, bot, n = args
    import sim_career as C, exp_money_after_merge_v0 as M
    C.EVENTS_APP = case != "旧の物差し"
    st = {"k": None}
    oe, oapp = C._ev_add, C._app_apply
    b1 = case.startswith("B1"); b2 = "B2" in case; b3 = "負けた後" in case
    def ev(s, key, amt):
        k = st["k"]
        if k in ("justlost", "styletalk", "tsuuka") and b1 and key in ABIL and amt == 2: amt = 1
        if k == "early" and b2 and key == "compat" and amt == 2: amt = 1
        if k == "justlost" and b3 and key == "compat" and amt == 2: amt = 1
        return oe(s, key, amt)
    def app(s, k):
        prev = st["k"]; st["k"] = k
        try: return oapp(s, k)
        finally: st["k"] = prev
    C._ev_add, C._app_apply = ev, app
    _, _, _, r = M.one(("all", True, bot, n))
    return case, bot, r

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, [(c, b, n) for c in CASES for b in BOTS], chunksize=1)
    print("| 案 | ボット | 優勝% | 決勝% | 10年目所持金の中央(万) |")
    print("|---|---|---|---|---|")
    for c, b, r in res:
        print(f"| {c} | {b[:8]} | {r['win']:.1f} | {r['fin']:.1f} | {r['y10'][1]:.0f} |")
