#!/usr/bin/env python3
"""EVENTS_APP False/True の帯比較（docs/events_app_parity_v0.md）。usage: python3 exp_events_app_v0.py [n=1000]
ボット・全部入り(部屋+アイテム+特技)・ネタ込みは exp_money_after_merge_v0.py と同じ（one() をそのまま呼ぶ）。False=従来のイベント(install の既定＝EVENTS_ON+OTHERS_ON)、True=アプリ版、off=イベント全部なし(参考)。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M

def one(args):
    app, name, n = args          # app: False=従来(install既定のイベント) / True=アプリ版 / "off"=イベントなし(参考・EVENTS_ON=False)
    C.EVENTS_APP = app is True
    if app == "off":
        import exp_balance_snapshot_v0 as S
        o = S.install
        def inst(neta):
            o(neta); C.EVENTS_ON = False
        S.install = inst
    r = M.one(("all", True, name, n))
    return app, name, r[3]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(a, b, n) for a in (False, True, "off") for b in M.BOTS])
    print(f"# n={n}/ボット・全部入り・ネタ込み。所持金は万円 Q1/中央/Q3。10年目=10年目まで続いた人のみ(n10)")
    print("EVENTS_APP|ボット|優勝%|決勝%|解散%|夜逃げ%|10年目所持金(n10)|終了時所持金")
    for a, name, r in res:
        print(f"{a}|{M.SHORT[M.BOTS.index(name)]}|{r['win']:.1f}|{r['fin']:.1f}|{r['ds']:.1f}|{r['bk']:.1f}|"
              + "/".join(f"{x:.0f}" for x in r["y10"]) + f"({r['n10']})|" + "/".join(f"{x:.0f}" for x in r["end"]))

if __name__ == "__main__":
    main()
