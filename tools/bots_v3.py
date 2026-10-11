# 正典v3（5通貨）に合わせた計測用ボット。旧 PSpread/PCasual/CareerBalanced は v3 では狙いが外れて帯を測れない（eval_axes_design_v0 §1-1）。
"""v3（5通貨・Leontief）経済に合わせた計測用ボット（scratch・正典ではない）。
PSpread（旧経済の「最低能力の稽古を選ぶ」）は v3 では稽古→能力が1対1でないため、ボトルネック通貨を外す。"""
import balance_sim as B
import sim_career as C

PERF = ["sense", "idea", "expr", "chara"]
# 稽古→（主通貨, 量）, （副通貨, 量）
def _issue(name):
    t = B.TRAININGS[name]
    out = {}
    for part in (t["main"], t["sub"]):
        if part and part[0].startswith("cur:"):
            out[part[0][4:]] = out.get(part[0][4:], 0) + part[1]
    return out

ISSUE = {n: _issue(n) for n in B.TRAININGS}

def bottleneck(s, ab):
    """ab を1段伸ばすのに最も足りない通貨（残高/必要比 が最小の通貨）"""
    rec = B.ABILITY_RECIPE[ab]
    return min(rec, key=lambda cw: getattr(s, B.CURRENCY_ATTR[cw[0]]) / cw[1])[0]

class PNeedV3(B.Policy):
    """ボトルネック追従型（v3版やり込み）: 目標能力（下の重み付き優先）のボトルネック通貨を最も多く出す稽古を選ぶ。
    target_fn で目標能力の選び方を差し替えられる（ビルド別の比較に使う）。"""
    name = "v3やり込み"
    BUFFER = 150_000
    MENTAL_FLOOR_GAP = 25   # メンタルが演技能力の平均よりこれ以上低いなら先にメンタル

    def __init__(self, target_fn=None, rest_before_event=75):
        self.target_fn = target_fn
        self.rest_before_event = rest_before_event

    def target(self, s):
        if self.target_fn:
            return self.target_fn(s)
        perf_avg = sum(getattr(s, a) for a in PERF) / 4
        if s.mental + self.MENTAL_FLOOR_GAP < perf_avg and s.mental < B.MENTAL_CAP:
            return "mental"
        return min(PERF, key=lambda a: getattr(s, a))

    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)
        if (week + 1) in C.EVENT_WEEKS and s.stamina < self.rest_before_event:
            return ("rest", "完全休養")
        if s.money < self.BUFFER:
            return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "完全休養")
        ab = self.target(s)
        need = bottleneck(s, ab)
        best, best_amt = None, -1
        for name, iss in ISSUE.items():
            if B.TRAININGS[name]["cost"] > 0 and s.money < 400_000:
                continue
            amt = iss.get(need, 0)
            if amt > best_amt:
                best, best_amt = name, amt
        if best_amt <= 0:
            best = "ネタ合わせ"
        return ("train", best)

    def transport(self, s):
        return B.TRAIN if s.money >= 150_000 else B.BUS

class PRotate(B.Policy):
    """ローテーション型（のんびり近似）: 無料3稽古を順番に。金が少なければバイト、体力が低ければ休む"""
    name = "ローテ"
    ROT = ["ネタ作り", "ネタ合わせ", "フリーライブ"]
    def __init__(self):
        self.i = 0
    def choose(self, s, week, offer, rng):
        if offer:
            return ("offer", None)
        if (week + 1) in C.EVENT_WEEKS and s.stamina < 60:
            return ("rest", "完全休養")
        if s.money < 150_000:
            return ("job", "標準")
        if s.stamina < 35:
            return ("rest", "完全休養")
        name = self.ROT[self.i % len(self.ROT)]
        self.i += 1
        return ("train", name)
    def transport(self, s):
        return B.TRAIN if s.money >= 150_000 else B.BUS
