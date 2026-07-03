#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
漫才師育成SLG 10年キャリア検証シミュレータ v0
- 1年48週×10年（最大480手）。能力・お金・知名度・相性は年をまたいで引き継ぎ、体力のみ年初全回復
- グランプリ（架空名）を実在の全国漫才賞レースと同じ多段階構造にし、初優勝が何年目に出るかを測る
- 相方ガチャ／周回ボーナス／アイテムは未設計のため、パラメータ実験（感度実験A/B/C）で適正な強さの材料を採る
- balance_sim.py は無変更で import 流用（週次の行動・数式・ボットはそちらの実装をそのまま使う）
- 使い方: python3 sim_career.py [キャリア数/設定]   （省略時 2000）
- 数値は全て【仮】。冒頭の定数を書き換えて再実験する
"""

import random
import statistics
import sys

import balance_sim as B

# ============================================================
# CONFIG —— 全て【仮】
# ============================================================

YEARS      = 10        # キャリア年数
N_CAREERS  = 2000      # 1設定あたりの試行キャリア数
BASE_SEED  = 20260704  # 乱数シード（balance_sim と同系）

# ------------------------------------------------------------
# グランプリ（架空名）の多段階構造
#
# 実在の国内最大級の漫才賞レース（固有名は CLAUDE.md ルールにより伏せる）の
# 2025年大会の公表データを Web で調査し、開催時期と通過率を参考にした。
#   応募:            11,521組
#   1回戦   (8月上旬〜10月上旬) 通過 1,912組 … 通過率 約16.6%（アマチュア含む母集団）
#   2回戦   (10月上旬〜下旬)    通過   380組 … 通過率 約19.9%
#   3回戦   (10月下旬〜11月上旬) 通過   134組 … 通過率 約35.3%
#   準々決勝 (11月中旬)          通過    30組 … 通過率 約22%（準決勝出場はWC等含め31組）
#   準決勝   (12月上旬)          通過     9組 … 通過率 約29%
#   敗者復活 (12月下旬)          通過     1組 … 準決勝敗退約21組中 約5%
#   決勝     (12月下旬)          優勝     1組/10組 … 10%
# （参考: 前年2024年大会は 応募10,330 → 1,721 → 408 → 132 → 準決勝31 → 決勝9+復活1）
#
# 開催時期を 1月起点48週（4週=1ヶ月）に変換して配置:
#   8月=第29〜32週 / 10月=第37〜40週 / 11月=第41〜44週 / 12月=第45〜48週
#
# 通過ラインは「絶対評価型（実力値がラインを超えれば通過）」の既存方式のまま、
# 序盤は新人でも勝ち上がれるよう低く、決勝ライン85（既存値を維持）へ滑らかに上げる。
# 1回戦の実通過率16.6%はアマチュア含む数字であり、プロのコンビには易しい想定でライン30とした。
# ------------------------------------------------------------

GP_ROUNDS = [
    # (週, ライン, ラベル)      実在対応: 開催時期 / 通過組数(2025)
    (30, 30, "GP1回戦"),      # 8月中旬       / 11,521 → 1,912 (16.6%)
    (39, 45, "GP2回戦"),      # 10月中旬〜下旬 /  1,912 →   380 (19.9%)
    (41, 55, "GP3回戦"),      # 11月上旬       /    380 →   134 (35.3%)
    (43, 65, "GP準々決勝"),   # 11月中旬       /    134 →    30 (22%)
    (45, 75, "GP準決勝"),     # 12月上旬       /     31 →     9 (29%)
]
GP_REVIVAL_WEEK, GP_REVIVAL_LINE = 47, 80   # 敗者復活: 12月下旬(決勝と同週) / 約21 → 1 (5%)
GP_FINAL_WEEK,   GP_FINAL_LINE   = 47, 85   # 決勝: 第47週固定 / 10 → 優勝1 (10%)
GP_PRIZE = B.GPF_PRIZE                       # 手元500万（表示1,000万の半分【仮】）

GP_ROUND_FAME = 3    # GP各回戦通過の知名度上昇【仮】
FAME_SMALL    = 5    # 小規模大会 通過+5【仮】
FAME_MID      = 10   # 中規模大会 通過+10【仮】
FAME_CHAMP    = 20   # グランプリ優勝+20【仮】

# ------------------------------------------------------------
# その他の大会カレンダー（毎年開催・全て架空名・全て【仮】）
# prize は「表示額の半分＝手元に入る額」。eligible(年目, 状態) で出場資格を判定
# ------------------------------------------------------------

TOURNAMENTS = {
    # 週: dict(名前, ライン, 手元賞金, 知名度, 大阪遠征, 資格)
    12: dict(name="春新人賞A",     line=55, prize=500_000, fame=FAME_MID,   osaka=True,
             ok=lambda year, s: year <= 10),          # 芸歴10年内
    15: dict(name="春新人賞B",     line=50, prize=250_000, fame=FAME_SMALL, osaka=True,
             ok=lambda year, s: year <= 10),          # 結成10年内
    27: dict(name="夏中堅賞",      line=60, prize=500_000, fame=FAME_MID,   osaka=True,
             ok=lambda year, s: year <= 10),          # デビュー10年内
    29: dict(name="大阪戎コンクール", line=B.OSAKA_LINE, prize=B.OSAKA_PRIZE, fame=FAME_SMALL,
             osaka=True,  ok=lambda year, s: True),   # 既存どおり（ライン40・手元10万）
    35: dict(name="若手限定賞",    line=50, prize=250_000, fame=FAME_SMALL, osaka=False,
             ok=lambda year, s: year <= 5),           # 1〜5年目のみ
    38: dict(name="推薦制中堅賞",  line=60, prize=500_000, fame=FAME_MID,   osaka=False,
             ok=lambda year, s: s.fame >= 30),        # 知名度30以上【仮】
}

EVENT_WEEKS = set(TOURNAMENTS) | {w for w, _, _ in GP_ROUNDS} | {GP_FINAL_WEEK}

# ============================================================
# ボット（既存のバランス型・調整型を流用）
# キャリア用の最小補正を2点だけ加える（1年版のロジック自体は変えない）:
#  (1) 選んだ稽古の主効果が上限100に達していたら、主効果が最も低い稽古に差し替える
#      （既存ボットは金持ちになると舞台稽古に固定され、表現100到達後の稽古週が全て空振りになるため。
#        この補正がないと実力値が57〜66で頭打ちになり、感度実験がボットの欠陥に埋もれる）
#  (2) 調整型の「大会前週に体力を整える」対象週を新カレンダー（大会6種＋GP各回戦）に差し替える
# ============================================================

def redirect_capped_training(s, choice):
    act, arg = choice
    if act != "train":
        return choice
    if getattr(s, B.TRAININGS[arg]["main"][0]) < 100:
        return choice
    cands = [(getattr(s, t["main"][0]), name) for name, t in B.TRAININGS.items()
             if t["cost"] <= s.money and getattr(s, t["main"][0]) < 100]
    if not cands:
        return ("rest", "完全休養")   # 全能力カンスト後は休むしかない
    cands.sort()
    return ("train", cands[0][1])

class CareerBalanced(B.PBalanced):
    def choose(self, s, week, offer, rng):
        return redirect_capped_training(s, super().choose(s, week, offer, rng))

class CareerSmart(B.PSmart):
    def choose(self, s, week, offer, rng):
        if (week + 1) in EVENT_WEEKS and s.stamina < 75:
            return ("rest", "完全休養")
        return redirect_capped_training(s, super().choose(s, week, offer, rng))

BOTS = (CareerBalanced, CareerSmart)

# ============================================================
# 1キャリア（最大10年）を回す
# ============================================================

def new_state(init_ability=None, compat=None):
    s = B.S()
    if init_ability is not None:
        s.sense = s.idea = s.expr = s.chara = s.mental = float(init_ability)
    if compat is not None:
        s.compat = float(compat)
    return s

def enter_tournament(s, pol, t, rng):
    """出場資格チェック後の大会1回ぶん。遠征費が払えなければ不参加(False)"""
    if t["osaka"]:
        tr = pol.transport(s)
        if s.money < tr["cost"]:
            return False
        s.money -= tr["cost"]
        B.add(s, "stamina", tr["stam"])
    ok, _ = B.perform(s, t["line"], rng)
    if ok:
        s.money += t["prize"]
        B.add(s, "fame", t["fame"])
    return True

def run_year(pol, s, year, rng):
    """1年48週。優勝したら True を返す（キャリア終了＝勇退）"""
    s.stamina = 100.0          # 体力のみ年初に全回復
    gp_stage = 0               # 次に挑む GP_ROUNDS のインデックス
    gp_alive = True            # 今年のグランプリ挑戦が続いているか
    finalist = False
    revival = False            # 準決勝敗退→敗者復活に回るか

    for week in range(1, B.WEEKS + 1):
        acted = False

        # --- その他の大会（出場資格があり交通費が払えるなら出る） ---
        t = TOURNAMENTS.get(week)
        if t and t["ok"](year, s):
            acted = enter_tournament(s, pol, t, rng)

        # --- グランプリ各回戦（東京・遠征不要・毎年1回戦からエントリー【仮】） ---
        if not acted and gp_alive and gp_stage < len(GP_ROUNDS) and week == GP_ROUNDS[gp_stage][0]:
            _, line, _ = GP_ROUNDS[gp_stage]
            ok, _ = B.perform(s, line, rng)
            acted = True
            if ok:
                B.add(s, "fame", GP_ROUND_FAME)
                gp_stage += 1
                if gp_stage == len(GP_ROUNDS):
                    finalist = True
            else:
                if gp_stage == len(GP_ROUNDS) - 1:   # 準決勝敗退のみ敗者復活へ
                    revival = True
                gp_alive = False                     # 落ちたら今年の挑戦終了（翌年また1回戦から）

        if week == GP_FINAL_WEEK:
            if revival:                              # 敗者復活 → 通過なら同週の決勝へ
                ok, _ = B.perform(s, GP_REVIVAL_LINE, rng)
                acted = True
                if ok:
                    B.add(s, "fame", GP_ROUND_FAME)
                    finalist = True
            if finalist:                             # 決勝
                ok, _ = B.perform(s, GP_FINAL_LINE, rng)
                acted = True
                if ok:
                    s.money += GP_PRIZE
                    B.add(s, "fame", FAME_CHAMP)
                    return True                      # 初優勝＝勇退

        # --- 通常行動（大会がなかった週） ---
        if not acted:
            offer = B.roll_offer(s, rng)
            act, arg = pol.choose(s, week, offer, rng)
            if act == "train":
                if not B.do_training(s, arg):
                    B.do_rest(s, "完全休養")
            elif act == "job":
                B.do_job(s, arg)
            elif act == "offer" and offer:
                B.do_offer(s, offer)
            elif act == "rest":
                B.do_rest(s, arg)

        if week % B.LIVING_INTERVAL == 0:
            s.money -= B.LIVING_COST
        s.min_money = min(s.min_money, s.money)

    return False

def run_career(pol, seed, init_ability=None, compat=None, money_log=None):
    """1キャリア。初優勝年（なければ None）を返す"""
    rng = random.Random(seed)
    s = new_state(init_ability, compat)
    for year in range(1, YEARS + 1):
        won = run_year(pol, s, year, rng)
        if money_log is not None:
            money_log[year - 1].append(s.money)
        if won:
            return year, s
    return None, s

# ============================================================
# 集計
# ============================================================

def run_config(pol_cls, n, init_ability=None, compat_fixed=None, track_money=False):
    """1設定×nキャリア。compat_fixed 指定時は相性成長もOFFにする"""
    saved = B.COMPAT_GROWS
    if compat_fixed is not None:
        B.COMPAT_GROWS = False
    try:
        pol = pol_cls()
        money_log = [[] for _ in range(YEARS)] if track_money else None
        wins, finals = [], []
        for i in range(n):
            year, s = run_career(pol, BASE_SEED + i,
                                 init_ability=init_ability, compat=compat_fixed,
                                 money_log=money_log)
            wins.append(year)
            finals.append(s.money)
    finally:
        B.COMPAT_GROWS = saved

    dist = [sum(1 for w in wins if w == y) for y in range(1, YEARS + 1)]
    none = sum(1 for w in wins if w is None)
    med = statistics.median((w if w is not None else YEARS + 1) for w in wins)
    return dict(name=pol.name, n=n, dist=dist, none=none, median=med,
                none_rate=100.0 * none / n,
                final_money=statistics.median(finals),
                money_log=money_log)

def fmt_dist(r):
    n = r["n"]
    cells = " ".join(f"{y}年:{100.0 * c / n:4.1f}%" for y, c in enumerate(r["dist"], 1))
    med = f"{r['median']:.0f}年目" if r["median"] <= YEARS else f">{YEARS}年(優勝なし)"
    return (f"  {r['name']:　<8}| {cells} | なし:{r['none_rate']:5.1f}%\n"
            f"  {'':　<8}| 初優勝中央値: {med} / 優勝なし率: {r['none_rate']:.1f}% / 最終所持金中央値: {B.yen(r['final_money'])}")

# ============================================================
# メイン: 感度実験 A / B / C
# ============================================================

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else N_CAREERS
    print(f"=== 10年キャリア検証 v0 | {YEARS}年×48週 × {n}キャリア/設定 | シード{BASE_SEED} | 数値は全て【仮】 ===")
    lines = " → ".join(f"{lbl}{ln}(第{wk}週)" for wk, ln, lbl in GP_ROUNDS)
    print(f"グランプリ: {lines} → 敗者復活{GP_REVIVAL_LINE}/決勝{GP_FINAL_LINE}(第{GP_FINAL_WEEK}週)")
    print()

    print("== 実験A: コンビ相性 固定値(成長なし) 5/10/15/20 — 相方ガチャの強さの材料 ==")
    for compat in (5, 10, 15, 20):
        print(f"[相性={compat} 固定]")
        for cls in BOTS:
            print(fmt_dist(run_config(cls, n, compat_fixed=compat)))
    print()

    print("== 実験B: 初期能力 一律10/15/20/25（相性5・成長あり）— 周回ボーナスの適正量の材料 ==")
    for ab in (10, 15, 20, 25):
        print(f"[初期能力={ab}]")
        for cls in BOTS:
            print(fmt_dist(run_config(cls, n, init_ability=ab)))
    print()

    print("== 実験C: 基準設定(相性5・成長あり・初期能力10) — お金の余り具合＝シンク規模の材料 ==")
    for cls in BOTS:
        r = run_config(cls, n, track_money=True)
        print(fmt_dist(r))
        for y, log in enumerate(r["money_log"], 1):
            if log:
                print(f"    {y}年目末: 所持金中央値 {B.yen(statistics.median(log)):>9} (残存 {len(log)}キャリア)")
    print()
    print("※ 大会週の出場判断は「資格があり交通費が払えるなら出る」。優勝したキャリアはその年で勇退（以降の年は集計外）。")

if __name__ == "__main__":
    main()
