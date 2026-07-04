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

# ラインは docs/endgame_design_v0.md 採用値（能力上限120・逓減D=120前提）。
# 初回プレイ＝優勝率1%前後（「普通にやったら優勝できちゃうのが1%くらい」）・決勝到達2〜3割、
# トロフィー(D解放)・相方で優勝が現実化する設計。正典バランスは【イベント層ON】で計測:
# 準決86・決勝94+人気補正1.5(実効92.5)・復活88 → 初回優勝1.5%・決勝到達25〜35%（2026-07-04改訂）
GP_ROUNDS = [
    # (週, ライン, ラベル)      実在対応: 開催時期 / 通過組数(2025)
    (30, 30, "GP1回戦"),      # 8月中旬       / 11,521 → 1,912 (16.6%)
    (39, 45, "GP2回戦"),      # 10月中旬〜下旬 /  1,912 →   380 (19.9%)
    (41, 60, "GP3回戦"),      # 11月上旬       /    380 →   134 (35.3%)
    (43, 72, "GP準々決勝"),   # 11月中旬       /    134 →    30 (22%)
    (45, 86, "GP準決勝"),     # 12月上旬       /     31 →     9 (29%)
]
GP_REVIVAL_WEEK, GP_REVIVAL_LINE = 47, 88   # 敗者復活: 12月下旬(決勝と同週) / 約21 → 1 (5%)
GP_FINAL_WEEK,   GP_FINAL_LINE   = 47, 94   # 決勝: 第47週固定。イベント込み正典で優勝1.5%（準決86とセット・2026-07-04改訂）
GP_PRIZE = B.GPF_PRIZE                       # 手元500万（表示1,000万の半分【仮】）

FAME_FINAL_BONUS = 1.5  # 決勝のみの人気補正【確定・機微】: 実効ライン = ライン − 1.5×(知名度−50)/50。judge_design §10-F
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
EVENT_FIRE_CAP = None   # 効果つきイベントのキャリア通算発火上限（None=無制限）。会話増産時の総量予算（dialogue_batch3 §8）
DEBT_LIFE_PEN  = None   # 【実験・既定OFF】(体力Δ, メンタルΔ): 生活費支払い時に所持金<0なら課す生活苦（exp_human_fix参照）
BANKRUPT_LINE  = None   # 【実験・既定OFF】所持金がこの額を下回ったら破産＝キャリア強制終了（例 -1_000_000。rule_holes_v0）
INJURY_ON      = False  # 【実験・既定OFF】低体力での稽古・キツいバイトに体調ダウン抽選（rule_holes_v0。ゲーム内表記は「喉をやられた」「腰にきた」等——漫才師にケガという語は使わない）
INJURY_TH      = 20.0   # この体力未満で対象行動を選ぶとダウン抽選
INJURY_P_PER   = 0.02   # 不足1ptあたりのダウン確率（体力0で40%）【仮】
INJURY_REST    = 3      # ダウン後の療養週数（行動強制）【仮】
INJURY_MENTAL  = -5.0   # ダウン時のメンタル打撃【仮】
INJURY_ABILITY = 0.0    # ダウン時のランダム演技能力の低下量（重症変種の比較用）【仮】
STAMINA_GATE   = None   # 例 20.0: 体力がこの値未満だと稽古を選べない（ハードゲート方式の比較用・選択は休養に差し替え）
CAP_CURVE      = None   # (基準, 傾き, 下限): その年の年間成長上限 = max(下限, 基準−傾き×(年−1))。正典v2の年齢カーブ（human_calibration §5）
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

def _neta_new():
    return dict(comp=NETA_CREATE_COMP, fresh=100.0, used=set())

def _neta_bonus(n, series):
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
    return max(s.netas, key=lambda n: _neta_bonus(n, series))

def _neta_use(n, series):
    n["used"].add(series)
    n["fresh"] = max(0.0, n["fresh"] + NETA_USE_FRESH)

def _neta_on_train(s, arg):
    """稽古行動をネタ資産に接続（能力効果は従来どおり併存）"""
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
        return NETA_SECOND_PEN if final else 0.0   # ネタ0本で決勝は2本目ペナルティ相当
    adj = -_neta_bonus(n, series)
    _neta_use(n, series)
    if final:
        others = [x for x in s.netas if x is not n]
        second = max(others, key=lambda x: x["comp"]) if others else None
        if second is None or second["comp"] < 60:
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
    if compat is not None:
        s.compat = float(compat)
    if NETA_ON:
        s.netas = [_neta_new()]   # 結成時の初ネタ1本
    return s

def enter_tournament(s, pol, t, rng):
    """出場資格チェック後の大会1回ぶん。(出場したか, 優勝したか) を返す"""
    if t["osaka"]:
        tr = pol.transport(s)
        if s.money < tr["cost"]:
            return False, False
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

def run_year(pol, s, year, rng, seed_final=False, final_line=None):
    """1年48週。(優勝したか, 通過した回戦数0〜5, 決勝に立ったか) を返す。
    seed_final=True で王者シード（予選免除・決勝直行）。final_line で決勝ラインを上書き（王者編の飽きられ用）"""
    s.stamina = 100.0          # 体力のみ年初に全回復
    if CAP_CURVE is not None:
        base, slope, floor = CAP_CURVE
        B.YEAR_GROWTH_CAP = max(floor, base - slope * (year - 1))   # 年齢カーブ型上限【実験】
    if B.YEAR_GROWTH_CAP is not None:
        s._yg = 0.0            # 年間成長上限の年初リセット【実験】
    if RUN_TRACK is not None:
        RUN_TRACK["year_wins"] = []
        RUN_TRACK["year_entered"] = []
    gp_stage = 0               # 次に挑む GP_ROUNDS のインデックス
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

        # --- その他の大会（出場資格があり交通費が払えるなら出る） ---
        t = TOURNAMENTS.get(week)
        if t and t["ok"](year, s):
            acted, won_t = enter_tournament(s, pol, t, rng)
            if RUN_TRACK is not None and acted:
                RUN_TRACK.setdefault("year_entered", []).append(t["name"])
                if won_t:
                    RUN_TRACK.setdefault("wins", set()).add(t["name"])
                    RUN_TRACK.setdefault("year_wins", []).append(t["name"])

        # --- グランプリ各回戦（東京・遠征不要・毎年1回戦からエントリー【仮】） ---
        if not acted and gp_alive and gp_stage < len(GP_ROUNDS) and week == GP_ROUNDS[gp_stage][0]:
            _, line, _ = GP_ROUNDS[gp_stage]
            line += upset
            if BOREDOM_ON and RUN_BOREDOM is not None and RUN_BOREDOM.get(gp_stage, 0) >= 3:
                line += BOREDOM_PEN                  # 飽きられ: 同じ壁に3年連続で跳ね返された翌年から
                CHALLENGER_STATS["boredom_applied"] += 1
            line += _neta_line_adj(s, f"GP{year}", rng)
            ok, _ = _gp_perform(s, line, rng, final=False)
            acted = True
            if ok:
                if RUN_BOREDOM is not None:
                    RUN_BOREDOM[gp_stage] = 0        # 壁を越えたら既視感リセット
                B.add(s, "fame", GP_ROUND_FAME)
                _track_pass(s)
                gp_stage += 1
                if gp_stage == len(GP_ROUNDS):
                    finalist = True
            else:
                if RUN_BOREDOM is not None:          # 「同一回戦で連続」のみ数える
                    for k in list(RUN_BOREDOM):
                        if k != gp_stage:
                            RUN_BOREDOM[k] = 0
                    RUN_BOREDOM[gp_stage] = RUN_BOREDOM.get(gp_stage, 0) + 1
                if gp_stage == len(GP_ROUNDS) - 1:   # 準決勝敗退のみ敗者復活へ
                    revival = True
                gp_alive = False                     # 落ちたら今年の挑戦終了（翌年また1回戦から）

        if week == GP_FINAL_WEEK:
            if revival:                              # 敗者復活 → 通過なら同週の決勝へ（客層はお茶の間=視聴者投票想定）
                rev_line = GP_REVIVAL_LINE + upset + _neta_line_adj(s, f"GP{year}", rng)
                ok, _ = _gp_perform(s, rev_line, rng, final=True)
                acted = True
                REVIVAL_STATS["attempts"] += 1
                if ok:
                    REVIVAL_STATS["passes"] += 1
                    B.add(s, "fame", GP_ROUND_FAME)
                    _track_pass(s)
                    if RUN_TRACK is not None:
                        RUN_TRACK["revival_pass"] = True
                    finalist = True
            if finalist:                             # 決勝（人気補正＝機微はここだけ効く）
                eff_line = line_final + upset - FAME_FINAL_BONUS * (s.fame - 50) / 50
                eff_line += _neta_line_adj(s, f"GP決勝{year}", rng, final=True)
                ok, _ = _gp_perform(s, eff_line, rng, final=True)
                acted = True
                if ok:
                    s.money += GP_PRIZE
                    B.add(s, "fame", FAME_CHAMP)
                    _track_pass(s)
                    if RUN_TRACK is not None:
                        entered = RUN_TRACK.get("year_entered", [])
                        if entered and set(RUN_TRACK.get("year_wins", [])) == set(entered):
                            RUN_TRACK["grand_slam"] = True   # 六冠の年（出場全大会優勝+GP制覇）
                    return True, gp_stage, True      # 初優勝＝勇退

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
            B.do_rest(s, "完全休養")
            acted = True
        if not acted:
            act, arg = pol.choose(s, week, offer, rng)
            if STAMINA_GATE is not None and act == "train" and s.stamina < STAMINA_GATE:
                act, arg = "rest", "完全休養"       # ハードゲート: 稽古ボタンが押せない（谷口が止める）
            if INJURY_ON and s.stamina < INJURY_TH and (
                    act == "train" or (act == "job" and arg == "キツい")):
                if rng.random() < (INJURY_TH - s.stamina) * INJURY_P_PER:
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
                    if NETA_ON:
                        _neta_on_train(s, arg)
                    if RUN_TRACK is not None:
                        RUN_TRACK["trains"] = RUN_TRACK.get("trains", 0) + 1
            elif act == "job":
                B.do_job(s, arg)
            elif act == "offer" and offer:
                B.do_offer(s, offer)
            elif act == "rest":
                B.do_rest(s, arg)

        if EVENTS_ON:
            if week in SEASONAL:
                _apply_event(s, SEASONAL[week])
            if not acted and rng.random() < EVENT_RATE:
                # 同一イベントは同一キャリアで原則1回（event_design_v0 §頻度設計）。全消化後は発生しない
                # EVENT_FIRE_CAP: プール何種でも効果発火は通算この回数まで（超過分はフレーバー表示のみ想定）
                idx = int(rng.random() * len(EVENT_TABLE))
                if RUN_EVENTS_FIRED is not None:
                    capped = EVENT_FIRE_CAP is not None and len(RUN_EVENTS_FIRED) >= EVENT_FIRE_CAP
                    if idx not in RUN_EVENTS_FIRED and not capped:
                        RUN_EVENTS_FIRED.add(idx)
                        _apply_event(s, EVENT_TABLE[idx])
                else:
                    _apply_event(s, EVENT_TABLE[idx])

        if week % B.LIVING_INTERVAL == 0:
            s.money -= B.LIVING_COST
            if DEBT_LIFE_PEN is not None and s.money < 0:
                dst, dmt = DEBT_LIFE_PEN   # 生活費が払えない月の生活苦【実験・既定OFF】
                B.add(s, "stamina", dst)
                B.add(s, "mental", dmt)
            if BANKRUPT_LINE is not None and s.money < BANKRUPT_LINE:
                s._bankrupt = True         # 破産: キャリア強制終了【実験・既定OFF】
                return False, gp_stage, finalist
        s.min_money = min(s.min_money, s.money)

    return False, gp_stage, finalist

def run_career(pol, seed, init_ability=None, compat=None, money_log=None):
    """1キャリア。(初優勝年 or None, 最終状態, 最高到達回戦数0〜5, 決勝経験) を返す"""
    global RUN_EVENTS_FIRED, RUN_BOREDOM
    rng = random.Random(seed)
    s = new_state(init_ability, compat)
    if EVENTS_ON:
        RUN_EVENTS_FIRED = set()
    if BOREDOM_ON:
        RUN_BOREDOM = {}
    best_stage, ever_final = 0, False
    for year in range(1, YEARS + 1):
        won, stage, finalist = run_year(pol, s, year, rng)
        best_stage = max(best_stage, stage)
        ever_final = ever_final or finalist
        if getattr(s, "_bankrupt", False):
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
