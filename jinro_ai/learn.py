"""self-play 学習ループ: 村側の戦略パラメータを自己対戦で最適化する（回すほど強くなる本体）。

「やってくうちに強くなる」の実体。強さの評価関数は self-play 勝率（selfplay.py）。
村側の投票ポリシーを数個の連続パラメータ θ で表し、(1+λ)進化戦略で勝率を最大化する。
- 相手（狼陣営）は HeuristicAgent 固定（50%で占い騙りをする＝正直/騙りの混合相手）。
- CRN（共通乱数）: 同一 seed 集合で全候補を評価し、候補間の比較を低ノイズにする。
- train と held-out を分け、学習 seed への過適合でなく“本物の汎化”かを検証する。

手で当てるのが不毛だった「いつ確率を信じるか」の閾値を、勝率を目的に自動で詰める。

実行:  python3 -m jinro_ai.learn
"""
from __future__ import annotations

import random
from statistics import median

from .roles import Role, Camp, spec
from .game import WerewolfGame, View
from .agents import HeuristicAgent, BeliefAgent
from .belief import wolf_probabilities
from .selfplay import STANDARD_9

# --- 学習するパラメータ θ（範囲つき）------------------------------------------
PARAM_SPACE = {
    "black_prior": (0.0, 2.0),   # 占い/霊媒が黒指定した相手への上乗せ疑い
    "spread_tau":  (0.0, 1.2),   # 人狼確率の“広がり”がこれ以上なら確率投票を採用（低い=攻め）
    "min_conf":    (0.0, 0.8),   # 最有力の人狼確率がこれ未満なら確率を信じず定石に任せる
}
# 出発点＝現行の保守既定（実質「CO割れ時のみ確率」＝ BeliefAgent 既定と同じ挙動）
BASELINE = {"black_prior": 0.5, "spread_tau": 1.2, "min_conf": 0.0}


class TunedVillager(BeliefAgent):
    """村側の投票を θ で可変にしたエージェント（狼陣営に回ったら定石固定）。"""

    def __init__(self, theta: dict):
        super().__init__()
        self.theta = theta

    def vote(self, view: View) -> int:
        role = view.self_role
        if role in (Role.WEREWOLF, Role.MADMAN):
            return HeuristicAgent.vote(self, view)  # 狼陣営は固定（村側だけ学習）
        me = view.self_id
        cand = [p for p in view.alive if p != me]
        if not cand:
            return me
        probs = wolf_probabilities(view)
        top = max(cand, key=lambda p: probs.get(p, 0.0))
        vals = sorted(probs.get(p, 0.0) for p in cand)
        spread = vals[-1] - median(vals)
        seer_cos = self._claimed_seers(view)
        use_belief = (len(seer_cos) >= 2) or (spread >= self.theta["spread_tau"])
        if not use_belief or probs.get(top, 0.0) < self.theta["min_conf"]:
            return HeuristicAgent.vote(self, view)  # 確率を信じない局面は実績ある定石へ
        blacks = {r.target for r in (view.seer_reports + view.medium_reports)
                  if r.wolf and r.target in view.alive}

        def score(p: int) -> float:
            return probs.get(p, 0.0) + (self.theta["black_prior"] if p in blacks else 0.0)

        return max(cand, key=lambda p: (score(p), view.rng.random()))


# --- 評価（村=TunedVillager(θ) / 狼=HeuristicAgent、固定seed集合で村勝率）---------
def evaluate(theta: dict, seeds: list[int]) -> float:
    wins = 0
    for seed in seeds:
        assign = list(STANDARD_9)
        random.Random(seed).shuffle(assign)
        agents = [TunedVillager(theta) if spec(r).camp == Camp.VILLAGE else HeuristicAgent()
                  for r in assign]
        if WerewolfGame(assign, agents, seed=seed).run().winner == Camp.VILLAGE:
            wins += 1
    return wins / len(seeds)


# --- (1+λ) 進化戦略 -----------------------------------------------------------
def _clip(theta: dict) -> dict:
    return {k: min(hi, max(lo, theta[k])) for k, (lo, hi) in PARAM_SPACE.items()}


def _mutate(theta: dict, rng: random.Random, sigma: float) -> dict:
    return _clip({k: theta[k] + rng.gauss(0, sigma * (hi - lo))
                  for k, (lo, hi) in PARAM_SPACE.items()})


def _fmt(theta: dict) -> str:
    return "{" + ", ".join(f"{k}={theta[k]:.2f}" for k in PARAM_SPACE) + "}"


def optimize(train: list[int], generations: int = 12, lam: int = 6,
             sigma: float = 0.15, seed: int = 0):
    rng = random.Random(seed)
    best = _clip(dict(BASELINE))
    best_fit = evaluate(best, train)
    print(f"gen 00  train {best_fit:6.1%}  {_fmt(best)}  (baseline)")
    for g in range(1, generations + 1):
        improved = False
        for _ in range(lam):
            cand = _mutate(best, rng, sigma)
            fit = evaluate(cand, train)
            if fit > best_fit:
                best, best_fit, improved = cand, fit, True
        print(f"gen {g:02d}  train {best_fit:6.1%}  {_fmt(best)}  {'↑改善' if improved else '  据置'}")
    return best, best_fit


def main() -> None:
    train = list(range(1000, 1250))   # 学習用 250 戦
    val = list(range(9000, 9500))     # held-out 500 戦（学習に一切使わない）
    print("=== self-play 学習ループ（村側の投票θを進化戦略で最適化）===")
    print(f"相手(狼陣営)=HeuristicAgent固定 / train {len(train)}戦・held-out {len(val)}戦\n")
    best, _ = optimize(train)

    base = _clip(dict(BASELINE))
    print("\n--- 検証（held-out=学習に使っていないseed で汎化を確認）---")
    print(f"baseline θ : train {evaluate(base, train):6.1%} | held-out {evaluate(base, val):6.1%}")
    print(f"learned  θ : train {evaluate(best, train):6.1%} | held-out {evaluate(best, val):6.1%}")
    print(f"\n学習後 θ = {_fmt(best)}")
    print("held-out でも上がっていれば、seed への過適合でなく“本物の汎化”＝回して強くなった証拠。")


if __name__ == "__main__":
    main()
