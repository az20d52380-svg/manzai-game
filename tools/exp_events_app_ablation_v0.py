#!/usr/bin/env python3
"""EVENTS_APP=True を基準に、アプリ抽選プールのイベントを1種ずつ外した時の 決勝到達・10年目所持金（docs/events_app_ablation_v0.md）。
usage: python3 exp_events_app_ablation_v0.py [n=300] [cfgs=all|カンマ区切り]  式・既定値は変えない（プール/効果の差し替えはプロセス内のみ）。
cfg: base(True基準) / false(従来) / -<key>(プールから外す) / -UNIQUE(固有9種をプールから外す) / -CONFIRM(確定発火の効果を無効化＝発火判定は残す)
知名度20到達週＝run_year 後ではなく invite_weekend（毎週末の最後）で fame>=20 を初めて見た通算週。"""
import sys, statistics
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_money_after_merge_v0 as M

BOTS2 = [("PRotate", "ローテ"), ("PNeedV3", "必要充足")]
CONFIRM = {"justlost", "styletalk", "passfork", "eve", "early", "tsuuka", "tani"}

def one(args):
    cfg, name, n = args
    C.EVENTS_APP = cfg != "false"
    if cfg.startswith("-"):
        k = cfg[1:]
        if k == "UNIQUE": C.APP_POOL[:] = [x for x in C.APP_POOL if x not in C.APP_UNIQUE]
        elif k == "CONFIRM" or k.startswith("C:"):
            off = CONFIRM if k == "CONFIRM" else {k[2:]}      # -C:tani = その確定発火の効果だけ無効化
            o = C._app_apply
            C._app_apply = lambda s, kk: None if kk in off else o(s, kk)
        else: C.APP_POOL[:] = [x for x in C.APP_POOL if x != k]
    f20 = []; cur = []
    orc, oiw = C.run_career, C.invite_weekend
    def iw(s, pol, year, week, seed):
        if s.__dict__.get("_f20") is None and s.fame >= 20: s._f20 = (year - 1) * B.WEEKS + week
        return oiw(s, pol, year, week, seed)
    def rc(*a, **kw):
        r = orc(*a, **kw); f20.append(r[1].__dict__.get("_f20")); return r
    C.invite_weekend, C.run_career = iw, rc
    r = M.one(("all", True, name, n))[3]
    got = [x for x in f20 if x is not None]
    return cfg, name, r["fin"], r["win"], r["y10"][1], r["n10"], (statistics.median(got) if got else float("nan")), 100.0 * len(got) / max(1, len(f20))

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    keys = ["-" + k for k in C.APP_POOL] + ["-UNIQUE", "-CONFIRM"] + ["-C:" + k for k in sorted(CONFIRM)]
    cfgs = ["false", "base"] + keys
    if len(sys.argv) > 2 and sys.argv[2] != "all": cfgs = sys.argv[2].split(",")
    jobs = [(c, b, n) for c in cfgs for b, _ in BOTS2]
    with Pool(9, maxtasksperchild=1) as pool: res = pool.map(one, jobs, chunksize=1)   # 1ジョブ=1プロセス（パッチの持ち越し防止）
    print(f"# n={n}/ボット・全部入り・ネタ込み。決勝%/優勝%/10年目所持金中央(万・n10)/知名度20到達週(中央・通算48週/年)/20到達者%")
    print("cfg|ボット|決勝%|優勝%|10年目中央(n10)|f20週|f20到達%")
    for c, b, fin, win, y10, n10, f20, f20p in res:
        print(f"{c}|{dict(BOTS2)[b]}|{fin:.1f}|{win:.1f}|{y10:.0f}({n10})|{f20:.0f}|{f20p:.0f}")

if __name__ == "__main__":
    main()
