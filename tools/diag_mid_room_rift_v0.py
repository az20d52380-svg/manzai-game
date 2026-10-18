#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""診断 v0（2026-10-19）: 中の部屋に固定すると解散が増える原因。基準(部屋なし)と中の部屋固定を同シードで並べ、年ごとに行動内訳・相性・rift・所持金を集計。
式・既定値は変えない（計測フックのみ）。usage: python3 diag_mid_room_rift_v0.py [n=300]"""
import sys, statistics, collections
from multiprocessing import Pool
import sim_career as C
import balance_sim as B
import exp_balance_snapshot_v0 as S
import exp_exploit_search_v1 as E

BASES = [("必要充足", E.NEED), ("ローテ", E.ROT), ("やり込み", E.YARI)]
YEARS = 10

class Rec(B.Policy):
    """行動を記録する薄い包み"""
    def __init__(self, base): self.base = base; self.name = base.name
    def __getattr__(self, k): return getattr(self.base, k)
    def choose(self, s, week, offer, rng):
        a = self.base.choose(s, week, offer, rng)
        s._act = a
        return a

def classify(s, act):
    if act is None: return "他(大会/療養/イベ)"
    k, a = act
    if k == "job": return "バイト"
    if k == "rest": return "休む(家)" if a in B.ROOM_HOME_RESTS else "休む(他)"
    if k == "offer": return "オファー"
    if k == "train": return "ネタ合わせ" if a == "ネタ合わせ" else ("舞台稽古" if a in C.RIFT_JOINT_TRAIN else "稽古(他)")
    return k
CATS = ["バイト", "休む(家)", "休む(他)", "ネタ合わせ", "舞台稽古", "稽古(他)", "オファー", "他(大会/療養/イベ)"]

def one(args):
    label, bn, room, n = args
    S.install(True)
    orig = C.rift_weekend
    out = []
    for i in range(n):
        pol = Rec(S.make2(bn))
        st = dict(yr=collections.defaultdict(lambda: collections.Counter()), snap={}, cut=None, wk=collections.Counter(), first_warn=None, comp_up=collections.Counter())
        def hook(s, year, compat0, st=st):
            if room is not None: pass
            act = getattr(s, "_act", None); s._act = None
            if getattr(s, "_joint", False) and act is None: act = None
            cat = classify(s, act)
            if getattr(s, "_joint", False) and cat not in ("ネタ合わせ", "舞台稽古"): cat = "他(大会/療養/イベ)"
            st["yr"][year][cat] += 1
            if s.compat > compat0: st["comp_up"][year] += 1
            r = orig(s, year, compat0)
            st["yr"][year]["_rift_sum"] += s.rift; st["yr"][year]["_money_sum"] += s.money; st["yr"][year]["_compat_sum"] += s.compat
            st["yr"][year]["_weeks"] += 1
            st["yr"][year]["_stam_sum"] += s.stamina
            if s.rift >= C.RIFT_WARN and st["first_warn"] is None: st["first_warn"] = (year, st["yr"][year]["_weeks"])
            return r
        C.rift_weekend = hook
        try:
            if room is not None:
                pol = E.W(pol, room=room)
                pol.name = "W"
            first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        finally:
            C.rift_weekend = orig
        d = s.__dict__
        out.append(dict(ds=bool(d.get("_dissolved")), bk=bool(d.get("_bankrupt")), win=first, st={y: dict(c) for y, c in st["yr"].items()},
                        comp_up={y: v for y, v in st["comp_up"].items()}, fw=st["first_warn"], compat=s.compat, rift=getattr(s, "rift", 0), money=s.money))
    return label, bn, room, out

def agg(recs, f):
    return statistics.mean(f(r) for r in recs) if recs else 0

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    jobs = [(lab, bn, room, n) for lab, bn in BASES for room in (None, 1)]
    with Pool(6, maxtasksperchild=1) as p: res = p.map(one, jobs, chunksize=1)
    R = {(lab, room): out for lab, bn, room, out in res}
    print(f"# n={n} 同シード(BASE_SEED+i)。解散/夜逃げ%、警告(rift>=50)初到達、年別の週内訳(平均週数/年)・相性・rift・所持金(万)")
    for lab, _ in BASES:
        for room in (None, 1):
            rc = R[(lab, room)]
            ds = 100 * agg(rc, lambda r: r["ds"]); bk = 100 * agg(rc, lambda r: r["bk"])
            fws = [r["fw"][0] for r in rc if r["fw"]]
            print(f"\n## {lab} / {'基準(部屋なし)' if room is None else '中の部屋固定'}: 解散{ds:.1f}% 夜逃げ{bk:.1f}% 警告到達{100*len(fws)/len(rc):.0f}% (警告年中央{statistics.median(fws) if fws else '-'}) 終了相性{agg(rc,lambda r:r['compat']):.1f} 終了所持金{statistics.median(r['money'] for r in rc)/1e4:.0f}万")
            print("年|生存n|" + "|".join(CATS) + "|相性↑週|相性|rift|所持金万|体力")
            for y in range(1, YEARS + 1):
                live = [r for r in rc if y in r["st"]]
                if not live: continue
                cells = []
                for c in CATS:
                    cells.append(f"{agg(live, lambda r: r['st'][y].get(c, 0)):.1f}")
                w = lambda k: statistics.mean(r["st"][y].get(k, 0) / max(1, r["st"][y].get("_weeks", 1)) for r in live)
                print(f"{y}|{len(live)}|" + "|".join(cells) + f"|{agg(live, lambda r: r['comp_up'].get(y, 0)):.1f}|{w('_compat_sum'):.1f}|{w('_rift_sum'):.1f}|{w('_money_sum')/1e4:.0f}|{w('_stam_sum'):.0f}")
    # 同シード対比: 基準で解散しない人のうち中の部屋で解散した人の年別差
    print("\n## 同シード対比（基準=生存 & 中の部屋=解散 の人と、基準=生存&中の部屋=生存 の人の、1〜3年目の平均）")
    for lab, _ in BASES:
        a, b = R[(lab, None)], R[(lab, 1)]
        bad = [i for i in range(n) if not a[i]["ds"] and b[i]["ds"]]
        ok = [i for i in range(n) if not a[i]["ds"] and not b[i]["ds"]]
        print(f"{lab}: 基準OK→部屋で解散 {len(bad)}人 / 両方OK {len(ok)}人")
        for tag, idx in (("部屋で解散", bad), ("両方OK", ok)):
            if not idx: continue
            for room_, rc in (("基準", a), ("部屋", b)):
                row = []
                for y in (1, 2, 3):
                    L = [rc[i] for i in idx if y in rc[i]["st"]]
                    if not L: continue
                    jb = agg(L, lambda r: r["st"][y].get("バイト", 0)); na = agg(L, lambda r: r["st"][y].get("ネタ合わせ", 0)); up = agg(L, lambda r: r["comp_up"].get(y, 0))
                    row.append(f"Y{y}:バイト{jb:.1f}/ネタ合{na:.1f}/相性↑{up:.1f}")
                print(f"  {tag}/{room_}: " + "  ".join(row))


# ---- 追加: 人が避けられるか（中の部屋固定＋工夫）。python3 diag_mid_room_rift_v0.py 300 extra ----
import bots_v3 as BV
class RotHard(BV.PRotate):
    """ローテのバイトを キツい に（週数あたりの稼ぎを上げる人）"""
    name = "ローテ(キツい)"
    def choose(self, s, week, offer, rng):
        a = super().choose(s, week, offer, rng)
        return ("job", "キツい") if a == ("job", "標準") else a
class RotHardBuf(RotHard):
    BUF = 150_000
def one_x(args):
    lab, kind, resp, n = args
    S.install(True)
    C.RIFT_RESPOND = resp
    ds = bk = 0; ms = []; cs = []
    for i in range(n):
        base = RotHard() if kind == "hard" else S.make2(E.ROT)
        pol = E.W(base, room=1)
        first, s, st, ev = C.run_career(pol, C.BASE_SEED + i)
        ds += bool(s.__dict__.get("_dissolved")); bk += bool(s.__dict__.get("_bankrupt")); ms.append(s.money / 1e4); cs.append(s.compat)
    return f"{lab}: 解散{100*ds/n:.1f}% 夜逃げ{100*bk/n:.1f}% 終了所持金中央{statistics.median(ms):.0f}万 終了相性{statistics.mean(cs):.1f}"
def extra(n):
    jobs = [("ローテ+中の部屋(素)", "std", False, n), ("ローテ+中の部屋+rift警告に向き合う", "std", True, n),
            ("ローテ+中の部屋+キツいバイト", "hard", False, n), ("ローテ+中の部屋+キツい+向き合う", "hard", True, n)]
    with Pool(4, maxtasksperchild=1) as p:
        for r in p.map(one_x, jobs): print(r)
if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "extra": extra(int(sys.argv[1]))
    else: main()
