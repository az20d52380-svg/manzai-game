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

LIVING_COST     = 140_000  # 4週ごと（マイナスOK・ペナルティなし＝仕様どおり）
LIVING_INTERVAL = 4
# 【キュー90・§90】部屋の段（状態 s.room=0..2・既定0＝安アパート＝今と同一）。Swift: GameConfig.roomRents/roomHeals
ROOM_RENT = (0, 50_000, 150_000)   # 4週ごとの生活費への上乗せ
ROOM_HEAL = (0, 10, 20)            # 家で休む（完全休養・気分転換）の体力の戻りへの加算
ROOM_HOME_RESTS = ("完全休養", "気分転換")
def room_rent(s): return ROOM_RENT[getattr(s, "room", 0) or 0]
# 【候補 q9・家賃の抜け道の直しA（room_rent_exploit_v0）】その月に住んだ一番上の部屋の家賃を月末に払う。
# s.room_peak＝前回の支払いから今までに住んだ部屋の最高段（None＝その間に移っていない＝今の部屋）。乱数なし。
# Swift: GameEngine.moveRoom / rentDue / applyWeekEnd（支払いの後に roomPeak=nil）
def can_move_room(s, target):
    if target < 0 or target >= len(ROOM_RENT): return False
    if target <= (getattr(s, "room", 0) or 0): return True
    return s.money >= ROOM_RENT[target]
def move_room(s, target):
    if not can_move_room(s, target): return False
    cur = getattr(s, "room", 0) or 0
    peak = getattr(s, "room_peak", None)
    s.room_peak = max(cur if peak is None else peak, target)
    s.room = target
    return True
def rent_due(s):
    cur = getattr(s, "room", 0) or 0
    peak = getattr(s, "room_peak", None)
    return ROOM_RENT[max(cur, peak if peak is not None else 0)]
def pay_living(s):
    """月末の支払い（生活費＋その月に住んだ一番上の部屋の家賃）。払ったら room_peak を戻す"""
    s.money -= living_cost(s) + rent_due(s)
    s.room_peak = None

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

# --- 練習の場所（お金を払う良い場所・docs/money_items_neta_v1.md §1・オーナー確定 2026-10-13）【値は仮】---
# Swift: Training.喫茶店で書く/.ファミレスで書く（GameConfig.trainings）と同値。既定では TRAININGS に入れない
# ＝既存のボット・sim・golden の基準は不変。測る時だけ enable_places() で足す（tools/exp_places_v1.py）。
PLACE_TRAININGS = {
    "喫茶店で書く":   dict(main=("cur:hirameki", 4.5), sub=("cur:goi", 1.5), cost=10_000, stam=-20, fame=0),
    "ファミレスで書く": dict(main=("cur:hirameki", 4),   sub=("cur:goi", 1),   cost=5_000,  stam=-30, fame=0),
    # お店から移した「お金を払うやり方」（1週使う練習・money_items_neta_v1 §3）【仮】
    "作家の勉強会":   dict(main=("cur:hirameki", 6),   sub=("cur:goi", 3),     cost=80_000, stam=-20, fame=0),
    "ボイトレ":       dict(main=("cur:sonzaikan", 6),  sub=("cur:maai", 2),    cost=80_000, stam=-20, fame=0),
}

def enable_places(on=True):
    for k, v in PLACE_TRAININGS.items():
        if on:
            TRAININGS[k] = v
        else:
            TRAININGS.pop(k, None)

# --- バイト: (収入, 体力) ---
JOBS = {
    "キツい": (96_000, -30),
    "標準":   (64_000,  -20),
    "楽":     (32_000,  -10),
}

# --- オファー（体力消費は仕様未定義→【仮】-20。種類の出現比は50/50【仮】） ---
OFFER_MONEY = dict(name="お金重視", income=240_000, fame=1, ability=None,        stam=-20)
OFFER_EXP   = dict(name="経験重視", income=120_000, fame=3, ability=("expr", 2), stam=-20)
# キュー96（規律A・2026-10-18）：オファーに名前4種（平均は OFFER_MONEY/EXP と同じ）。EXP→ひな壇/ラジオ、MONEY→ロケ/営業（追加の乱数1回＝半々）
OFFERS_NAMED = [
    dict(name="ひな壇", income=120_000, fame=3, ability=("expr", 2), stam=-15),
    dict(name="ラジオ", income=100_000, fame=2, ability=("expr", 2), stam=-10),
    dict(name="ロケ",   income=220_000, fame=2, ability=None,        stam=-25),
    dict(name="営業",   income=280_000, fame=1, ability=None,        stam=-20),
]
OFFER_FATIGUE_WINDOW = 6     # テレビ慣れ：直近6週（今週−受けた週 < 6）
OFFER_FATIGUE_K      = 4     # その中に4回以上受けていたら、受けるたびに
OFFER_FATIGUE_D      = 0.5   # センスと表現を0.5ずつ下げる
OFFER_RATES = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]  # 区切り 20/50/80→10/30/55（キュー62・saturation §8）  # (知名度がこの値未満, 発生率/週)

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

FAME_OTHER_MULT = 0.6    # 知名度のその他の伸びの倍率（キュー62 案G・2026-10-15）【仮】。Swift GameConfig.fameOtherMult
FAME_OTHER_CAP  = 80.0   # その他の伸びが鈍っていく先【仮】。Swift GameConfig.fameOtherCap

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

# 特技（キュー106・規律A）：余った経験点の使い道。各1回きり・覚えたらずっと効く。状態 s.skills（set・既定なし＝今と同じ）。
# 費用は内部の単位（画面では×10）。Swift: Skill.swift。ボットは覚えない（golden不変）。
SKILL_COST = {
    "体が資本":     {"tanryoku": 4, "sonzaikan": 3},   # 体調ダウンの確率 ×0.7
    "愛され芸人":   {"sonzaikan": 6},                   # 知名度の伸び ×1.1（正の増分だけ）
    "やりくり上手": {"goi": 2, "maai": 4},              # 月末の生活費 −5%
    "相方思い":     {"sonzaikan": 3, "maai": 4},        # すれ違いの増え ×0.8（増えた週だけ）
}
SKILL_INJURY_MULT, SKILL_FAME_MULT, SKILL_LIVING_MULT, SKILL_RIFT_MULT = 0.7, 1.1, 0.95, 0.8

def has_skill(s, name):
    return name in getattr(s, "skills", ())

def learn_skill(s, name):
    """特技を覚える（足りる時だけ費用を引く）。覚えたら True。Swift: GameEngine.learnSkill"""
    if name not in SKILL_COST or has_skill(s, name):
        return False
    cost = SKILL_COST[name]
    if any(getattr(s, CURRENCY_ATTR[c]) < v for c, v in cost.items()):
        return False
    for c, v in cost.items():
        setattr(s, CURRENCY_ATTR[c], getattr(s, CURRENCY_ATTR[c]) - v)
    if not hasattr(s, "skills"):
        s.skills = set()
    s.skills.add(name)
    return True

def living_cost(s):
    return LIVING_COST * (SKILL_LIVING_MULT if has_skill(s, "やりくり上手") else 1.0)

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
        # キュー62 案G：その他の伸びは小さく・FAME_OTHER_CAP に近いほど鈍る（決勝進出・優勝は sim_career._fame_big／fame_champ）
        # Swift GameEngine.add(.知名度) と同じ演算順。旧挙動は FAME_OTHER_MULT=1.0・FAME_OTHER_CAP=inf
        if amt > 0:
            d = max(0.0, 1 - s.fame / FAME_OTHER_CAP)
            amt = amt * FAME_OTHER_MULT * (d * d)
            if has_skill(s, "愛され芸人"):
                amt *= SKILL_FAME_MULT
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
    k, v = t["main"]
    # アイテム（GameCore/Item.swift の鏡像）：ICレコーダー＝ネタ作りの主効果+、稽古場の年契約＝全稽古の主効果+。未購入は恒等
    if name == "ネタ作り" and getattr(s, "has_recorder", None):
        v += ITEM_RECORDER_BONUS
    if getattr(s, "studio_active", None):
        v += ITEM_STUDIO_BONUS
    _grow(k, v)
    if t["sub"]:
        k, v = t["sub"]; _grow(k, v)
    add(s, "stamina", t["stam"])
    if t["fame"]:
        add(s, "fame", t["fame"])
    return True

# ============================================================
# アイテム（GameCore/Item.swift の鏡像・docs/item_design_v0.md・全て【仮】）。購入は乱数を引かない
# ============================================================
ITEMS = {   # 名前: (価格, 年の上限 None=キャリア1回)
    "栄養ドリンク": (3_000, 6), "回復ドリンク大": (20_000, 4), "喉のケア用品": (20_000, 1), "銭湯の回数券": (10_000, 99), "中古のICレコーダー": (30_000, None),
    "新幹線回数券": (200_000, 1), "ネタ作家の勉強会": (150_000, 2), "ボイトレ短期集中": (250_000, 1),
    "稽古場の年契約": (2_400_000, 1),
}
ITEM_DRINK_STAMINA = 8.0
ITEM_DRINK_L_STAMINA = 20.0
ITEM_THROAT_INJURY_MULT = 0.5   # 喉のケア用品を今年持っていれば体調ダウン確率×0.5（item_counts は年初に消える）
ITEM_SENTO_TICKETS = 4
ITEM_SENTO_RECOVERY = 10.0
ITEM_RECORDER_BONUS = 1.0
ITEM_STUDIO_BONUS = 1.0
ITEM_STUDY = (4.0, 2.0)    # 閃き・語彙（通貨に直接）
ITEM_VOICE = (4.0, 2.0)    # 間合い・語彙（通貨に直接）

# お店で売る品（オーナー原則 2026-10-12「アイテムで能力は上がらない」・money_items_neta_v1 §3）。
# 能力に効く4品（ICレコーダー・勉強会・ボイトレ・稽古場の年契約）は売らない。Swift: GameConfig.shopLineup と同値。
SHOP_LINEUP = ["栄養ドリンク", "回復ドリンク大", "喉のケア用品", "銭湯の回数券", "新幹線回数券"]

def can_buy(s, item):
    if item not in SHOP_LINEUP:
        return False
    price, lim = ITEMS[item]
    if s.money < price:
        return False
    if item == "中古のICレコーダー":
        return not getattr(s, "has_recorder", None)
    if item == "銭湯の回数券" and getattr(s, "sento_tickets", None):
        return False
    if item == "新幹線回数券" and getattr(s, "shinkansen_active", None):
        return False
    if item == "稽古場の年契約" and getattr(s, "studio_active", None):
        return False
    counts = getattr(s, "item_counts", None) or {}
    return lim is None or counts.get(item, 0) < lim

def buy_item(s, item):
    if not can_buy(s, item):
        return False
    s.money -= ITEMS[item][0]
    counts = dict(getattr(s, "item_counts", None) or {})
    counts[item] = counts.get(item, 0) + 1
    s.item_counts = counts
    if item == "栄養ドリンク":
        add(s, "stamina", ITEM_DRINK_STAMINA)
    elif item == "回復ドリンク大":
        add(s, "stamina", ITEM_DRINK_L_STAMINA)
    elif item == "喉のケア用品":
        pass   # 効果は item_counts の有無で体調ダウン判定が読む（throat_mult）
    elif item == "銭湯の回数券":
        s.sento_tickets = ITEM_SENTO_TICKETS
    elif item == "中古のICレコーダー":
        s.has_recorder = True
    elif item == "新幹線回数券":
        s.shinkansen_active = True
    elif item == "ネタ作家の勉強会":
        s.exp_hirameki += ITEM_STUDY[0]; s.exp_goi += ITEM_STUDY[1]
    elif item == "ボイトレ短期集中":
        s.exp_maai += ITEM_VOICE[0]; s.exp_goi += ITEM_VOICE[1]
    elif item == "稽古場の年契約":
        s.studio_active = True
    return True

def throat_mult(s):
    """体調ダウン確率の係数。喉のケア用品をその年持っていれば0.5、なければ1（恒等）"""
    return ITEM_THROAT_INJURY_MULT if (getattr(s, "item_counts", None) or {}).get("喉のケア用品", 0) > 0 else 1.0

def reset_yearly_items(s):
    """年初（WeekRunner.init と同じ位置）。未購入は恒等"""
    for k in ("item_counts", "shinkansen_active", "studio_active"):
        if getattr(s, k, None) is not None:
            setattr(s, k, None)

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
    wk = getattr(s, "_wk", None)          # 通算の週（呼び出し側が行動直前に s._wk=(年-1)*48+週 を入れる）
    if wk is not None:
        hist = getattr(s, "offer_weeks", None) or []
        if offer_fatigued(s, wk):
            add(s, "sense", -OFFER_FATIGUE_D); add(s, "expr", -OFFER_FATIGUE_D)
        hist = [w for w in hist if wk - w < OFFER_FATIGUE_WINDOW] + [wk]
        s.offer_weeks = hist

def offer_fatigued(s, wk):
    """次にオファーを受けると腕が落ちるか（テレビ慣れ）"""
    hist = getattr(s, "offer_weeks", None) or []
    return sum(1 for w in hist if wk - w < OFFER_FATIGUE_WINDOW) >= OFFER_FATIGUE_K

# --- お金を払う休み（money_items_neta_v1 §2・オーナー案 2026-10-12）【値は仮】---
# Swift: Rest.サウナ/.温泉に一泊（GameConfig.rests/restCosts）と同値。既定では RESTS に入れない＝既存の基準不変。
PAID_RESTS = {
    "サウナ":     (80,  ("mental", 2)),
    "温泉に一泊": (100, ("mental", 2)),   # 相性+1 は帯を壊した（v3やり込み 初回優勝3.3→12.3%・§6-2）＝メンタルに【仮】
}
REST_COST = {"サウナ": 10_000, "温泉に一泊": 60_000}

def enable_paid_rests(on=True):
    for k, v in PAID_RESTS.items():
        if on:
            RESTS[k] = v
        else:
            RESTS.pop(k, None)

def do_rest(s, name, use_ticket=True):
    cost = REST_COST.get(name, 0)
    if cost > 0:
        if s.money < cost:          # 払えなければ家で寝る（Swift applyRest と同じ）
            name = "完全休養"
        else:
            s.money -= cost
    rec, (k, v) = RESTS[name]
    t = getattr(s, "sento_tickets", None)
    if t and use_ticket:                    # 銭湯の回数券（Item.swift 鏡像）。選んでいない療養週は使わない（WeekRunner applyRest useTicket:false・gamecore_review_1019 F3）
        rec += ITEM_SENTO_RECOVERY
        s.sento_tickets = t - 1
    room = getattr(s, "room", 0) or 0
    if room and name in ROOM_HOME_RESTS:
        rec += ROOM_HEAL[room]
    add(s, "stamina", rec)
    add(s, k, v)
    if room == 2 and name == "完全休養":
        add(s, "mental", 1)

def roll_offer(s, rng):
    rate = next(r for cap, r in OFFER_RATES if s.fame < cap)
    if rng.random() < rate:
        base = rng.choice([OFFER_MONEY, OFFER_EXP])
        i = (0 if base is OFFER_EXP else 2) + (1 if rng.random() < 0.5 else 0)   # 追加の乱数1回（名前）
        return dict(OFFERS_NAMED[i])
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
                s._wk = week
                do_offer(s, offer)
            elif act == "rest":
                do_rest(s, arg)

        pour_all(s)   # 会計移設: 行動直後に粒を全量注ぐ（稽古以外の週は空注ぎ）

        if week % LIVING_INTERVAL == 0:
            pay_living(s)
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
