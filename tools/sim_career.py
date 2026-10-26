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

# ラインは【正典v2 2026-07-05】docs/canonical_v2_spec.md 採用値（年齢カーブ上限・キャリア累計予算・
# 2層ブレ「ハマった夜」・生活ルール一式とセット）。イベント層ON計測で:
# のんびり改=優勝0.3%/決勝到達22%・やり込み=2.1%/43%・トロフィー30ptで21.6%（exp_v2_anchor / exp_v2_meta）
# 旧正典（準決86・決勝94・D解放）の実測値は docs の履歴注記を参照
# 予選ライン−2（1回戦〜準決勝・復活。決勝80はそのまま）: 7本統合で下がった決勝到達率を今の帯に戻す根拠 docs/combined7_bands_v0.md 追記・候補 docs/candidate_v0.md
GP_ROUNDS = [
    # (週, ライン, ラベル)      実在対応: 開催時期 / 通過組数(2025)。ライン【正典v2 2026-07-05】canonical_v2_spec
    (30, 16, "GP1回戦"),      # 8月中旬       / 11,521 → 1,912 (16.6%)
    (39, 24, "GP2回戦"),      # 10月中旬〜下旬 /  1,912 →   380 (19.9%)
    (41, 32, "GP3回戦"),      # 11月上旬       /    380 →   134 (35.3%)
    (43, 43, "GP準々決勝"),   # 11月中旬       /    134 →    30 (22%)
    (45, 72, "GP準決勝"),     # 12月上旬       /     31 →     9 (29%)
]
GP_REVIVAL_WEEK, GP_REVIVAL_LINE = 47, 74   # 敗者復活: 決勝-6（7本統合に伴い予選−2・docs/combined7_bands_v0.md 追記）
GP_FINAL_WEEK,   GP_FINAL_LINE   = 47, 80   # 決勝【正典v2】のんびり改0.3%・やり込み2.1%（exp_v2_anchor）
GP_PRIZE = B.GPF_PRIZE                       # 手元500万（表示1,000万の半分【仮】）
GP_ENTRY_FEE = 2_000    # 【正典v2】GPエントリー費（実在の賞レース準拠・1回戦週に徴収。払えなければその年は出場不可）

FAME_FINAL_BONUS = 1.5  # 決勝のみの人気補正【確定・機微】: 実効ライン = ライン − 1.5×(知名度−50)/50。judge_design §10-F
GP_ROUND_FAME = 3    # GP各回戦通過の知名度上昇【仮】
FAME_SMALL    = 5    # 小規模大会 通過+5【仮】
FAME_MID      = 10   # 中規模大会 通過+10【仮】
FAME_CHAMP    = 10   # グランプリ優勝+10（逓減なし＝2回目の優勝で100）【仮】キュー62 案G（q60_q62_proposal_v0 §2）

# ------------------------------------------------------------
# その他の大会カレンダー（毎年開催・全て架空名・全て【仮】）
# prize は「表示額の半分＝手元に入る額」。eligible(年目, 状態) で出場資格を判定
# ------------------------------------------------------------

TOURNAMENTS = {
    # 週: dict(名前, ライン, 手元賞金, 知名度, 大阪遠征, 資格)
    12: dict(name="春新人賞A",     line=30, prize=500_000, fame=FAME_MID,   osaka=True,
             ok=lambda year, s: year <= 10),          # 芸歴10年内
    15: dict(name="春新人賞B",     line=28, prize=250_000, fame=FAME_SMALL, osaka=True,
             ok=lambda year, s: year <= 10),          # 結成10年内
    27: dict(name="夏中堅賞",      line=33, prize=500_000, fame=FAME_MID,   osaka=True,
             ok=lambda year, s: year <= 10),          # デビュー10年内
    29: dict(name="大阪戎コンクール", line=B.OSAKA_LINE, prize=B.OSAKA_PRIZE, fame=FAME_SMALL,
             osaka=True,  ok=lambda year, s: True),   # ライン22【正典v2】・手元10万
    35: dict(name="若手限定賞",    line=28, prize=250_000, fame=FAME_SMALL, osaka=False,
             ok=lambda year, s: year <= 5),           # 1〜5年目のみ
    38: dict(name="推薦制中堅賞",  line=33, prize=500_000, fame=FAME_MID,   osaka=False,
             ok=lambda year, s: s.fame >= 30),        # 知名度30以上【仮】
    46: dict(name="寒梅漫才杯",    line=34, prize=250_000, fame=FAME_SMALL, osaka=False,
             ok=lambda year, s: year <= 10),          # 芸歴10年内・GP準決勝の翌週【仮】キュー98 §98（balance_q93_98_measure_v0）
}

EVENT_WEEKS = set(TOURNAMENTS) | {w for w, _, _ in GP_ROUNDS} | {GP_FINAL_WEEK}

# 敗者復活の実測用カウンタ（improvement_proposals_v0.md 課題#1）
REVIVAL_STATS = {"attempts": 0, "passes": 0}

# 周回トロフィー判定用の計測フック（sim_meta.py が dict を差して有効化。None なら計測しない）
RUN_TRACK = None

# ============================================================
# 突発イベント層（event_design_v0/v1・dialogue_batch2 の数値効果を代表近似）
# 既定OFF: ベースライン・golden生成には影響しない。exp_events.py がONにして分布への影響を測る
# ============================================================

EVENTS_ON   = False
RUN_EVENTS_FIRED = None   # set() を差すとキャリア内1回制になる（run_careerが管理）
EVENT_RATE  = 0.12   # 大会・GP週を除く週の発生率【仮】
EVENT_DRAW_FILTER = False   # True=Swift同様「発火帯に入っていて未発火の候補」だけから一様に引く（既定OFF＝従来の34種一様＋不発）
EVENT_FORCE = {}            # {others種名: 週 or (開始週,終了週)}。その週（窓内の最初の自由週）に未発火・発火帯ならロール無しで確定発火（既定空＝従来どおり）
EVENT_FIRE_CAP = None   # 効果つきイベントのキャリア通算発火上限（None=無制限）。会話増産時の総量予算（dialogue_batch3 §8）
DEBT_LIFE_PEN  = (-10, -3)   # 【正典v2】(体力Δ, メンタルΔ): 生活費支払い時に所持金<0なら課す生活苦
RIFT_ON        = True       # 途中解散（すれ違いゲージ）docs/dissolution_rift_spec_v1.md【仮】
RIFT_GAIN      = 0.5        # 相性が上がらなかった週の増え方 ×(上限−相性)/上限
RIFT_HEAL      = 3.0        # 相性が上がった週の減り方
RIFT_WARN      = 50.0       # 初めて越えた週末に予告（アプリ側の選択肢イベント）
RIFT_JOINT_STILL = True     # §94 二人で舞台に立つ週（ネタ見せ会・フリーライブ・大会・GP）で相性が上がらなくても、すれ違いは増えない（減りもしない）
GP_LOSS_COMPAT = (0.5, 0.5, 0.5, 0.25, 0.125)   # §94 GPの予選で落ちた時の相性の下げ幅（1〜3回戦・準々決勝・準決勝）。敗者復活・決勝・その他の大会の負けでは下げない
RIFT_JOINT_TRAIN = ("ネタ見せ会", "フリーライブ")   # §94 舞台に立つ稽古
RIFT_RESPOND   = False      # 実測用：予告に「向き合う」で応えるボット（rift −30・体力 −10）
# --- §102 飲みの誘い（先輩・後輩）: 不定期に何度も来る軽い気分転換の選択。docs/balance_q93_98_measure_v0.md §102【仮】 ---
INVITE_P       = 0.04       # 毎週末（rift_weekend の後）にこの率で誘いが来る（10年で約19回）
INVITE_MONEY   = 5_000      # 行く: 所持金 −
INVITE_STAMINA = -10        # 行く: 体力
INVITE_MENTAL  = 1          # 行く: メンタル
INVITE_IDEA    = 0.5        # 行く: 半分の確率で 発想 +
INVITE_IDEA_P  = 0.5
INVITE_GO      = True       # ボットの既定は「行く」（方針に choose_invite(s) があればそれを使う）。断る＝何も起きない
RUN_INVITE_SEED = None      # run_career が差すキャリアのシード（None=誘いなし）。本編の乱数とは独立
INVITE_COUNT   = 0          # 実測用: 来た回数
BANKRUPT_LINE  = -1_000_000   # 【正典v2】夜逃げライン: 下回ったらキャリア強制終了（rule_holes_v0 §2）
INJURY_ON      = True   # 【正典v2】低体力のキツいバイトに体調ダウン抽選（稽古はゲートで先に止まる）（rule_holes_v0。ゲーム内表記は「喉をやられた」「腰にきた」等——漫才師にケガという語は使わない）
INJURY_TH      = 50.0   # この体力未満で対象行動を選ぶとダウン抽選（§97実測: 20だと稽古ゲートに阻まれほぼ起きない→50）
INJURY_P_PER   = 0.005  # 不足1ptあたりのダウン確率（体力0で25%・体力40で5%）（§97）
INJURY_REST    = 3      # ダウン後の療養週数（行動強制）【仮】
INJURY_MENTAL  = -5.0   # ダウン時のメンタル打撃【仮】
INJURY_ABILITY = 0.0    # ダウン時のランダム演技能力の低下量（重症変種の比較用）【仮】
STAMINA_GATE   = 20.0   # 【正典v2】体力がこの値未満だと稽古を選べない（谷口が止める・rule_holes_v0 §3）
CAP_CURVE      = (6.0, 0.4, 2.0)   # 【正典v2】(基準, 傾き, 下限): その年の年間成長上限 = max(下限, 基準−傾き×(年−1))。正典v2の年齢カーブ（human_calibration §5）
CAREER_BUDGET  = True   # 【正典v2】成長予算をキャリア累計化（年初リセットせず、CAP_CURVEの累計が上限。初期能力ボーナスは予算の前借り＝canonical_v2_spec §2-B）
GROWTH_END_YEAR = 15    # 成長が完成する結成年数（GP挑戦資格15年のloreと一致）【仮】
# (所持金Δ, 体力Δ, 知名度Δ, 能力キーorNone, 能力Δ) — 各ドキュメントの効果つきイベント18種の代表値
EVENT_TABLE = [
    (0,  10, 0, None, 0),          # 廃棄弁当/班長の弁当
    (0,   5, 0, "idea", 1),        # 百円パスタの発明
    (0,  20, 0, None, 0),          # 先輩の焼肉（相性+1は近似で省略）
    (0, -20, 0, None, 0),          # 流行り風邪/労働のギックリ
    (0,   0, 2, "mental", 2),      # 伝説の出待ち
    (0,   0, 0, "sense", 2),       # 楽屋の神様
    (0,   0, 3, None, 0),          # 切り抜きバズ（減衰は省略）
    (0,   0, 2, "idea", 1),        # 深夜ラジオ採用
    (30_000, 0, 0, None, 0),       # シフトの恩人
    (0,   0, 0, "mental", -3),     # 同期の解散（発想+2とセット）
    (0,   0, 0, "idea", 2),        # 対バンの化け物/夜勤明けの発明
    (10_000, 0, 1, None, 0),       # 財布を拾う/福引き係
    (0,   0, 0, "mental", 2),      # 占い師/銭湯の常連
    (-20_000, 0, 0, "chara", 2),   # 古着屋の衣装（ミニ二択の採択側近似）
    (-8_000, -10, 0, "idea", 2),   # 先輩の飲み
    (-5_000, 0, 0, None, 0),       # 谷口の誕生日（相性+2は近似で省略）
    (0, -10, 0, "expr", 2),        # 照明さんの雑談
    (0,   5, 0, "mental", 1),      # 常連のおばあちゃん
]
# --- 相方以外の人とのイベント 0041〜0049（preview-all: ChoiceEvent.swift / choice_events_others_v1.md・2026-10-16）---
# 既定OFF（golden・既存実測は不変）。ONにすると既存プール(EVENT_TABLE 18種)に9種が加わり、同じ12%抽選の一様選択に入る
# （発火帯に入っていない／発火済みの引きは不発＝総発火数は増えない）。選択はボット共通の方針（OTHERS_CHOICE）。
OTHERS_ON = False
OTHERS_EVENTS = ["kouhai", "senpai", "crew", "postcard", "douki", "inventory", "homecoming", "fan", "ticket",
                 # 第2束 0051〜0057（docs/choice_events_more_v1.md・2026-10-16）
                 "festival", "tv", "renovation", "classmate", "fever", "notebook", "yearend"]
def _others_fireable(k, s, week, year, honban_ahead):
    """honban_ahead: 次の本番(大会・GP回戦)までの週数（無ければ99）。jobs=この年までのバイト回数"""
    jobs = getattr(s, "_jobs", 0)
    if k == "kouhai":    return s.money >= 20_000 and (year >= 2 or week >= 24)
    if k == "senpai":    return s.stamina >= 40 and honban_ahead >= 2
    if k == "crew":      return week >= 8
    if k == "postcard":  return s.fame >= 10 and s.money < 200_000
    if k == "douki":     return week >= 16 and s.fame < 40 and s.money >= 20_000
    if k == "inventory": return s.money < 150_000 and jobs >= 3
    if k == "homecoming":return week >= 41 and honban_ahead >= 3
    if k == "fan":       return s.fame >= 15
    if k == "ticket":    return s.fame < 30
    # 第2束 0051〜0057（第1週=1月・4週で1か月＝calendar_wording_1026_v0 案②）
    if k == "festival":  return 26 <= week <= 32 and s.stamina >= 40 and honban_ahead >= 2
    if k == "tv":        return week >= 20 and s.fame < 30
    if k == "renovation":return week >= 12 and s.fame < 40
    if k == "classmate": return week >= 10 and s.fame >= 5
    if k == "fever":     return week >= 6 and s.stamina < 50
    if k == "notebook":  return week >= 10 and bool(getattr(s, "netas", None))
    if k == "yearend":   return 45 <= week <= 48 and s.money >= 1500   # 選択肢が全部お金ゲート＝1500未満は出さない（全イベント共通の決まり）
    return False
def _ev_add(s, key, amt):
    """選択肢イベントの効果1件。EVENTS_APP=True ではアプリ（ChoiceEventEffect.swift applyEventEffect）と同じ
    『素の加減算＋clamp』＝成長逓減・年予算・知名度の鈍化・相性凍結を通さない（gamecore_review_1019 F2）。
    EVENTS_APP=False（sim 独自のイベント模型）は従来どおり B.add。gen_golden はイベントを回さない＝golden 不変。"""
    if not EVENTS_APP:
        return B.add(s, key, amt)
    if key == "compat":
        if B.COMPAT_GROWS:   # 相性を育てない設定ではイベントでも動かさない（B.add と同じ・review_today_fixes_1019 §5）
            s.compat = B.clamp(s.compat + amt, 0, B.COMPAT_CAP)
    elif key in ("stamina", "fame"):
        setattr(s, key, B.clamp(getattr(s, key) + amt, 0, 100))
    else:
        cap = B.MENTAL_CAP if key == "mental" else B.ABILITY_CAP
        setattr(s, key, B.clamp(getattr(s, key) + amt, 0, cap))

def _others_apply(s, k):
    """ボット共通の方針: 余裕(お金5万+/体力50+)があれば人の方（A）へ、なければ B。効果はChoiceEvent.swiftの値"""
    A = lambda: None
    if k == "kouhai":
        if s.money >= 50_000: s.money -= 8000; _ev_add(s, "chara", 1); _ev_add(s, "mental", 1)
        else: _ev_add(s, "chara", -1); _ev_add(s, "mental", -1); _ev_add(s, "stamina", 5)
    elif k == "senpai":
        if s.stamina >= 60: _ev_add(s, "sense", 1); _ev_add(s, "mental", 1); _ev_add(s, "stamina", -15)
    elif k == "crew":
        if s.stamina >= 50: _ev_add(s, "fame", 1); _ev_add(s, "stamina", -10)
        else: _ev_add(s, "stamina", 5)
    elif k == "postcard":
        if s.stamina >= 50: s.money += 15_000; _ev_add(s, "idea", 1); _ev_add(s, "stamina", -10)
        else: _ev_add(s, "compat", 1)
    elif k == "douki":
        if s.money >= 50_000 and s.stamina >= 50: _ev_add(s, "fame", 2); s.money -= 10_000; _ev_add(s, "stamina", -10)
        else: _ev_add(s, "compat", 1)
    elif k == "inventory":
        if s.stamina >= 50: s.money += 20_000; _ev_add(s, "stamina", -15)
        else: _ev_add(s, "expr", 1)
    elif k == "homecoming":
        if s.money >= 50_000: _ev_add(s, "stamina", 15); _ev_add(s, "mental", 1); s.money -= 12_000
        else: _ev_add(s, "expr", 1); _ev_add(s, "mental", -1)
    elif k == "fan":
        if s.money >= 30_000: _ev_add(s, "chara", 1); _ev_add(s, "fame", 1); s.money -= 5000
    elif k == "ticket":
        if s.stamina >= 50: _ev_add(s, "fame", 1); _ev_add(s, "stamina", -10)
        elif s.money >= 6000: s.money -= 6000; _ev_add(s, "expr", 1)
    # 第2束 0051〜0057（効果は ChoiceEvent.swift と同値。方針は同じ「余裕があれば人・外の方（A）」）
    elif k == "festival":
        if s.stamina >= 55: s.money += 12_000; _ev_add(s, "fame", 1); _ev_add(s, "stamina", -15)
        else: _ev_add(s, "stamina", 10); _ev_add(s, "mental", 1)
    elif k == "tv":
        if s.stamina >= 50 or s.money < 1000: _ev_add(s, "sense", 1); _ev_add(s, "mental", -1)
        else: _ev_add(s, "stamina", 10); _ev_add(s, "mental", 1); s.money -= 1000
    elif k == "renovation":
        if s.money >= 50_000 and s.stamina >= 50: _ev_add(s, "fame", 2); s.money -= 8000; _ev_add(s, "stamina", -10)
        else: _ev_add(s, "expr", 1); _ev_add(s, "stamina", -5)
    elif k == "classmate":
        if s.stamina >= 50: _ev_add(s, "fame", 1); _ev_add(s, "mental", 1); _ev_add(s, "stamina", -10)
        else: _ev_add(s, "compat", 1); _ev_add(s, "stamina", 5)
    elif k == "fever":
        if s.money >= 2000: _ev_add(s, "compat", 2); s.money -= 2000; _ev_add(s, "stamina", -5)
        else: _ev_add(s, "expr", 1)
    elif k == "notebook":
        if s.stamina >= 50 and s.money >= 1500: _ev_add(s, "mental", 1); _ev_add(s, "stamina", -10); s.money -= 1500
        else: _ev_add(s, "idea", 1); _ev_add(s, "mental", -1)
    elif k == "yearend":
        if s.money >= 50_000: _ev_add(s, "sense", 1); _ev_add(s, "fame", 1); s.money -= 5000; _ev_add(s, "stamina", -10)
        elif s.money >= 1500: _ev_add(s, "compat", 1); _ev_add(s, "mental", 1); s.money -= 1500

def _honban_ahead(week):
    ws = sorted(set(list(TOURNAMENTS.keys()) + [r[0] for r in GP_ROUNDS]))
    return min([w - week for w in ws if w > week] or [99])

# --- 実測用: アプリ(GameSession.swift 週次抽選)と同じ選択肢イベント。既定OFF（False では従来と1ビットも変わらない）---
# True の時だけ: 旧プール(EVENT_TABLE 18種＋OTHERS)と SEASONAL は使わず、固有9種＋相方以外16種＝25種を「週頭（行動前）の状態」で判定する。
# 確定発火（justLost・styleTalk・passFork・前夜・earlyFormality・tsuuka・nameless・taniguchi）が立つ週は週次抽選を引かない。
# 乱数は本編 rng と独立（s._app_rng）＝本編の乱数列は動かさない。riftWarning・weekendInvite は未対応（別実装 RIFT_ON / invite_weekend のまま）。
# docs/events_app_parity_v0.md
EVENTS_APP     = False
APP_EVENT_CAP  = 15      # GameConfig.weeklyEventCap（確定発火は数えない）
APP_UNIQUE = ["brokedrink", "meishi", "peerchair", "lineuptop", "greenroom", "lasttrain", "luckythird", "wrote", "photo"]
APP_POOL   = APP_UNIQUE + OTHERS_EVENTS      # 25種

def _app_state(s, seed=None):
    a = s.__dict__.get("_app")
    if a is None:
        a = dict(fired=set(), count=0, loss=0, jp=False, jl=False, style_done=False,
                 lost_fired=False, fork_fired=False, eve_fired=False, early_done=False,
                 tsuuka_done=False, nameless_fired=False, tani_fired=False, counts={})
        s._app = a
        s._app_rng = random.Random(0xA11CE if seed is None else (seed * 2654435761 + 0x5EED) & 0xFFFFFFFF)
    return a

def _app_result(s, passed):
    """大会・GPの結果（アプリ pump の lossStreak / justPassed / justLost 更新）"""
    a = _app_state(s)
    if passed:
        a["loss"] = 0; a["jp"] = True; a["jl"] = False; a["style_done"] = False
    else:
        a["loss"] += 1; a["jp"] = False; a["jl"] = True

def _app_stages(s, year, week, gp_alive, gp_stage, finalist, revival):
    """GameSession.upcomingStages 相当（自由週＝今週は含めない）。[(週, 高格か)]"""
    ms = []
    if gp_alive:
        for i in range(gp_stage, len(GP_ROUNDS)):
            ms.append((GP_ROUNDS[i][0], i == len(GP_ROUNDS) - 1))
    if finalist or gp_alive:
        ms.append((GP_FINAL_WEEK, True))
    elif revival:
        ms.append((GP_REVIVAL_WEEK, True))
    for w, t in TOURNAMENTS.items():
        if t["ok"](year, s):
            ms.append((w, True))
    return sorted(m for m in ms if m[0] > week)

def _app_band(k, s, week, year, ahead, nxt, a):
    if k == "brokedrink": return s.money < 50_000 and s.compat < B.COMPAT_CAP
    if k == "meishi":     return s.money < 200_000 and s.fame < 50
    if k == "peerchair":  return week >= 20
    if k == "lineuptop":  return s.fame < 20
    if k == "greenroom":  return 8 <= int(s.compat) <= 14
    if k == "lasttrain":  return s.fame < 20
    if k == "luckythird":
        return s.stamina >= 80 and a["loss"] == 0 and nxt is not None and 2 <= nxt[0] - week <= 4
    if k == "wrote":      return bool(getattr(s, "netas", None))
    if k == "photo":      return 20 <= s.fame <= 50
    if k == "homecoming": return week >= 41 and ahead > 3          # アプリ: noTournamentWithin3Weeks（sim 旧は >=3）
    return _others_fireable(k, s, week, year, ahead)

def _app_weak4(s):
    return min(["sense", "idea", "expr", "chara"], key=lambda x: getattr(s, x))

def _app_apply(s, k):
    """固有9種＋確定発火の効果（ChoiceEvent.swift と同値）。方針は _others_apply と同じ『余裕(体力50+等)があれば A』。None=効果なし/フレーバー"""
    weaker = lambda: ("sense" if s.sense <= s.idea else "idea")
    if k == "brokedrink":
        if s.money >= 10_000: s.money -= 4000; _ev_add(s, "compat", 1); _ev_add(s, "mental", 1)
        else: _ev_add(s, "idea", 1); _ev_add(s, "mental", -1)
    elif k == "meishi":
        if s.stamina >= 50: _ev_add(s, "chara", 1); _ev_add(s, "fame", 2); _ev_add(s, "mental", -1)
        else: _ev_add(s, "stamina", 15); _ev_add(s, "mental", 1); _ev_add(s, "compat", 1)
    elif k == "peerchair":
        if s.stamina >= 50: _ev_add(s, "fame", 2); _ev_add(s, "stamina", -10); _ev_add(s, "mental", -1)
        else: _ev_add(s, "mental", 1); _ev_add(s, "compat", 1)
    elif k == "lasttrain":
        if s.stamina >= 50: _ev_add(s, "mental", -2); _ev_add(s, "stamina", -5); _ev_add(s, weaker(), 2)
        else: _ev_add(s, "stamina", 5); _ev_add(s, "mental", 1); _ev_add(s, "compat", 1); s.money -= 800
    elif k == "wrote":      # B は『ネタ書きの伸び ×NETA_BOOST_MULT を NETA_BOOST_WEEKS 週』（GameConfig.netaBoostMult/Weeks・WeekRunner.applyNetaRevise）
        if s.stamina >= 50: _ev_add(s, "idea", 2); _ev_add(s, "expr", 1); _ev_add(s, "stamina", -15)
        else: _ev_add(s, "stamina", 5); _ev_add(s, "mental", 1); s._neta_boost = max(getattr(s, "_neta_boost", 0), NETA_BOOST_WEEKS)
    elif k == "photo":
        if s.stamina >= 50:
            _ev_add(s, "chara", 2); _ev_add(s, "fame", 1); s.money += 10_000; _ev_add(s, "stamina", -5)
            s._preocc = max(getattr(s, "_preocc", 0), 1)       # 今週の稽古は不可（アプリ preoccupiedWeeks=1）
        else: _ev_add(s, weaker(), 1)
    elif k == "justlost":
        if s.stamina >= 50: _ev_add(s, _app_weak4(s), 2); _ev_add(s, "mental", -2); _ev_add(s, "stamina", -10)
        elif s.money >= 1500: _ev_add(s, "compat", 2); _ev_add(s, "mental", 1); _ev_add(s, "stamina", 5); s.money -= 1500
        else: _ev_add(s, "stamina", 15); _ev_add(s, "mental", 2)
    elif k == "styletalk":   # A=発想+2/表現-1/相性-2 B=表現+2/相性+1/メンタル-1 → ボットは B（相性を削らない）
        _ev_add(s, "expr", 2); _ev_add(s, "compat", 1); _ev_add(s, "mental", -1)
    elif k == "passfork":
        if s.stamina >= 50: _ev_add(s, "fame", 3); _ev_add(s, "stamina", -15); _ev_add(s, "mental", -1)
        else: _ev_add(s, weaker(), 1); _ev_add(s, "compat", 1)
    elif k == "eve":
        if s.stamina >= 60: _ev_add(s, "expr", 1)
        else: _ev_add(s, "stamina", 10); _ev_add(s, "mental", 1)
    elif k == "tsuuka":
        if s.stamina >= 50: _ev_add(s, "sense", 2); _ev_add(s, "compat", -1); _ev_add(s, "stamina", -10)
        else: _ev_add(s, "expr", 2); _ev_add(s, "compat", 1)
    elif k == "early":
        if s.stamina >= 50: _ev_add(s, "compat", 2); _ev_add(s, "stamina", -15)
        else: _ev_add(s, "stamina", 10); _ev_add(s, "mental", 1)
    elif k == "tani":
        if s.stamina >= 35: s.money += 150_000; _ev_add(s, "stamina", -15)
        else: _ev_add(s, "mental", -1); _ev_add(s, "compat", 1)
    # lineuptop / greenroom / luckythird / nameless はフレーバー（効果なし）

def _app_week_event(s, year, week, stages, gp_alive):
    """GameSession.evaluateChoiceEventFire（週頭＝行動前の状態）。確定発火→無ければ rollWeeklyRandomEvent"""
    if getattr(s, "_neta_boost", 0) > 0: s._neta_boost -= 1   # GameSession.tickNetaBoost（週が明けて1減る＝自由週ごと）
    a = _app_state(s)
    nxt = stages[0] if stages else None
    ahead = (nxt[0] - week) if nxt else 99
    def done(key):
        a["counts"][key] = a["counts"].get(key, 0) + 1
    if a["jl"] and not a["lost_fired"]:
        a["lost_fired"] = True; _app_apply(s, "justlost"); a["jl"] = False; done("justlost"); return
    if a["loss"] >= 3 and not a["style_done"]:
        a["style_done"] = True; _app_apply(s, "styletalk"); done("styletalk"); return
    if a["jp"] and not a["fork_fired"] and nxt and nxt[0] - week >= 3 and s.stamina >= 15:
        a["fork_fired"] = True; _app_apply(s, "passfork"); a["jp"] = False; done("passfork"); return
    if not a["eve_fired"] and nxt and nxt[0] - week == 1 and nxt[1]:
        a["eve_fired"] = True; _app_apply(s, "eve"); done("eve"); return
    if not a["early_done"] and year == 1 and 3 <= week < 15 and s.compat <= 7:
        a["early_done"] = True; _app_apply(s, "early"); done("early"); return
    if not a["tsuuka_done"] and s.compat >= 15:
        a["tsuuka_done"] = True; _app_apply(s, "tsuuka"); done("tsuuka"); return
    if not a["nameless_fired"] and s.compat >= 8 and nxt and 2 <= nxt[0] - week <= 5:
        a["nameless_fired"] = True; done("nameless"); return
    if not a["tani_fired"] and s.money < 100_000 and s.compat >= 8 and ahead > 3:
        a["tani_fired"] = True; _app_apply(s, "tani"); done("tani"); return
    # 週次ランダム抽選
    if a["count"] >= APP_EVENT_CAP:
        return
    rng = s._app_rng
    if rng.random() >= EVENT_RATE:
        return
    cands = [k for k in APP_POOL if k not in a["fired"]
             and _app_band(k, s, week, year, ahead, nxt, a)
             and (k != "yearend" or s.money >= 1500)]       # 選べる選択肢が無いイベントは出さない
    if not cands:
        return
    k = cands[min(int(rng.random() * len(cands)), len(cands) - 1)]
    a["fired"].add(k); a["count"] += 1; done(k)
    if k in APP_UNIQUE: _app_apply(s, k)
    else: _others_apply(s, k)

# 季節催事（週固定・毎年）
SEASONAL = {1: (0, 10, 0, None, 0), 26: (0, 0, 0, "mental", 2)}

def _apply_event(s, ev):
    dm, dst, df, key, dab = ev
    s.money += dm
    if dst:
        B.add(s, "stamina", dst)
    if df:
        B.add(s, "fame", df)
    if key:
        B.add(s, key, dab)

def _track_pass(s):
    """回戦・大会を通過した瞬間の状態記録（満身創痍/どん底トロフィー用）"""
    if RUN_TRACK is None:
        return
    if s.stamina < 30:
        RUN_TRACK["sub30_pass"] = True
    if s.money < 0:
        RUN_TRACK["subzero_pass"] = True

# ============================================================
# 挑戦者側の「飽きられ」機構（dynasty_design_v0.md §3・既定OFF・golden非対象）
# exp_challenger.py がONにして初回分布への影響を測る
# ============================================================

AUDIENCE_SPLIT = False    # 客層二層化: 準決まで=コア客(センス・発想の重み×K) / 決勝=お茶の間(表現・華×K)。重みは再正規化
AUDIENCE_K     = 1.1      # 二層化の強さ【仮】（1.1で優勝率+0.8pt→係数を下げて帯内に収める。exp_challenger参照）
BOREDOM_ON     = False    # 飽きられデバフ: 同一回戦で3年連続敗退→その回戦の実効ライン+BOREDOM_PEN（通過で解除）
BOREDOM_PEN    = 3.0
UPSET_ON       = False    # 波乱の年: 毎年UPSET_Pの確率でその年のGP全ライン±UPSET_DELTA
UPSET_P        = 1.0 / 6.0
UPSET_DELTA    = 3.0
RUN_BOREDOM    = None     # {回戦idx: 連続敗退数} run_careerが管理
CHALLENGER_STATS = {"boredom_applied": 0, "upset_years": 0}

def _gp_perform(s, line, rng, final):
    """GP本番。AUDIENCE_SPLIT時のみ重み替えで再計算（OFFならB.performと完全同値）"""
    if not AUDIENCE_SPLIT:
        return B.perform(s, line, rng)
    if final:
        w = ((s.sense, B.W_SENSE), (s.idea, B.W_IDEA), (s.expr, B.W_EXPR * AUDIENCE_K), (s.chara, B.W_CHARA * AUDIENCE_K))
    else:
        w = ((s.sense, B.W_SENSE * AUDIENCE_K), (s.idea, B.W_IDEA * AUDIENCE_K), (s.expr, B.W_EXPR), (s.chara, B.W_CHARA))
    tot = sum(wt for _, wt in w)
    jitsu = sum(v * wt for v, wt in w) / tot
    b = B.blur_width(s.mental)
    roll = rng.uniform(-b, b)
    pen = 0
    for th, p in B.STAM_PEN:
        if s.stamina < th:
            pen = p
            break
    return jitsu + s.compat + roll + pen >= line, 0.0

# ============================================================
# ネタ資産層（neta_system_design_v0.md §6・既定OFF・golden非対象）
# ボットは「2本を作って磨く」最小戦略（実プレイヤーの4枠運用の下位近似）
# ============================================================

NETA_ON          = False
NETA_CREATE_COMP = 30.0    # 新ネタの初期完成度
NETA_WRITE_GAIN  = 8.0     # ネタ作り=改稿
NETA_STAGE_GAIN  = 12.0    # ネタ見せ会=劇場で試す
NETA_STAGE_FRESH = -2.0
NETA_LIVE_FRESH  = 5.0     # フリーライブ=客前で寝かせる
NETA_USE_FRESH   = -10.0   # 大会で掛ける【仮】
NETA_COEF_COMP   = 0.04    # 完成度係数【採用値】。設計初期値0.06は優勝率+1.2ptの易化→0.04で帯内（exp_neta参照）
NETA_COEF_FRESH  = 0.02
NETA_CLAMP       = 5.0
NETA_SECOND_PEN  = 3.0     # 決勝2本目の完成度60未満ペナルティ
NETA_RANDOM_PICK = False   # 計測C: ネタ選択をランダム化（プレイヤースキル寄与の測定）
# --- 2026-10-14 追加：アプリ（GameCore）と同じ式で測る（既定OFF＝従来の実測を再現できる） ---
# GameEngine.netaScoreBonus＝(polish−50)×0.04＋(buzz−50)×0.02・±5／決勝2本目 polish<60 で −3（neta_system_redesign_v2 §(a)(b)）
# buzz＝ライブ手応えの移動平均（Neta.liveBuzz＝clamp(実力×0.7＋完成度×0.5, 0,100)・α=0.4・乱数なし）
# 新ネタ polish=30・buzz=0／改稿 +8（netaReviseGain）／ネタ見せ会 +12・フリーライブ +6（netaLivePolishShow/Free）
NETA_V2            = False
NETA_SKIP_NEGATIVE = False  # 補正がマイナスのネタは掛けない（ネタなし＝0）。「粗いネタを選ぶと損」の差を測る
V2_NEW_POLISH = 30.0
V2_REVISE     = 8.0
NETA_BOOST_MULT, NETA_BOOST_WEEKS = 1.6, 2   # GameConfig.netaBoostMult / netaBoostWeeks（0016 書けた一本 B・events_parity_check_1019）
V2_LIVE_SHOW  = 12.0
V2_LIVE_FREE  = 6.0
V2_ALPHA      = 0.4
V2_POWER_W    = 0.7
V2_POLISH_W   = 0.5
V2_COEF_BUZZ  = 0.02
V2_SECOND_MIN = 60.0
# 2026-10-15 オーナー決定（キュー60）：同じネタを毎年使うと飽きられる＝前の年に大会で掛けたネタは年初に buzz −D（同じ年の中では減らない）
V2_YEAR_STALE = 0.0   # D【仮】。0＝従来どおり
V2_TIRED_PEN  = 1.0   # 案B【仮】：大会で掛けた年の数×P を補正から引く（ライブでは戻らない＝客が覚えている）。0＝無し
V2_TIRED_CAP  = 2     # 案C：飽きの段の上限（3＝最大 −3P）
V2_TIRED_REST_YEARS = 0  # 案E：この年数続けて掛けなかったら飽きが全部戻る（寝かせた再演・0＝無し）
V2_TIRED_REST = False # 案C：前の年に掛けなかったネタは飽きが1段戻る（寝かせると戻る＝再演）
V2_TIRED_NEW  = False # 案B のボット：書く時、飽きられたネタ（使った年≥1）があれば新ネタに書き替える（実プレイヤーの「新ネタを書く」の近似）
V2_WRITE_GAIN = {"ネタ作り": V2_REVISE, "喫茶店で書く": 10.0, "ファミレスで書く": 12.0}

# ============================================================
# 知名度 v62（2026-10-15 オーナー決定・キュー62・既定OFF＝golden 非対象）
# 「徐々に上がる。決勝に行けば1年目でも一気に上がる。他は甘くない。100＝優勝を重ねた大御所」
# その他の伸び（大会・回戦・オファー・イベント）＝×FAME_OTHER_MULT×(1−知名度/FAME_OTHER_CAP)²（balance_sim.add）
# 決勝進出 +FAME_FINALIST・優勝 +FAME_CHAMP は ×(1−知名度/100)（1回の優勝では100に届かない）
# ============================================================
FAME_V62        = True   # 2026-10-15 採用（キュー62 案G）。その他の伸びの逓減は balance_sim.add（FAME_OTHER_MULT/CAP）に移した
FAME_FINALIST   = 30.0
FAME_CHAMP_FLAT = True   # 優勝は逓減なしの +FAME_CHAMP（2回目の優勝で100に届く形）

def _fame_raw(s, amt):
    s.fame = B.clamp(s.fame + amt, 0, 100)

def fame_champ(s):
    """優勝の知名度（Swift WeekRunner .final と鏡像）"""
    if FAME_V62 and FAME_CHAMP_FLAT:
        _fame_raw(s, FAME_CHAMP)
    elif FAME_V62:
        _fame_big(s, FAME_CHAMP)
    else:
        B.add(s, "fame", FAME_CHAMP)

def _fame_big(s, amt):
    """決勝進出・優勝の伸び（v62 のみ・逓減は1乗）"""
    if FAME_V62 and amt > 0:
        _fame_raw(s, amt * (1 - s.fame / 100))

def _neta_new():
    if NETA_V2:
        return dict(comp=V2_NEW_POLISH, buzz=0.0, fresh=0.0, used=set())
    return dict(comp=NETA_CREATE_COMP, fresh=100.0, used=set())

def _v2_live(s, n, polish_gain):
    """Swift WeekRunner.applyNetaLive と同順：手応え（演じた時点）→buzz移動平均→完成度↑"""
    lb = max(0.0, min(100.0, B.jitsuryoku(s) * V2_POWER_W + n["comp"] * V2_POLISH_W))
    n["buzz"] = n["buzz"] * (1 - V2_ALPHA) + lb * V2_ALPHA
    n["comp"] = min(100.0, n["comp"] + polish_gain)

def _neta_bonus(n, series):
    if NETA_V2:
        bonus = (n["comp"] - 50) * NETA_COEF_COMP + (n["buzz"] - 50) * V2_COEF_BUZZ
        return max(-NETA_CLAMP, min(NETA_CLAMP, bonus)) - V2_TIRED_PEN * n.get("tired", 0)
    comp_part = (n["comp"] - 50) * NETA_COEF_COMP
    if series in n["used"]:
        comp_part *= 0.5   # 同一大会系統への再投入は完成度補正半減（審査員は覚えている）
    bonus = comp_part + (n["fresh"] - 50) * NETA_COEF_FRESH
    return max(-NETA_CLAMP, min(NETA_CLAMP, bonus))

def _neta_pick(s, series, rng):
    if not getattr(s, "netas", None):
        return None
    if NETA_RANDOM_PICK:
        return rng.choice(s.netas)
    best = max(s.netas, key=lambda n: _neta_bonus(n, series))
    if NETA_SKIP_NEGATIVE and _neta_bonus(best, series) < 0:
        return None
    return best

def _neta_use(n, series):
    if NETA_V2:
        n["used_y"] = True   # 年初の飽き（V2_YEAR_STALE）用の印だけ。大会は buzz/polish を動かさない
        return
    n["used"].add(series)
    n["fresh"] = max(0.0, n["fresh"] + NETA_USE_FRESH)

def _neta_on_train(s, arg):
    """稽古行動をネタ資産に接続（能力効果は従来どおり併存）"""
    if NETA_V2:
        if arg in V2_WRITE_GAIN:   # 家・喫茶店・ファミレスで書く（GameConfig.netaWriteTrainings／netaPlaceGain）
            tired = [x for x in s.netas if x.get("tired", 0) >= 1]
            if len(s.netas) < 2:
                s.netas.append(_neta_new())
            elif V2_TIRED_NEW and tired:
                s.netas[s.netas.index(max(tired, key=lambda x: x["tired"]))] = _neta_new()
            else:
                n = min(s.netas, key=lambda x: x["comp"])
                boost = NETA_BOOST_MULT if getattr(s, "_neta_boost", 0) > 0 else 1.0   # 0016 書けた一本 B（アプリ版イベントのみ立つ＝既定では恒等）
                n["comp"] = min(100.0, n["comp"] + V2_WRITE_GAIN[arg] * boost)
        elif arg == "ネタ見せ会" and s.netas:
            _v2_live(s, max(s.netas, key=lambda x: x["comp"]), V2_LIVE_SHOW)
        elif arg == "フリーライブ" and s.netas:
            _v2_live(s, min(s.netas, key=lambda x: x["buzz"]), V2_LIVE_FREE)
        return
    if arg == "ネタ作り":
        if len(s.netas) < 2:
            s.netas.append(_neta_new())
        else:
            n = min(s.netas, key=lambda x: x["comp"])
            n["comp"] = min(100.0, n["comp"] + NETA_WRITE_GAIN)
    elif arg == "ネタ見せ会" and s.netas:
        n = max(s.netas, key=lambda x: x["comp"])
        n["comp"] = min(100.0, n["comp"] + NETA_STAGE_GAIN)
        n["fresh"] = max(0.0, n["fresh"] + NETA_STAGE_FRESH)
    elif arg == "フリーライブ" and s.netas:
        n = min(s.netas, key=lambda x: x["fresh"])
        n["fresh"] = min(100.0, n["fresh"] + NETA_LIVE_FRESH)

def _neta_line_adj(s, series, rng, final=False):
    """大会の実効ラインへの調整量（=−ネタ補正。決勝は2本制チェック込み）。ネタ消費も行う"""
    if not NETA_ON:
        return 0.0
    n = _neta_pick(s, series, rng)
    if n is None:
        if NETA_V2:
            return 0.0   # Swift：選んでいなければ決勝でも 0（2本目の減点も付かない＝netaScoreBonus の guard）
        return NETA_SECOND_PEN if final else 0.0   # ネタ0本で決勝は2本目ペナルティ相当
    adj = -_neta_bonus(n, series)
    _neta_use(n, series)
    if final:
        others = [x for x in s.netas if x is not n]
        second = max(others, key=lambda x: x["comp"]) if others else None
        if second is None or second["comp"] < (V2_SECOND_MIN if NETA_V2 else 60):
            adj += NETA_SECOND_PEN   # 「2本目がなかった」敗因
    return adj

# ============================================================
# ボット（既存のバランス型・調整型を流用）
# キャリア用の最小補正を2点だけ加える（1年版のロジック自体は変えない）:
#  (1) 選んだ稽古の主効果が上限100に達していたら、主効果が最も低い稽古に差し替える
#      （既存ボットは金持ちになるとネタ見せ会に固定され、表現100到達後の稽古週が全て空振りになるため。
#        この補正がないと実力値が57〜66で頭打ちになり、感度実験がボットの欠陥に埋もれる）
#  (2) 調整型の「大会前週に体力を整える」対象週を新カレンダー（大会6種＋GP各回戦）に差し替える
# ============================================================

def _cap_of(key):
    return B.MENTAL_CAP if key == "mental" else B.ABILITY_CAP

def redirect_capped_training(s, choice):
    act, arg = choice
    if act != "train":
        return choice
    key = B.TRAININGS[arg]["main"][0]
    if key.startswith("cur:"):
        return choice   # 正典v3: 主効果は通貨（能力の上限で差し替える対象がない）。旧版はここで AttributeError だった
    if getattr(s, key) < _cap_of(key):
        return choice
    cands = [(getattr(s, t["main"][0]), name) for name, t in B.TRAININGS.items()
             if t["cost"] <= s.money and getattr(s, t["main"][0]) < _cap_of(t["main"][0])]
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
        if CAREER_BUDGET and init_ability > B.INIT_ABILITY:
            s._yg = float(init_ability - B.INIT_ABILITY)   # 初期ボーナスは成長予算の前借り（実力値換算・重み合計1.0）
    if compat is not None:
        s.compat = float(compat)
    if NETA_ON:
        s.netas = [_neta_new()]   # 結成時の初ネタ1本
    return s

def enter_tournament(s, pol, t, rng):
    """出場資格チェック後の大会1回ぶん。(出場したか, 優勝したか) を返す。
    エントリー費2,000円は全大会共通【正典v2・H7対策】。大阪はさらに遠征費"""
    need = GP_ENTRY_FEE
    tr = pol.transport(s) if t["osaka"] else None
    if tr is not None and getattr(s, "shinkansen_active", None):
        tr = dict(cost=0, stam=0)   # 新幹線回数券（Item.swift 鏡像）
    if tr is not None:
        need += tr["cost"]
    if s.money < need:
        return False, False
    s.money -= GP_ENTRY_FEE
    if tr is not None:
        s.money -= tr["cost"]
        B.add(s, "stamina", tr["stam"])
        if RUN_TRACK is not None and tr is B.BUS:
            RUN_TRACK["bus"] = RUN_TRACK.get("bus", 0) + 1
    line = t["line"] + _neta_line_adj(s, t["name"], rng)
    ok, _ = B.perform(s, line, rng)
    if ok:
        s.money += t["prize"]
        B.add(s, "fame", t["fame"])
        _track_pass(s)
        if RUN_BOREDOM is not None:
            RUN_BOREDOM.clear()   # 飽きられ解除(b): 他大会での優勝＝再評価（dynasty §3-2）
    return True, ok

_M64 = (1 << 64) - 1

def _splitmix_u01(state, n):
    """SplitMix64（Swift RandomSource.swift と同一）の n 番目(1始まり)の [0,1) 値。"""
    st = state & _M64
    z = 0
    for _ in range(n):
        st = (st + 0x9E3779B97F4A7C15) & _M64
        z = st
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & _M64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & _M64
        z = z ^ (z >> 31)
    return (z >> 11) * (1.0 / 9007199254740992.0)

def invite_roll(seed, year, week):
    """§102 誘いの抽選。本編の乱数とは別の決定論（シード+年週のハッシュ→SplitMix64）。(来たか, 発想が付くか)。
    Swift: GameEngine.rollInvite（同じ式・同じ定数で同値）。"""
    st = (seed + (year * 1000 + week) * 0xD1B54A32D192ED03) & _M64
    if _splitmix_u01(st, 1) >= INVITE_P:
        return None
    return _splitmix_u01(st, 2) < INVITE_IDEA_P

# --- キュー96（規律A・2026-10-18）：知名度が上がるほどオファーの札が増える（30未満=1枚／30〜55=2枚／55以上=3枚【仮】） ---
OFFER_CARD_FAMES = (30, 55)                 # OFFER_RATES の区切り 10/30/55 に合わせる【仮】
OFFER_CARD_SALT  = 0x5851F42D4C957F2D       # 誘い(§102)とは別の系列にする塩

def offer_extra_count(fame):
    return sum(1 for f in OFFER_CARD_FAMES if fame >= f)

def extra_offers(seed, year, week, fame, first_name):
    """追加の札（2枚目以降）。1枚目は本編の乱数（B.roll_offer）。ここは本編の乱数を一切消費しない別の決定論
    （シード+年週+塩のハッシュ→SplitMix64）。1枚目と違う種類を、残りから floor(u*残り数) で引く。
    Swift: GameEngine.extraOffers（同じ式・同値）。seed=None または枚数0 なら []。"""
    n = offer_extra_count(fame)
    if seed is None or n <= 0:
        return []
    st = (seed + (year * 1000 + week) * 0xD1B54A32D192ED03 + OFFER_CARD_SALT) & _M64
    rest = [o["name"] for o in B.OFFERS_NAMED if o["name"] != first_name]
    out = []
    for k in range(1, n + 1):
        i = int(_splitmix_u01(st, k) * len(rest))
        nm = rest.pop(i)
        out.append(dict(next(o for o in B.OFFERS_NAMED if o["name"] == nm)))
    return out

def invite_weekend(s, pol, year, week, seed):
    """週末の誘い（rift_weekend の後）。来たら「行く／断る」をボットが選ぶ。Swift: WeekRunner.pendingInvite→resolveInvite"""
    global INVITE_COUNT
    if seed is None or INVITE_P <= 0:
        return
    idea = invite_roll(seed, year, week)
    if idea is None:
        return
    INVITE_COUNT += 1
    ch = getattr(pol, "choose_invite", None)
    go = ch(s) if ch else INVITE_GO
    if go:
        s.money -= INVITE_MONEY
        B.add(s, "stamina", INVITE_STAMINA)
        B.add(s, "mental", INVITE_MENTAL)
        if idea:
            B.add(s, "idea", INVITE_IDEA)

def rift_weekend(s, year, compat0):
    """途中解散のすれ違いゲージ（週末・生活費の後）。乱数なし。解散なら True。Swift: GameEngine.applyRiftWeekEnd"""
    r = getattr(s, "rift", 0.0)
    joint = getattr(s, "_joint", False)   # §94 この週に二人で舞台に立ったか（run_year が立てる）
    s._joint = False
    if s.compat > compat0:
        r = max(0.0, r - RIFT_HEAL)
    elif joint and RIFT_JOINT_STILL:
        pass                              # §94 二人の週はすれ違いがたまらない（増えない・減らない）
    else:
        gain = RIFT_GAIN * (B.COMPAT_CAP - s.compat) / B.COMPAT_CAP
        if B.has_skill(s, "相方思い"):
            gain *= B.SKILL_RIFT_MULT
        r = min(100.0, r + gain)
    if r >= RIFT_WARN and not getattr(s, "rift_warned", False):
        s.rift_warned = True
        if RIFT_RESPOND:
            r = max(0.0, r - 30.0)
            B.add(s, "stamina", -10)
    if year < 2:
        r = min(r, 99.0)
    s.rift = r
    return r >= 100.0 and getattr(s, "rift_warned", False)

def run_year(pol, s, year, rng, seed_final=False, final_line=None, gp_seed=False):
    """1年48週。(優勝したか, 通過した回戦数0〜5, 決勝に立ったか) を返す。
    seed_final=True で王者シード（予選免除・決勝直行）。final_line で決勝ラインを上書き（王者編の飽きられ用）。
    gp_seed=True で1回戦免除（前年に準々決勝以上へ進出した組・実在準拠のシード制）"""
    s.stamina = 100.0          # 体力のみ年初に全回復
    B.reset_yearly_items(s)    # その年だけのアイテム効果（GameCore WeekRunner.init と同位置・未購入は恒等）
    if CAP_CURVE is not None:
        base, slope, floor = CAP_CURVE
        if CAREER_BUDGET:
            # キャリア累計予算: 結成からの成長総量に天井（初期ボーナスは前借り済み・_ygはリセットしない）
            B.YEAR_GROWTH_CAP = sum(max(floor, base - slope * (k - 1))
                                    for k in range(1, min(year, GROWTH_END_YEAR) + 1))
            if not hasattr(s, "_yg"):
                s._yg = 0.0
        else:
            B.YEAR_GROWTH_CAP = max(floor, base - slope * (year - 1))   # 年齢カーブ型上限【実験】
            s._yg = 0.0
    elif B.YEAR_GROWTH_CAP is not None:
        s._yg = 0.0            # 年間成長上限の年初リセット【実験】
    if RUN_TRACK is not None:
        RUN_TRACK["year_wins"] = []
        RUN_TRACK["year_entered"] = []
    gp_stage = 1 if gp_seed else 0   # 次に挑む GP_ROUNDS のインデックス（シード組は2回戦から）
    gp_entry_paid = False      # エントリー費はその年最初に出る回戦で徴収
    gp_alive = not seed_final  # 今年のグランプリ挑戦が続いているか（王者は予選免除）
    finalist = seed_final
    revival = False            # 準決勝敗退→敗者復活に回るか
    line_final = GP_FINAL_LINE if final_line is None else final_line
    upset = 0.0                # 波乱の年（dynasty §3）: その年のGP全ラインを揺らす
    if UPSET_ON and rng.random() < UPSET_P:
        upset = UPSET_DELTA if rng.random() < 0.5 else -UPSET_DELTA
        CHALLENGER_STATS["upset_years"] += 1

    for week in range(1, B.WEEKS + 1):
        acted = False
        compat0 = s.compat   # 途中解散：この週に相性が上がったか（乱数なし）

        # --- その他の大会（出場資格があり交通費が払えるなら出る） ---
        t = TOURNAMENTS.get(week)
        if t and t["ok"](year, s):
            acted, won_t = enter_tournament(s, pol, t, rng)
            if acted: s._joint = True
            if acted and EVENTS_APP: _app_result(s, bool(won_t))
            if RUN_TRACK is not None and acted:
                RUN_TRACK.setdefault("year_entered", []).append(t["name"])
                if won_t:
                    RUN_TRACK.setdefault("wins", set()).add(t["name"])
                    RUN_TRACK.setdefault("year_wins", []).append(t["name"])

        # --- グランプリ各回戦（東京・遠征不要・毎年1回戦からエントリー【仮】） ---
        if not acted and gp_alive and gp_stage < len(GP_ROUNDS) and week == GP_ROUNDS[gp_stage][0]:
            if not gp_entry_paid and s.money < GP_ENTRY_FEE:
                gp_alive = False                     # エントリー費が払えない＝その年は出られない（夜逃げ寸前だけが踏む）
            else:
                if not gp_entry_paid:
                    s.money -= GP_ENTRY_FEE          # エントリー費はその年最初の回戦週に1回（実在準拠2,000円）
                    gp_entry_paid = True
                _, line, _ = GP_ROUNDS[gp_stage]
                line += upset
                if BOREDOM_ON and RUN_BOREDOM is not None and RUN_BOREDOM.get(gp_stage, 0) >= 3:
                    line += BOREDOM_PEN              # 飽きられ: 同じ壁に3年連続で跳ね返された翌年から
                    CHALLENGER_STATS["boredom_applied"] += 1
                line += _neta_line_adj(s, f"GP{year}", rng)
                ok, _ = _gp_perform(s, line, rng, final=False)
                acted = True
                s._joint = True
                if EVENTS_APP: _app_result(s, bool(ok))
                if not ok:
                    B.add(s, "compat", -GP_LOSS_COMPAT[gp_stage])   # §94 予選で落ちたら相性↓
                if ok:
                    if RUN_BOREDOM is not None:
                        RUN_BOREDOM[gp_stage] = 0    # 壁を越えたら既視感リセット
                    B.add(s, "fame", GP_ROUND_FAME)
                    _track_pass(s)
                    gp_stage += 1
                    if gp_stage == len(GP_ROUNDS):
                        finalist = True
                        _fame_big(s, FAME_FINALIST)
                else:
                    if RUN_BOREDOM is not None:      # 「同一回戦で連続」のみ数える
                        for k in list(RUN_BOREDOM):
                            if k != gp_stage:
                                RUN_BOREDOM[k] = 0
                        RUN_BOREDOM[gp_stage] = RUN_BOREDOM.get(gp_stage, 0) + 1
                    if gp_stage == len(GP_ROUNDS) - 1:   # 準決勝敗退のみ敗者復活へ
                        revival = True
                    gp_alive = False                 # 落ちたら今年の挑戦終了（翌年また1回戦から）

        if week == GP_FINAL_WEEK:
            if revival:                              # 敗者復活 → 通過なら同週の決勝へ（客層はお茶の間=視聴者投票想定）
                rev_line = GP_REVIVAL_LINE + upset + _neta_line_adj(s, f"GP{year}", rng)
                ok, _ = _gp_perform(s, rev_line, rng, final=True)
                acted = True
                s._joint = True
                if EVENTS_APP: _app_result(s, bool(ok))
                REVIVAL_STATS["attempts"] += 1
                if ok:
                    REVIVAL_STATS["passes"] += 1
                    B.add(s, "fame", GP_ROUND_FAME)
                    _track_pass(s)
                    if RUN_TRACK is not None:
                        RUN_TRACK["revival_pass"] = True
                    finalist = True
                    _fame_big(s, FAME_FINALIST)
            if finalist:                             # 決勝（人気補正＝機微はここだけ効く）
                eff_line = line_final + upset - FAME_FINAL_BONUS * (s.fame - 50) / 50
                eff_line += _neta_line_adj(s, f"GP決勝{year}", rng, final=True)
                ok, _ = _gp_perform(s, eff_line, rng, final=True)
                acted = True
                s._joint = True
                if EVENTS_APP: _app_result(s, bool(ok))
                if ok:
                    s.money += GP_PRIZE
                    fame_champ(s)
                    _track_pass(s)
                    if RUN_TRACK is not None:
                        entered = RUN_TRACK.get("year_entered", [])
                        if entered and set(RUN_TRACK.get("year_wins", [])) == set(entered):
                            RUN_TRACK["grand_slam"] = True   # 六冠の年（出場全大会優勝+GP制覇）
                    return True, gp_stage, True      # 初優勝＝勇退

        # --- アプリ版 選択肢イベント（週頭＝行動前。EVENTS_APP=True の時だけ） ---
        app_free = EVENTS_APP and not acted
        if app_free:
            _app_week_event(s, year, week, _app_stages(s, year, week, gp_alive and gp_stage < len(GP_ROUNDS), gp_stage, finalist, revival), gp_alive)
        # --- 通常行動（大会がなかった週） ---
        if not acted:
            offer = B.roll_offer(s, rng)
            if EVENTS_ON and offer is not None and s.fame < 20:
                # 変な仕事テーブル（下積み期はまともなオファーの代わりに変な誘い）: 受けると小銭と話のタネ
                offer = None
                s.money += 25_000
                B.add(s, "stamina", -15)
                B.add(s, rng.choice(["idea", "chara", "expr"]), 1)
                acted = True
        if not acted and INJURY_ON and getattr(s, "_inj", 0) > 0:
            s._inj -= 1                      # 療養中: 行動選択できず休むだけ
            B.do_rest(s, "完全休養", use_ticket=False)   # アプリ A-10：選んでいない療養週は回数券を使わない
            acted = True
        if not acted:
            act, arg = pol.choose(s, week, offer, rng)
            if STAMINA_GATE is not None and act == "train" and s.stamina < STAMINA_GATE:
                act, arg = "rest", "完全休養"       # ハードゲート: 稽古ボタンが押せない（谷口が止める）
            if EVENTS_APP and act == "train" and s.__dict__.get("_preocc", 0) > 0:
                act, arg = "rest", "完全休養"       # 撮影で稽古枠が埋まった週（photoShootOffer A）
            if INJURY_ON and s.stamina < INJURY_TH and (
                    act == "train" or (act == "job" and arg == "キツい")):
                if rng.random() < (INJURY_TH - s.stamina) * INJURY_P_PER * B.throat_mult(s) * (B.SKILL_INJURY_MULT if B.has_skill(s, "体が資本") else 1.0):
                    act, arg = "rest", "完全休養"   # 体調ダウン発生: 今週から療養
                    s._inj = INJURY_REST - 1
                    B.add(s, "mental", INJURY_MENTAL)
                    if INJURY_ABILITY:
                        B.add(s, rng.choice(["sense", "idea", "expr", "chara"]), -INJURY_ABILITY)
                    if RUN_TRACK is not None:
                        RUN_TRACK["injuries"] = RUN_TRACK.get("injuries", 0) + 1
            if act == "train":
                if not B.do_training(s, arg):
                    B.do_rest(s, "完全休養")
                else:
                    if arg in RIFT_JOINT_TRAIN: s._joint = True
                    if NETA_ON:
                        _neta_on_train(s, arg)
                    if RUN_TRACK is not None:
                        RUN_TRACK["trains"] = RUN_TRACK.get("trains", 0) + 1
            elif act == "job":
                B.do_job(s, arg)
                s._jobs = getattr(s, "_jobs", 0) + 1
            elif act == "offer" and offer:
                s._wk = (year - 1) * B.WEEKS + week
                B.do_offer(s, offer)
            elif act == "rest":
                B.do_rest(s, arg)

        # 会計移設: 行動直後に稼いだ粒を recommended_plan で全量注ぐ（即時が既定・銀行は中立バッファ）。
        # 稽古以外の週は粒が無い＝空注ぎ（no-op）。人ボット・simボット・golden が同じ pour_all を使う。
        B.pour_all(s)

        if app_free:      # 自由週の行動が済んだ: 余韻フラグ失効・撮影ロック減算（アプリ choose / 週送り）
            _a = _app_state(s)
            _a["jp"] = False; _a["jl"] = False
            if s.__dict__.get("_preocc", 0) > 0: s._preocc -= 1

        if EVENTS_ON and not EVENTS_APP:
            if week in SEASONAL:
                _apply_event(s, SEASONAL[week])
            forced = False
            if EVENT_FORCE and not acted and OTHERS_ON and RUN_EVENTS_FIRED is not None:
                for fk, fw in EVENT_FORCE.items():
                    fi = len(EVENT_TABLE) + OTHERS_EVENTS.index(fk)
                    if (week == fw if isinstance(fw, int) else fw[0] <= week <= fw[1]) and fi not in RUN_EVENTS_FIRED and _others_fireable(fk, s, week, year, _honban_ahead(week)) \
                            and not (EVENT_FIRE_CAP is not None and len(RUN_EVENTS_FIRED) >= EVENT_FIRE_CAP):
                        RUN_EVENTS_FIRED.add(fi); _others_apply(s, fk); forced = True; break
            if EVENT_DRAW_FILTER and not forced and not acted and RUN_EVENTS_FIRED is not None and rng.random() < EVENT_RATE:
                if EVENT_FIRE_CAP is None or len(RUN_EVENTS_FIRED) < EVENT_FIRE_CAP:
                    cands = [i for i in range(len(EVENT_TABLE) + (len(OTHERS_EVENTS) if OTHERS_ON else 0))
                             if i not in RUN_EVENTS_FIRED and (i < len(EVENT_TABLE) or
                                 _others_fireable(OTHERS_EVENTS[i - len(EVENT_TABLE)], s, week, year, _honban_ahead(week)))]
                    if cands:
                        idx = cands[min(int(rng.random() * len(cands)), len(cands) - 1)]
                        RUN_EVENTS_FIRED.add(idx)
                        if idx >= len(EVENT_TABLE): _others_apply(s, OTHERS_EVENTS[idx - len(EVENT_TABLE)])
                        else: _apply_event(s, EVENT_TABLE[idx])
            elif not EVENT_DRAW_FILTER and not forced and not acted and rng.random() < EVENT_RATE:
                # 同一イベントは同一キャリアで原則1回（event_design_v0 §頻度設計）。全消化後は発生しない
                # EVENT_FIRE_CAP: プール何種でも効果発火は通算この回数まで（超過分はフレーバー表示のみ想定）
                idx = int(rng.random() * (len(EVENT_TABLE) + (len(OTHERS_EVENTS) if OTHERS_ON else 0)))
                if idx >= len(EVENT_TABLE):
                    k = OTHERS_EVENTS[idx - len(EVENT_TABLE)]
                    capped = EVENT_FIRE_CAP is not None and RUN_EVENTS_FIRED is not None and len(RUN_EVENTS_FIRED) >= EVENT_FIRE_CAP
                    if (RUN_EVENTS_FIRED is None or idx not in RUN_EVENTS_FIRED) and not capped \
                            and _others_fireable(k, s, week, year, _honban_ahead(week)):
                        if RUN_EVENTS_FIRED is not None:
                            RUN_EVENTS_FIRED.add(idx)
                        _others_apply(s, k)
                elif RUN_EVENTS_FIRED is not None:
                    capped = EVENT_FIRE_CAP is not None and len(RUN_EVENTS_FIRED) >= EVENT_FIRE_CAP
                    if idx not in RUN_EVENTS_FIRED and not capped:
                        RUN_EVENTS_FIRED.add(idx)
                        _apply_event(s, EVENT_TABLE[idx])
                else:
                    _apply_event(s, EVENT_TABLE[idx])

        if week % B.LIVING_INTERVAL == 0:
            s.money -= B.living_cost(s) + B.room_rent(s)
            if DEBT_LIFE_PEN is not None and s.money < 0:
                dst, dmt = DEBT_LIFE_PEN   # 生活費が払えない月の生活苦【実験・既定OFF】
                B.add(s, "stamina", dst)
                B.add(s, "mental", dmt)
            if BANKRUPT_LINE is not None and s.money < BANKRUPT_LINE:
                s._bankrupt = True         # 破産: キャリア強制終了【実験・既定OFF】
                return False, gp_stage, finalist
        if RIFT_ON and rift_weekend(s, year, compat0):
            s._dissolved = True            # 途中解散: キャリア終了（夜逃げの後に判定）
            return False, gp_stage, finalist
        invite_weekend(s, pol, year, week, RUN_INVITE_SEED)   # §102 飲みの誘い（別乱数・rift の後）
        s.min_money = min(s.min_money, s.money)

    return False, gp_stage, finalist

def run_career(pol, seed, init_ability=None, compat=None, money_log=None):
    """1キャリア。(初優勝年 or None, 最終状態, 最高到達回戦数0〜5, 決勝経験) を返す"""
    global RUN_EVENTS_FIRED, RUN_BOREDOM, RUN_INVITE_SEED
    RUN_INVITE_SEED = seed
    rng = random.Random(seed)
    s = new_state(init_ability, compat)
    if EVENTS_APP:
        _app_state(s, seed)      # アプリ版イベントの状態と独立乱数（本編 rng は動かさない）
    if EVENTS_ON:
        RUN_EVENTS_FIRED = set()
    if BOREDOM_ON:
        RUN_BOREDOM = {}
    best_stage, ever_final = 0, False
    prev_stage = 0
    for year in range(1, YEARS + 1):
        if NETA_V2 and (V2_YEAR_STALE or V2_TIRED_PEN) and getattr(s, "netas", None):
            for n in s.netas:   # 年初：前の年に大会で掛けたネタは飽きられる（乱数なし）
                if n.pop("used_y", False):
                    n["buzz"] = max(0.0, n["buzz"] - V2_YEAR_STALE)
                    n["tired"] = min(V2_TIRED_CAP, n.get("tired", 0) + 1)
                    n["rest"] = 0
                elif V2_TIRED_REST and n.get("tired", 0) > 0:
                    n["tired"] -= 1
                elif V2_TIRED_REST_YEARS and n.get("tired", 0) > 0:
                    n["rest"] = n.get("rest", 0) + 1
                    if n["rest"] >= V2_TIRED_REST_YEARS:
                        n["tired"], n["rest"] = 0, 0
        won, stage, finalist = run_year(pol, s, year, rng, gp_seed=(prev_stage >= 3))
        prev_stage = stage
        best_stage = max(best_stage, stage)
        ever_final = ever_final or finalist
        if getattr(s, "_bankrupt", False) or getattr(s, "_dissolved", False):
            break
        if money_log is not None:
            money_log[year - 1].append(s.money)
        if won:
            return year, s, best_stage, ever_final
    return None, s, best_stage, ever_final

# ============================================================
# 集計
# ============================================================

def run_config(pol_cls, n, init_ability=None, compat_fixed=None, compat_start=None, track_money=False):
    """1設定×nキャリア。compat_fixed=成長OFFで固定 / compat_start=初期値だけ変えて成長は既定のまま"""
    saved = B.COMPAT_GROWS
    if compat_fixed is not None:
        B.COMPAT_GROWS = False
    try:
        pol = pol_cls()
        money_log = [[] for _ in range(YEARS)] if track_money else None
        wins, finals, semi_in, final_in = [], [], 0, 0
        for i in range(n):
            year, s, best_stage, ever_final = run_career(
                pol, BASE_SEED + i,
                init_ability=init_ability,
                compat=compat_fixed if compat_fixed is not None else compat_start,
                money_log=money_log)
            wins.append(year)
            finals.append(s.money)
            if best_stage >= 4:   # 準々決勝を通過＝準決勝の舞台に立った
                semi_in += 1
            if ever_final:
                final_in += 1
    finally:
        B.COMPAT_GROWS = saved

    dist = [sum(1 for w in wins if w == y) for y in range(1, YEARS + 1)]
    none = sum(1 for w in wins if w is None)
    med = statistics.median((w if w is not None else YEARS + 1) for w in wins)
    return dict(name=pol.name, n=n, dist=dist, none=none, median=med,
                none_rate=100.0 * none / n,
                semi_rate=100.0 * semi_in / n,
                final_rate=100.0 * final_in / n,
                final_money=statistics.median(finals),
                money_log=money_log)

def fmt_dist(r):
    n = r["n"]
    cells = " ".join(f"{y}年:{100.0 * c / n:4.1f}%" for y, c in enumerate(r["dist"], 1))
    med = f"{r['median']:.0f}年目" if r["median"] <= YEARS else f">{YEARS}年(優勝なし)"
    return (f"  {r['name']:　<8}| {cells} | なし:{r['none_rate']:5.1f}%\n"
            f"  {'':　<8}| 初優勝中央値: {med} / 優勝なし率: {r['none_rate']:.1f}% / "
            f"準決到達: {r['semi_rate']:.1f}% / 決勝到達: {r['final_rate']:.1f}% / 最終所持金中央値: {B.yen(r['final_money'])}")

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
