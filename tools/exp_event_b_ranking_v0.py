#!/usr/bin/env python3
"""イベント別「毎回B」ランキング（docs/event_b_ranking_v0.md）。usage: python3 exp_event_b_ranking_v0.py [n=300] [top=5] [topn=1000]
基準＝やり込み・全部入り・ネタ込み・EVENTS_APP=True・イベントは既定の選び方。イベント k だけ毎回B（他は既定）を k ごとに回して差を見る。
上位 top 件は topn で再測（基準・全イベントB も topn で再測）。選び方の表は exp_exploit_search_v2.py の _evtab/_evuniq。上書きはプロセス内のみ。"""
import sys
from multiprocessing import Pool
import sim_career as C
import exp_money_after_merge_v0 as M
import exp_exploit_search_v2 as X2
import exp_event_scale_v1 as E

BOT = "金→力 全振り(やり込み改)"

def one(args):
    E.patch("raw")            # EVENTS_APP=True（素の加減算）
    target, n = args          # target: None=基準, "ALL"=全イベントB, それ以外=そのイベントだけB
    if target is not None:
        o_oth, o_app = C._others_apply, C._app_apply
        X2.hook_evm("B")
        b_oth, b_app = C._others_apply, C._app_apply
        if target == "ALL":
            pass
        else:
            C._others_apply = lambda s, k: b_oth(s, k) if k == target else o_oth(s, k)
            C._app_apply = lambda s, k: b_app(s, k) if k == target else o_app(s, k)
    r = M.one(("all", True, BOT, n))[3]
    return target, n, r["win"], r["fin"], r["ds"]

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    top = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    topn = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
    keys = list(X2._evtab()) + list(X2._evuniq())
    with Pool(maxtasksperchild=1) as pool:
        res = pool.map(one, [(None, n), ("ALL", n)] + [(k, n) for k in keys], chunksize=1)
        base = res[0]; rows = sorted(res[2:], key=lambda r: -(r[2] - base[2]) - 0.5 * (r[3] - base[3]) / 10)
        pick = [r[0] for r in rows[:top]]
        res2 = pool.map(one, [(None, topn), ("ALL", topn)] + [(k, topn) for k in pick], chunksize=1)
    print(f"# n={n}（上位{top}件は n={topn}）。やり込み・全部入り・ネタ込み・EVENTS_APP=True")
    print("対象|n|優勝%|決勝%|解散%|優勝差|決勝差")
    def show(rs, b):
        for t, nn, w, f, d in rs:
            print(f"{t if t else '基準'}|{nn}|{w:.1f}|{f:.1f}|{d:.1f}|{w-b[2]:+.1f}|{f-b[3]:+.1f}")
    show([res[0], res[1]] + rows, base)
    print("--- top")
    show(res2, res2[0])

if __name__ == "__main__":
    main()
