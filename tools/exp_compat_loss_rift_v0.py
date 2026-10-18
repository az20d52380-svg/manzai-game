#!/usr/bin/env python3
"""キュー94：予選で落ちたら相性が下がる（3-回答）＋二人でやる行動の週はすれ違いがたまらない（4-回答）の実測。
usage: python3 exp_compat_loss_rift_v0.py [n=300] [variants=all]
式・既定値は変えない（案はこのスクリプト内の差し替えだけ）。数値は全て【仮】。ネタ込み（NETA_ON/NETA_V2）。
案の書き方 "L{x}_T{y}[_O]":
  L = グランプリの予選（1回戦〜準決勝）で落ちた時の相性の下げ幅。1〜3回戦は x、準々決勝は x/2、準決勝は x/4（上の段ほど小さく）
      敗者復活・決勝の負けでは下げない。_O を付けると、その他の大会の負けでも x/2 下げる
  T = 二人でやる行動の週（ネタ見せ会・フリーライブ・その他の大会・GPの回戦/敗者復活/決勝）で相性が上がらなかった時：
      すれ違いを増やさず、y だけ減らす（y=0 は「増えない」だけ）。T- は今のまま（一人の週と同じく増える）
エンディング：相性で分けるまま（exp_endings_distribution_v0 の案A＝相性15以上で #4/#6/#8）。"""
import sys
from multiprocessing import Pool
import balance_sim as B
import sim_career as C
import exp_balance_snapshot_v0 as S
import exp_endings_distribution_v0 as E

BOTS = ["PCasual2", "PRotate", "PNeedV3", "金→力 全振り(やり込み改)", "放置(ネタ作り/フリーライブ/バイト)"]
SHORT = ["のんびり改", "ローテ", "必要充足", "やり込み", "放置"]
JOINT = {"ネタ見せ会", "フリーライブ"}

def parse(v):
    L = T = None; others = False
    for p in v.split("_"):
        if p.startswith("L"): L = float(p[1:])
        elif p == "T-": T = None
        elif p.startswith("T"): T = float(p[1:])
        elif p == "O": others = True
    return L or 0.0, T, others

def one(args):
    var, name, n = args
    L, T, others = parse(var)
    S.install(True)
    st = {"joint": False, "k": 0, "mr": 0.0}
    o_tr, o_gp, o_ent, o_rw, o_ry = B.do_training, C._gp_perform, C.enter_tournament, C.rift_weekend, C.run_year

    def do_training(s, nm):
        ok = o_tr(s, nm)
        if ok and nm in JOINT: st["joint"] = True
        return ok
    def gp(s, line, rng, final):
        st["joint"] = True
        ok, x = o_gp(s, line, rng, final)
        if not final:
            stage = st["k"]; st["k"] += 1
            if not ok and L > 0:
                f = 1.0 if stage <= 2 else (0.5 if stage == 3 else 0.25)
                B.add(s, "compat", -L * f)
        return ok, x
    def ent(s, pol, t, rng):
        acted, ok = o_ent(s, pol, t, rng)
        if acted:
            st["joint"] = True
            if others and not ok and L > 0: B.add(s, "compat", -L * 0.5)
        return acted, ok
    def rw(s, year, c0):
        if T is not None and st["joint"] and not (s.compat > c0):
            s.rift = max(0.0, getattr(s, "rift", 0.0) - T)
            if year < 2: s.rift = min(s.rift, 99.0)
            out = False
        else:
            out = o_rw(s, year, c0)
        st["joint"] = False
        st["mr"] = max(st["mr"], getattr(s, "rift", 0.0))
        return out
    def ry(pol, s, year, rng, **kw):
        st["k"] = 1 if kw.get("gp_seed") else 0
        return o_ry(pol, s, year, rng, **kw)
    B.do_training, C._gp_perform, C.enter_tournament, C.rift_weekend, C.run_year = do_training, gp, ent, rw, ry
    pol = S.make2(name); recs = []
    for i in range(n):
        st.update(joint=False, k=0, mr=0.0)
        first, s, stage, ever = C.run_career(pol, C.BASE_SEED + i)
        d = s.__dict__
        recs.append(dict(bk=bool(d.get("_bankrupt")), ds=bool(d.get("_dissolved")), champ=first is not None,
                         fin=d.get("_finals", 0), ever=bool(ever), compat=s.compat, mr=st["mr"], warned=bool(d.get("rift_warned"))))
    return var, name, recs

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    variants = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] != "all" else \
        ["L0_T-", "L0_T0", "L0_T1", "L0.5_T1", "L1_T1", "L2_T1", "L1_T1_O", "L1_T-"]
    jobs = [(v, b, n) for v in variants for b in BOTS]
    with Pool(maxtasksperchild=1) as p:
        res = p.map(one, jobs)
    print(f"# n={n}/ボット ネタ込み。エンド=案A（相性15）。#1夜逃げ #2解散 #3/#4決勝なし(相性低/高) #5/#6決勝あり #7/#8優勝")
    print("案|ボット|優勝%|決勝%|解散%|予告%|相性平均|#1|#2|#3|#4|#5|#6|#7|#8|5-40%のエンド数")
    for var, name, recs in res:
        k = len(recs); pc = lambda f: 100.0 * sum(1 for r in recs if f(r)) / k
        ends = [pc(lambda r, j=j: E.end(r, "A") == j) for j in range(1, 9)]
        spread = sum(1 for x in ends[2:] if 5 <= x <= 40)
        print(f"{var}|{SHORT[BOTS.index(name)]}|{pc(lambda r: r['champ']):.1f}|{pc(lambda r: r['ever']):.1f}|"
              f"{pc(lambda r: r['ds']):.1f}|{pc(lambda r: r['warned']):.1f}|{sum(r['compat'] for r in recs)/k:.1f}|"
              + "|".join(f"{x:.1f}" for x in ends) + f"|{spread}", flush=True)

if __name__ == "__main__":
    main()
