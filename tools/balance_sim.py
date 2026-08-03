#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
漫才師育成SLG バランス検証シミュレータ v0.2
- v0.2: 成長逓減(GROWTH_DECAY_D=120)と能力上限120(メンタルのみ100)を正式組み込み
- MVP仕様書 v1.2 の数式・数値【仮】を忠実に実装
- 5つの戦略ボットで48週×N回を自動プレイし、§12要調整リストの当たりを付ける
- 標準ライブラリのみ。使い方: python3 balance_sim.py [試行回数]
- Swift実装(GameCore)と数式・数値を常に同期させること（CLAUDE.md参照）
"""

import random
import statistics
import sys
from dataclasses import dataclass

# ============================================================
# CONFIG —— §12要調整リスト対応。全て【仮】。ここを書き換えて再実験する
# ============================================================

WEEKS           = 48
INIT_MONEY      = 300_000
INIT_STAMINA    = 100
INIT_FAME       = 3        # 初期知名度0〜5【仮】の中間
INIT_ABILITY    = 10       # 能力5種 一律
COMPAT_INIT     = 5        # コンビ相性（谷口）
COMPAT_CAP      = 20       # 【仮】相性の成長上限（成長させるか自体がTBD）
COMPAT_GROWS    = True     # 【TBD】ネタ合わせ/相方と過ごす で+1

# --- 成長逓減と能力上限（docs/career_report_v1.md・endgame_design_v0.md・trophy_design_v1.md で採用。GameCoreと同期） ---
GROWTH_DECAY_D  = 120      # 【仮】能力上昇量×(1−現在値/D)。Noneで無効。D=100まで下げると10年で優勝不能になる崖あり
GROWTH_DECAY_TOTAL = False # 【実験・既定OFF】逓減を「現在値/D」でなく「実力値(加重合計)/D」で計算（分散稽古の構造優位を消す案・exp_human_fix2参照）
YEAR_GROWTH_CAP = None     # 【実験・既定OFF】演技系4能力の実力値換算の年間成長上限。sim_careerが年初に s._yg を0リセットする（exp_human_fix2参照）
ABILITY_CAP     = 120      # 【仮】センス/発想/表現/華の上限（固定）。トロフィーでDが120を超えた分は「上限到達が速く・確実になる」効果
MENTAL_CAP      = 100      # メンタルはブレ幅式(1−メンタル/100)に直結するため100のまま

LIVING_COST     = 100_000  # 4週ごと（マイナスOK・ペナルティなし＝仕様どおり）
LIVING_INTERVAL = 4

# --- 稽古: 主効果 / 副効果 / 費用 / 体力 / 知名度 ---
# 正典v3（パワプロ式5通貨・docs/exp_currency_redesign_v0.md）: main/subは能力でなく経験点通貨を発行する。
# "cur:"接頭辞＝経験点通貨（ABILITY_RECIPEで能力へブレンド変換）／それ以外（compat等）は従来どおり経済外add直結。
# 量は旧版（能力直付け）のamountを踏襲＝EXP_SUPPLY_SCALE等の既存較正値をそのまま出発点にできる【仮】。
TRAININGS = {
    "ネタ作り":     dict(main=("cur:hirameki", 3),   sub=("cur:goi", 1),      cost=0,      stam=-20, fame=0),
    "ネタ見せ会":     dict(main=("cur:maai", 6),       sub=("cur:tanryoku", 3), cost=80_000, stam=-30, fame=0),
    "ネタ合わせ":   dict(main=("cur:maai", 3),       sub=("compat", 1),       cost=0,      stam=-20, fame=0),
    "ランニング・サウナ": dict(main=("cur:tanryoku", 6), sub=None,                cost=80_000, stam=-10, fame=0),
    "フリーライブ":     dict(main=("cur:sonzaikan", 3), sub=("cur:maai", 1),    cost=0,      stam=-30, fame=1),
}

# --- バイト: (収入, 体力) ---
JOBS = {
    "キツい": (120_000, -30),
    "標準":   (80_000,  -20),
    "楽":     (40_000,  -10),
}

# --- オファー（体力消費は仕様未定義→【仮】-20。種類の出現比は50/50【仮】） ---
OFFER_MONEY = dict(name="お金重視", income=300_000, fame=1, ability=None,        stam=-20)
OFFER_EXP   = dict(name="経験重視", income=150_000, fame=3, ability=("expr", 2), stam=-20)
OFFER_RATES = [(20, 0.05), (50, 0.15), (80, 0.30), (999, 0.50)]  # (知名度がこの値未満, 発生率/週)

# --- 休む: (回復, 追加効果) ---
RESTS = {
    "完全休養":     (60, ("mental", 2)),
    "気分転換":     (35, ("mental", 1)),
    "相方と過ごす": (20, ("compat", 1)),
}

# --- 大会（賞金は山分け後の手元額） ---
OSAKA_WEEK, OSAKA_LINE, OSAKA_PRIZE = 29, 22, 100_000   # ライン【正典v2】旧40×0.55
GPQ_WEEK,   GPQ_LINE               = 40, 33            # 予選チェック週【正典v2】旧60×0.55
GPF_WEEK,   GPF_LINE,  GPF_PRIZE   = 47, 47, 5_000_000 # 【正典v2】旧85×0.55（1年目には届かない設計を維持）
FAME_PASS, FAME_CHAMP = 10, 20                          # 通過+10 / 優勝+20【仮TBD】

BUS   = dict(cost=10_000, stam=-25)   # 東京→大阪 往復・夜行
TRAIN = dict(cost=30_000, stam=0)     # 新幹線

# --- 本番スコア（§7） ---
W_SENSE, W_IDEA, W_EXPR, W_CHARA = 0.30, 0.30, 0.25, 0.15
STAM_PEN = [(10, -15), (30, -10), (50, -5)]   # 体力<10で-15 / <30で-10 / <50で-5【正典v2・H3対策】

def blur_width(mental):
    """ブレ幅B = 5 + 15×(1−メンタル/100)"""
    return 5 + 15 * (1 - mental / 100)

# ============================================================
# 状態と基本操作
# ============================================================

@dataclass
class S:
    money: int = INIT_MONEY
    stamina: float = INIT_STAMINA
    fame: float = INIT_FAME
    sense: float = INIT_ABILITY
    idea: float = INIT_ABILITY
    expr: float = INIT_ABILITY
    chara: float = INIT_ABILITY
    mental: float = INIT_ABILITY
    compat: float = COMPAT_INIT
    # --- 経験点残高（正典v3・パワプロ式5通貨・GameState.exp* の鏡像。docs/exp_currency_redesign_v0.md） ---
    # 稼ぐ時は成長予算を消費せずここに貯まり、能力へ注ぐ瞬間だけ add()（①逓減→②予算→③clamp）を通る。
    # 通貨は能力名と別立て（1能力=複数通貨のブレンドで伸びる・1通貨=複数能力に寄与＝真の多対多）。
    # ABILITY_RECIPE が通貨→能力の重み表（Leontief固定比率＝最も乏しい通貨がボトルネック）。
    exp_hirameki: float = 0.0    # 閃き（アイデアの瞬発力）
    exp_goi: float = 0.0         # 語彙（言葉の引き出し）
    exp_maai: float = 0.0        # 間合い（間・テンポ）
    exp_sonzaikan: float = 0.0   # 存在感（華・舞台映え）
    exp_tanryoku: float = 0.0    # 胆力（メンタルの土台）
    # 記録
    osaka_in: bool = False
    osaka_win: bool = False
    gpq_pass: bool = False
    champion: bool = False
    min_money: int = INIT_MONEY

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def add(s, key, amt):
    if key == "compat":
        if COMPAT_GROWS:
            # 0012 相性凍結（golden-inert・GameEngine.add と鏡像）: freeze中は増加だけ止める（減算は通す）。
            # gen_golden はイベント非発火＝compat_freeze は常に0（getattr既定）＝この分岐は恒等 no-op＝golden不変。
            if getattr(s, "compat_freeze", 0) > 0 and amt > 0:
                pass
            else:
                s.compat = clamp(s.compat + amt, 0, COMPAT_CAP)
    elif key == "stamina":
        s.stamina = clamp(s.stamina + amt, 0, 100)
    elif key == "fame":
        s.fame = clamp(s.fame + amt, 0, 100)
    else:
        # 能力5種: 成長逓減（正の上昇のみ）を掛けてから上限にクランプ
        if GROWTH_DECAY_D and amt > 0:
            basis = jitsuryoku(s) if (GROWTH_DECAY_TOTAL and key != "mental") else getattr(s, key)
            amt = amt * max(0.0, 1 - basis / GROWTH_DECAY_D)
        if YEAR_GROWTH_CAP is not None and amt > 0 and key != "mental":
            w = dict(sense=W_SENSE, idea=W_IDEA, expr=W_EXPR, chara=W_CHARA)[key]
            budget = YEAR_GROWTH_CAP - getattr(s, "_yg", 0.0)
            amt = max(0.0, min(amt, budget / w))
            s._yg = getattr(s, "_yg", 0.0) + amt * w
        cap = MENTAL_CAP if key == "mental" else ABILITY_CAP
        setattr(s, key, clamp(getattr(s, key) + amt, 0, cap))

def jitsuryoku(s):
    return s.sense * W_SENSE + s.idea * W_IDEA + s.expr * W_EXPR + s.chara * W_CHARA

# ============================================================
# 経験点の割り振り（注ぐ側）—— GameCore/Allocation.swift の厳密な鏡像（ルール5）。正典v3（パワプロ式5通貨）。
# projected_gain / pour_step / recommended_plan の3関数は Swift と同値（同一式・同一順序）。
# RandomSource を一切呼ばない＝乱数消費順は不変。数値は全て【仮】（docs/exp_currency_redesign_v0.md）。
# ============================================================

ALLOCATION_STEP  = 1.0     # 割り振り1段で注ぐ「生の伸び試行量」（GameConfig.allocationStep と同期）
EXP_SUPPLY_SCALE = 0.48    # 【仮】稽古発行の通貨供給スケール（GameConfig.expSupplyScale と同期・旧較正値を継承）
POUR_EPS         = 1e-9    # 浮動小数の塵で粒を空費しない下限（GameEngine.pourEpsilon と同期）

# 経験点通貨5種（能力名と別立て＝真の多対多。ExpCurrency.allCases の鏡像）
CURRENCIES = ["hirameki", "goi", "maai", "sonzaikan", "tanryoku"]
CURRENCY_ATTR = {c: f"exp_{c}" for c in CURRENCIES}

# 能力→通貨レシピ（Leontief固定比率＝1能力=複数通貨のブレンド。1通貨=複数能力に寄与）。
# GameConfig.abilityRecipes の鏡像。重みは全て【仮】（sim較正で確定）。
ABILITY_RECIPE = {
    "sense":  [("hirameki", 0.45), ("maai", 0.35), ("tanryoku", 0.20)],
    "idea":   [("hirameki", 0.65), ("goi", 0.35)],
    "expr":   [("goi", 0.35), ("maai", 0.65)],
    "chara":  [("sonzaikan", 0.70), ("hirameki", 0.30)],
    "mental": [("sonzaikan", 0.25), ("tanryoku", 0.75)],
}
# add() の予算②で使う実力値換算重み（mental は 0＝予算を通らない）
_W = {"sense": W_SENSE, "idea": W_IDEA, "expr": W_EXPR, "chara": W_CHARA, "mental": 0.0}

# 正典v3-1（2026-08-03オーナー指示「能力が上がるほど必要な経験点も変動する」への対応。
# パワプロ実機リサーチ確認済み: 査定値表は現在ランクが上がるほど1段あたりの必要経験点が段階的に増える
# （帯ごとの階段状カーブ・g→sで数倍に跳ね上がる）。GameConfig.abilityRankCostBands の鏡像。
# しきい値は Theme.rank の等級ラダー（G/F/E/D/C/B/A/S）と同じ帯＝UIの等級表示と経済上の意味が一致する。
# 数値は全て【仮】（sim較正で確定・docs/exp_currency_redesign_v0.md §7-1）。
RANK_COST_BANDS = [(15, 1.00), (25, 1.15), (35, 1.35), (45, 1.60), (55, 2.00), (70, 2.50), (90, 3.20)]
RANK_COST_MULT_S = 4.20   # 最終帯（S・90以上）のデフォルト倍率

def _rank_cost_multiplier(value):
    """現在値が高いほど1段あたりの通貨消費が重くなる倍率（等級帯の階段状カーブ）"""
    for threshold, mult in RANK_COST_BANDS:
        if value < threshold:
            return mult
    return RANK_COST_MULT_S

def projected_gain(s, key, amount):
    """add() の①逓減→②予算キャップ→③clamp と同一式で「見える伸び」を副作用なしで返す純関数。
    GameEngine.projectedGain の鏡像。s._yg（=growthUsed）と YEAR_GROWTH_CAP（=growthBudget）を参照。
    通貨変換とは独立＝amount は既に「能力への生の伸び試行量」（呼び出し側がボトルネックで決める）"""
    if amount <= 0:
        return 0.0
    amt = amount
    if GROWTH_DECAY_D:
        basis = jitsuryoku(s) if (GROWTH_DECAY_TOTAL and key != "mental") else getattr(s, key)
        amt = amount * max(0.0, 1 - basis / GROWTH_DECAY_D)
    if YEAR_GROWTH_CAP is not None and amt > 0 and key != "mental":
        w = _W[key]
        remaining = YEAR_GROWTH_CAP - getattr(s, "_yg", 0.0)
        amt = max(0.0, min(amt, remaining / w))
    cap = MENTAL_CAP if key == "mental" else ABILITY_CAP
    return clamp(getattr(s, key) + amt, 0, cap) - getattr(s, key)

def _affordable_raw(s, key):
    """レシピの通貨残高から「このステップで注げる生の伸び試行量」をボトルネック（最も乏しい通貨）で決める。
    ある通貨の重みが0.5・現在ランクの倍率が2.0で残高がbなら、その通貨だけで賄える生量は b/(0.5×2.0)。
    全通貨中の最小値が実際に払える量。現在ランクが高いほど倍率が重くなる＝同じ通貨残高でも段が伸びにくくなる
    （正典v3-1・階段状の等級コスト）。ALLOCATION_STEP を上限にクランプ（段刻みループ正典・論点C不変）"""
    recipe = ABILITY_RECIPE[key]
    mult = _rank_cost_multiplier(getattr(s, key))
    afford = min((getattr(s, CURRENCY_ATTR[c]) / (w * mult) for c, w in recipe), default=0.0)
    return min(ALLOCATION_STEP, afford)

def pour_step(s, key):
    """1段（ボトルネック通貨で決まる生量・端数はあるだけ）を key に注ぐ。GameEngine.pourStep の鏡像。
    レシピの全通貨を同じ比率で、かつ現在ランクの等級コスト倍率ぶん上乗せして同時消費（Leontief×階段コスト）。
    見える伸びが無い段は通貨を消費しない。戻り値=実効伸び"""
    amount = _affordable_raw(s, key)
    if amount <= POUR_EPS:
        return 0.0
    gain = projected_gain(s, key, amount)
    if gain <= POUR_EPS:
        return 0.0
    mult = _rank_cost_multiplier(getattr(s, key))
    for c, w in ABILITY_RECIPE[key]:
        attr = CURRENCY_ATTR[c]
        setattr(s, attr, getattr(s, attr) - amount * w * mult)
    add(s, key, amount)   # ①逓減→②予算（s._yg 更新）→③clamp
    return gain

ALL_ABILITIES = ["sense", "idea", "expr", "chara", "mental"]   # Ability.allCases と同順

def recommended_plan(s):
    """おすすめ注ぎ（決定論・golden台本の単一純関数）。GameEngine.recommendedPlan の鏡像。
    正典v3: 通貨が能力間で共有される（同じ通貨を複数能力が奪い合う）ため、旧来の「ロック→共通枠」2段では
    なく、注げる（gain>0）能力の中で現在値が最も低いものへ毎ステップ回す単一の追いつきループに一般化した。
    scratch のコピーで計画を作る（呼び出し側が本適用する＝表示と確定が食い違わない）"""
    import copy
    scratch = copy.copy(s)
    plan = []
    guard = 0
    while guard < 10_000:
        candidates = [a for a in ALL_ABILITIES if _affordable_raw(scratch, a) > POUR_EPS]
        if not candidates:
            break
        target = min(candidates, key=lambda a: getattr(scratch, a))
        if pour_step(scratch, target) <= 0:
            break
        plan.append(target)
        guard += 1
    return plan

def apply_allocation(s, taps):
    """タップ列（recommended_plan の戻り値）を本状態に適用。WeekRunner.applyAllocation の鏡像"""
    for a in taps:
        pour_step(s, a)

def pour_all(s):
    """行動直後の即時全量注ぎ（golden台本）: recommended_plan を作って本適用する。
    人ボット・simボット・golden の3系統が全てこの1経路を使う（台本分裂＝golden毒源を作らない）"""
    apply_allocation(s, recommended_plan(s))

def credit_currency(s, currency, v):
    """稽古発行: 通貨への正の加算 v を供給スケールで割り引いて積む。GameEngine.creditCurrency の鏡像。
    通貨はどの能力にも直接ロックされない＝発行側はもう1:1マッピングを持たない（正典v3の核）"""
    if v <= 0:
        return   # 負・ゼロは実運用では発生しない（稽古の main/sub は常に正）
    attr = CURRENCY_ATTR[currency]
    setattr(s, attr, getattr(s, attr) + v * EXP_SUPPLY_SCALE)

# ============================================================
# 行動
# ============================================================

DEBT_TRAIN_FACTOR = 0.5    # 【正典v2】借金中は稽古が半分しか身にならない（生活苦・rule_holes_v0 §2）

def do_training(s, name):
    t = TRAININGS[name]
    if t["cost"] > 0 and s.money < t["cost"]:   # 有料行動のみ所持金必須【仮の実装解釈・仕様未定義】
        return False
    fac = DEBT_TRAIN_FACTOR if (DEBT_TRAIN_FACTOR is not None and s.money < 0) else None
    s.money -= t["cost"]
    # 正典v3: "cur:xxx" タグは経験点通貨へ（発行側・会計移設）。それ以外（compat等）は経済外＝add 直結のまま。
    # 借金倍率は通貨の量に掛ける（能力でなく通貨に）。cost/stamina/fame も従来どおり。
    def _grow(k, v):
        amt = v if fac is None else v * fac
        if k.startswith("cur:"):
            credit_currency(s, k[4:], amt)
        else:                   # compat など＝経済外
            add(s, k, amt)
    k, v = t["main"]; _grow(k, v)
    if t["sub"]:
        k, v = t["sub"]; _grow(k, v)
    add(s, "stamina", t["stam"])
    if t["fame"]:
        add(s, "fame", t["fame"])
    return True

def do_job(s, name):
    inc, st = JOBS[name]
    s.money += inc
    add(s, "stamina", st)

def do_offer(s, offer):
    s.money += offer["income"]
    add(s, "fame", offer["fame"])
    if offer["ability"]:
        k, v = offer["ability"]; add(s, k, v)
    add(s, "stamina", offer["stam"])

def do_rest(s, name):
    rec, (k, v) = RESTS[name]
    add(s, "stamina", rec)
    add(s, k, v)

def roll_offer(s, rng):
    rate = next(r for cap, r in OFFER_RATES if s.fame < cap)
    if rng.random() < rate:
        return dict(rng.choice([OFFER_MONEY, OFFER_EXP]))
    return None

BURST_P     = 0.10   # 【正典v2】「ハマった夜」の発生率（勝負ごとの独立な運・メンタル非依存）
BURST_BONUS = 12.0   # 【正典v2】ハマった夜のスコア加点（A案: 決勝到達を特別体験に戻すレバー・exp_v2_anchor）

def perform(s, line, rng):
    b = blur_width(s.mental)
    roll = rng.uniform(-b, b)
    if BURST_P and rng.random() < BURST_P:   # 0/Noneはdraw自体を消費しない（Swift側 burstP>0 と同義・レッドチーム指摘で対称化）
        roll += BURST_BONUS
    pen = 0
    for th, p in STAM_PEN:
        if s.stamina < th:
            pen = p
            break
    score = jitsuryoku(s) + s.compat + roll + pen
    return score >= line, score

# ============================================================
# 戦略ボット（全て【仮】の方針。人間の代役）
# ============================================================

FREE_ROT = ["ネタ作り", "ネタ合わせ", "フリーライブ"]

class Policy:
    name = "base"
    def choose(self, s, week, offer, rng):
        raise NotImplementedError
    def enter_osaka(self, s):
        return True
    def transport(self, s):
        return BUS

class PRandom(Policy):
    name = "ランダム"
    def choose(self, s, week, offer, rng):
        opts = [("job", j) for j in JOBS] + [("rest", r) for r in RESTS]
        opts += [("train", t) for t, d in TRAININGS.items() if d["cost"] <= s.money]
        if offer:
            opts.append(("offer", None))
        return rng.choice(opts)

class PWork(Policy):
    name = "バイト全振り"
    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)
        if s.stamina < 20:
            return ("rest", "完全休養")
        return ("job", "標準")
    def transport(self, s):
        return TRAIN if s.money >= 200_000 else BUS

class PTrain(Policy):
    name = "稽古全振り(無料)"
    def choose(self, s, week, offer, rng):
        if s.stamina < 30:
            return ("rest", "完全休養")
        return ("train", FREE_ROT[week % 3])

class PBalanced(Policy):
    name = "バランス型"
    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)
        if s.money < 150_000:
            return ("job", "標準")
        if s.stamina < 40:
            return ("rest", "完全休養")
        if s.money >= 500_000:
            return ("train", "ネタ見せ会")
        return ("train", FREE_ROT[week % 3])
    def transport(self, s):
        return TRAIN if s.money >= 150_000 else BUS

class PSmart(Policy):
    name = "調整型(賢い)"
    def choose(self, s, week, offer, rng):
        # 大会前週は体力を整える
        if week in (OSAKA_WEEK - 1, GPQ_WEEK - 1, GPF_WEEK - 1) and s.stamina < 75:
            return ("rest", "完全休養")
        if offer:
            return ("offer", None)
        if s.money < 130_000:
            return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "完全休養")
        if s.mental < 45 and s.money >= 300_000:
            return ("train", "ランニング・サウナ")
        if s.money >= 450_000:
            return ("train", "ネタ見せ会")
        # 弱点補強: 主効果対象が最も低い無料稽古
        cands = [("ネタ作り", s.idea), ("ネタ合わせ", s.sense), ("フリーライブ", s.chara)]
        cands.sort(key=lambda x: x[1])
        return ("train", cands[0][0])
    def transport(self, s):
        return TRAIN if s.money >= 150_000 else BUS

# ============================================================
# 1年（48週）を回す
# ============================================================

def run_one(pol, seed):
    rng = random.Random(seed)
    s = S()
    for week in range(1, WEEKS + 1):
        acted = False

        if week == OSAKA_WEEK and pol.enter_osaka(s):
            tr = pol.transport(s)
            if s.money >= tr["cost"]:
                s.money -= tr["cost"]
                add(s, "stamina", tr["stam"])
                s.osaka_in = True
                ok, _ = perform(s, OSAKA_LINE, rng)
                if ok:
                    s.osaka_win = True
                    s.money += OSAKA_PRIZE
                    add(s, "fame", FAME_PASS)
                acted = True
        elif week == GPQ_WEEK:
            ok, _ = perform(s, GPQ_LINE, rng)  # 東京・遠征不要・全員エントリー【仮】
            if ok:
                s.gpq_pass = True
                add(s, "fame", FAME_PASS)
            acted = True
        elif week == GPF_WEEK and s.gpq_pass:
            ok, _ = perform(s, GPF_LINE, rng)
            if ok:
                s.champion = True
                s.money += GPF_PRIZE
                add(s, "fame", FAME_CHAMP)
            acted = True

        if not acted:
            offer = roll_offer(s, rng)
            act, arg = pol.choose(s, week, offer, rng)
            if act == "train":
                if not do_training(s, arg):
                    do_rest(s, "完全休養")   # 払えなければ休むにフォールバック
            elif act == "job":
                do_job(s, arg)
            elif act == "offer" and offer:
                do_offer(s, offer)
            elif act == "rest":
                do_rest(s, arg)

        pour_all(s)   # 会計移設: 行動直後に粒を全量注ぐ（稽古以外の週は空注ぎ）

        if week % LIVING_INTERVAL == 0:
            s.money -= LIVING_COST
        s.min_money = min(s.min_money, s.money)
    return s

def simulate(pol_cls, n, base_seed=20260704):
    pol = pol_cls()
    outs = [run_one(pol, base_seed + i) for i in range(n)]
    pct = lambda f: 100.0 * sum(1 for o in outs if f(o)) / n
    med = lambda f: statistics.median(f(o) for o in outs)
    return dict(
        name=pol.name,
        osaka_in=pct(lambda o: o.osaka_in),
        osaka_win=pct(lambda o: o.osaka_win),
        gpq=pct(lambda o: o.gpq_pass),
        champ=pct(lambda o: o.champion),
        money=med(lambda o: o.money),
        min_money=med(lambda o: o.min_money),
        jitsu=med(jitsuryoku),
        fame=med(lambda o: o.fame),
        mental=med(lambda o: o.mental),
    )

def yen(v):
    return f"{v / 10_000:+,.0f}万"

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    print(f"=== 漫才師育成SLG バランス検証 v0.2 | {WEEKS}週 × {n}回/戦略 | 逓減D={GROWTH_DECAY_D} 上限{ABILITY_CAP} | 数値は全て【仮】 ===")
    print(f"通過ライン: 大阪戎{OSAKA_LINE}(第{OSAKA_WEEK}週) / GP予選{GPQ_LINE}(第{GPQ_WEEK}週) / GP決勝{GPF_LINE}(第{GPF_WEEK}週)")
    print()
    hdr = f"{'戦略':　<10}| 戎出場% | 戎通過% | GP予選% | 優勝% | 最終所持金 | 年間最低金 | 実力値 | 知名度"
    print(hdr)
    print("-" * 86)
    for cls in (PRandom, PWork, PTrain, PBalanced, PSmart):
        r = simulate(cls, n)
        print(f"{r['name']:　<10}| {r['osaka_in']:6.1f}  | {r['osaka_win']:6.1f}  | "
              f"{r['gpq']:6.1f}  | {r['champ']:4.1f}  | {yen(r['money']):>9} | "
              f"{yen(r['min_money']):>9} | {r['jitsu']:5.1f}  | {r['fame']:5.1f}")
    print()
    print("※ 実力値=センス.30+発想.30+表現.25+華.15 の週48時点中央値。金額は中央値。")

if __name__ == "__main__":
    main()
