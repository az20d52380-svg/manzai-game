#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
得意A（方式A = 稽古効率+20% / 演技系4能力限定）— experiment-only 共有モジュール
================================================================================
- 目的: 「角の上限テスト」。方式Aは本来"相方の得意1能力"だが、ここでは演技系
  4能力(sense/idea/expr/chara)すべてを ×MULT(既定1.20) する generous版で
  「最悪でも角が壊れないか」を上からbracketする。
- 正典非干渉(構造保証): このモジュールは gen_golden が import しない exp_*.py。
  balance_sim/sim_career の本体は一切編集せず、apply()を呼んだ時だけ
  B.do_training を一時ラップし、稽古中の add() 呼び出しのうち
  演技系4キーの効果量だけを ×MULT する。reset()/with 終了で完全復元。
  exp_pity3.py の _gp_perform ラップ→finally復元の流儀に倣う。
- 絶対に掛けない: mental / compat / stamina / fame。
  （方式Aは演技系限定・メンタル/体力は予算外。do_training内の
   add(s,"stamina",..)/add(s,"fame",..) はキーが ACTING に無いので素通り。）
- 稽古"効率"のみを上げる。do_offer/do_rest 等の稽古外のability付与は対象外
  （B.add をグローバル恒久差し替えせず、do_training実行中だけ差し替えるため）。
- 数値は全て【仮】。確定フリップ(golden同期)はMacへ引き継ぐ前提。

使い方:
    import exp_talent_ability as T
    T.apply(1.20)          # 得意A ON
    ...                    # ここで B.do_training / sim_career が +20%
    T.reset()              # 復元
  もしくは:
    with T.talent_a(1.20):
        ...

CLI: python3 exp_talent_ability.py [N=600]
"""
import contextlib
import random
import sys

import balance_sim as B
import sim_career as C
import canon_v2 as V
from exp_human import PCasual2
from exp_human_fix import PSpread

# 演技系4能力（方式Aの対象）。mental/compat/stamina/fame は絶対に含めない。
ACTING = ("sense", "idea", "expr", "chara")

_ORIG_TRAIN = B.do_training
_ORIG_ADD = B.add
MULT = 1.20   # 【仮】稽古効率倍率


def _add_boost(s, key, amt):
    """稽古中だけ有効な add ラッパ。演技系キーの効果量のみ ×MULT。
    それ以外(stamina/fame/compat/mental)は素の add にそのまま渡す=漏れゼロ。
    ※逓減・年間成長予算(CAP)のクランプは素の add 内で従来通り効く
      （+20%は"生の効果量"に掛かり、予算が最終的に拘束する）。"""
    if key in ACTING and amt > 0:
        amt = amt * MULT
    return _ORIG_ADD(s, key, amt)


def _train_boost(s, name):
    """B.do_training のラッパ。実行中だけ B.add を _add_boost に差し替え、
    finally で必ず復元。do_training内の add 参照は module-global 解決なので
    B.add の一時差し替えがそのまま届く。"""
    B.add = _add_boost
    try:
        return _ORIG_TRAIN(s, name)
    finally:
        B.add = _ORIG_ADD


def apply(mult=1.20):
    """得意A ON。B.do_training を一時ラップ。reset()で復元。"""
    global MULT
    MULT = mult
    B.do_training = _train_boost


def reset():
    """完全復元。"""
    B.do_training = _ORIG_TRAIN
    B.add = _ORIG_ADD


@contextlib.contextmanager
def talent_a(mult=1.20):
    apply(mult)
    try:
        yield
    finally:
        reset()


# ============================================================
# 妥当性アンカー & ON/OFF 実測（exp_pity3 の run_one/scan 構造を流用）
# ============================================================

def run_one(pol, seed, init_ability, compat):
    """1キャリア。exp_pity3.run_one と同じ per-career グローバル初期化。
    返り値: (won:bool, ever_final:bool)。"""
    rng = random.Random(seed)
    s = C.new_state(init_ability, compat)
    if C.EVENTS_ON:
        C.RUN_EVENTS_FIRED = set()
    if C.BOREDOM_ON:
        C.RUN_BOREDOM = {}
    prev_stage = 0
    ever_final = False
    for year in range(1, C.YEARS + 1):
        won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        ever_final = ever_final or finalist
        if getattr(s, "_bankrupt", False):
            break
        if won:
            return True, ever_final
    return False, ever_final


def scan(pol_cls, n, talent_on, mult, init_ability, compat_start):
    """トロフィー0pt・裏天井/得意OFF がベースライン。talent_on=Trueで得意A。
    返り値: (優勝率%, 決勝到達率%)。
    canon_v2.apply(0) で canonical §2 の baseline(EVENTS_ON=True・CAP lift 0)を再現。
    exp_pity3.scan と同じ前提を踏むことで実証済みアンカーを継承する。"""
    V.apply(trophy_pt=0)
    if talent_on:
        apply(mult)
    try:
        pol = pol_cls()
        wins = finals = 0
        for i in range(n):
            won, ever = run_one(pol, C.BASE_SEED + i, init_ability, compat_start)
            wins += won
            finals += ever
        return 100.0 * wins / n, 100.0 * finals / n
    finally:
        reset()
        V.reset()


# ============================================================
# 稽古の成長差 & 漏れ検査（単体・キャリア非依存）
# ============================================================

def growth_probe(mult=1.20, reps=40):
    """稽古を反復し、得意A OFF/ON で各パラメータの最終値を比較。
    演技系は上がり、mental/compat/stamina/fame は不変(漏れゼロ)を示す。
    予算(YEAR_GROWTH_CAP)を無効化した"生の稽古効率"の差を見るため、
    ここでは s._yg 予算は new_state 由来のまま（既定は成長予算ON/OFFに依存）。"""
    keys = ("sense", "idea", "expr", "chara", "mental", "compat", "stamina", "fame")

    def _run(on):
        s = C.new_state(10, 5)
        s.money = 10 ** 9   # 有料稽古の所持金制約を外す
        if on:
            apply(mult)
        try:
            rng = random.Random(C.BASE_SEED)
            for _ in range(reps):
                for nm in ("ネタ作り", "ネタ合わせ", "フリーライブ"):
                    if nm in B.TRAININGS:
                        B.do_training(s, nm)
        finally:
            reset()
        return {k: round(getattr(s, k), 3) for k in keys}

    return _run(False), _run(True)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    mult = 1.20
    # 妥当性アンカー用の初プレイ設定（exp_pity3 stage① と同一: 0pt / cap20 / ia10 / cs5）
    ia, cs = 10, 5

    # --- 稽古成長差 & 漏れ検査 ---
    off, on = growth_probe(mult)
    print("=== 得意A 稽古成長プローブ（reps=40・生の稽古効率）| 数値は全て【仮】 ===")
    print(f"{'key':<9}| OFF      | ON       | Δ")
    print("-" * 44)
    for k in ("sense", "idea", "expr", "chara", "mental", "compat", "stamina", "fame"):
        d = on[k] - off[k]
        tag = " <演技系" if k in ACTING else (" <漏れNG(不変であるべき)" if k in ("mental", "compat", "stamina", "fame") else "")
        print(f"{k:<9}| {off[k]:8.3f} | {on[k]:8.3f} | {d:+8.3f}{tag}")
    leak = [k for k in ("mental", "compat", "stamina", "fame") if abs(on[k] - off[k]) > 1e-9]
    print(f"漏れ検査: 非演技系で変化したキー = {leak or 'なし（OK）'}")
    print()

    # --- ベースライン一致(canonical §2) & 得意A ON/OFF ---
    print(f"=== 得意A(方式A=稽古+20%/演技系4能力) ON/OFF | n={n} | trophy0/裏天井OFF | 全て【仮】 ===")
    print(f"{'プレイ型':<10}| 決勝到達 OFF→ON      | 優勝 OFF→ON")
    print("-" * 60)
    for cls in (PCasual2, PSpread):
        w_off, f_off = scan(cls, n, False, mult, ia, cs)
        w_on, f_on = scan(cls, n, True, mult, ia, cs)
        name = getattr(cls(), "name", cls.__name__)
        print(f"{name:<10}| {f_off:5.1f}% → {f_on:5.1f}%  (Δ{f_on - f_off:+.1f})"
              f" | {w_off:5.2f}% → {w_on:5.2f}%  (Δ{w_on - w_off:+.2f})", flush=True)
    print()
    print("アンカー基準(canonical §2): のんびり 優勝≈0.3%/到達≈23.1% / やり込み 優勝≈2.7%/到達≈41.5%")


if __name__ == "__main__":
    main()
