"""エージェント（頭脳）。エンジンから View を受け取り合法手を返す“口”。

昼は2フェーズ:
  statement(view) … CO・占い/霊媒の申告（発言）。dict を返す。
  vote(view)      … 投票先 pid。全員の発言が出そろった View で呼ばれる。
夜:
  divine/guard/attack … 各役職の夜行動。

差し替え可能:
- RandomAgent   … 合法ランダム。ベースライン。
- HeuristicAgent … 定石ベース（占いの黒を吊る／占い師護衛／狼は騙り＆占い噛み）。
- BeliefAgent   … 村側の投票を信念エンジン（人狼確率）で選ぶ。狼側は定石のまま。
"""
from __future__ import annotations

from .roles import Role
from .game import View
from .belief import wolf_probabilities


class Agent:
    """既定は合法ランダム。各フックを override して頭脳を実装する。"""

    def statement(self, view: View) -> dict:
        return {}

    def vote(self, view: View) -> int:
        cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def divine(self, view: View) -> int:
        cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def guard(self, view: View) -> int:
        cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def attack(self, view: View) -> int:
        cand = [q for q in view.alive if q not in view.fellow_wolves and q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id


class RandomAgent(Agent):
    """完全合法ランダム。ベースライン。"""
    pass


class HeuristicAgent(Agent):
    """定石ベースの素朴に強いエージェント。"""

    # --- 公開情報の読み取り補助 ---------------------------------------------
    @staticmethod
    def _public_blacks(view: View) -> list[int]:
        blacks = set()
        for r in view.seer_reports + view.medium_reports:
            if r.wolf and r.target in view.alive:
                blacks.add(r.target)
        return sorted(blacks)

    @staticmethod
    def _claimed_seers(view: View) -> list[int]:
        return [pid for pid, rl in view.claims.items() if rl == Role.SEER and pid in view.alive]

    def _pick_vote(self, view: View, avoid: set[int]) -> int:
        """黒 → 対抗占い師 → ランダム の優先で吊り先を選ぶ（avoid は除外）。"""
        me = view.self_id
        blacks = [b for b in self._public_blacks(view) if b != me and b not in avoid]
        if blacks:
            return view.rng.choice(blacks)
        seers = [s for s in self._claimed_seers(view) if s != me and s not in avoid]
        if len(seers) >= 2:  # 占い騙りが割れている→どちらか吊る流れ
            return view.rng.choice(seers)
        cand = [q for q in view.alive if q != me and q not in avoid]
        return view.rng.choice(cand) if cand else me

    # --- 発言（CO・占霊申告）-------------------------------------------------
    def statement(self, view: View) -> dict:
        role = view.self_role
        me = view.self_id
        fellows = set(view.fellow_wolves) | {me}

        if role == Role.SEER:
            report = None
            if view.my_divinations:
                d = view.my_divinations[-1]
                report = (d.target, d.wolf)
            return {"co": Role.SEER, "seer_report": report}

        if role == Role.MEDIUM:
            if view.executions:  # 処刑が起きてからCO
                report = None
                if view.my_medium:
                    m = view.my_medium[-1]
                    report = (m.target, m.wolf)
                return {"co": Role.MEDIUM, "medium_report": report}
            return {}

        if role == Role.WEREWOLF:
            # 対抗占いがいる時 50% で占い騙り（仲間以外を黒に出しヘイトを逸らす）
            if (view.claims.get(me) != Role.SEER and self._claimed_seers(view)
                    and view.rng.random() < 0.5):
                targets = [q for q in view.alive if q not in fellows]
                if targets:
                    return {"co": Role.SEER, "seer_report": (view.rng.choice(targets), True)}
            return {}

        if role == Role.MADMAN:
            # 混乱要員: 占い騙りで村の視線を散らす
            if view.claims.get(me) != Role.SEER and view.rng.random() < 0.5:
                targets = [q for q in view.alive if q != me]
                if targets:
                    return {"co": Role.SEER, "seer_report": (view.rng.choice(targets), True)}
            return {}

        return {}  # 村人・狩人は潜伏

    # --- 投票 ----------------------------------------------------------------
    def vote(self, view: View) -> int:
        role = view.self_role
        me = view.self_id
        if role == Role.WEREWOLF:
            fellows = set(view.fellow_wolves) | {me}
            seers = [s for s in self._claimed_seers(view) if s not in fellows]
            if seers:  # 村の情報源（占い師CO者）を吊りにいく
                return view.rng.choice(seers)
            return self._pick_vote(view, avoid=fellows)
        # 村人陣営・狂人: 黒を追う（狂人も村っぽく振る舞う）
        return self._pick_vote(view, avoid=set())

    # --- 夜 ------------------------------------------------------------------
    def divine(self, view: View) -> int:
        known = {r.target for r in view.my_divinations}
        cand = [q for q in view.alive if q != view.self_id and q not in known]
        if not cand:
            cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def guard(self, view: View) -> int:
        seers = [s for s in self._claimed_seers(view) if s != view.self_id]
        if seers:  # 一番噛まれそうな占い師CO者を護衛
            return view.rng.choice(seers)
        cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def attack(self, view: View) -> int:
        fellows = set(view.fellow_wolves) | {view.self_id}
        seers = [s for s in self._claimed_seers(view) if s not in fellows]
        if seers:  # 村の情報源を最優先で噛む
            return view.rng.choice(seers)
        cand = [q for q in view.alive if q not in fellows]
        return view.rng.choice(cand) if cand else view.self_id


class BeliefAgent(HeuristicAgent):
    """村側の投票を信念エンジン（人狼確率）で強化する。狼・狂人側は定石のまま。

    設計判断（self-play実測にもとづく・数値は【仮】）:
    - 信念エンジンの価値は「占い騙りを裁く」局面に集中する。反証（対抗占い）が無い局面で
      確率を積極利用すると、弱い読みで確定村人を差し出し逆に弱くなる（対random狼で実測）。
    - よって既定は **CO割れ時のみ信念で裁く** 保守ゲート。これは定石に対し「対random狼で無劣化・
      対騙り狼で改善」の厳密に劣化しない改善（62.4% / 34.6→40.2%）。
    - なお `aggressive=True`（常に確率で投票）は騙り狼相手に大きく勝つ（58.9%）が正直狼相手に
      落ちる（35.4%）。このトレードオフの最適点を手で当てるのは不毛で、**self-play学習で
      チューニングすべき対象**（次フェーズ）。既定は安全側に置く。
    """

    BLACK_PRIOR = 0.5  # 黒指定された生存者へ上乗せする疑い

    def __init__(self, aggressive: bool = False):
        self.aggressive = aggressive

    def _belief_vote(self, view: View, cand: list[int]) -> int:
        probs = wolf_probabilities(view)
        blacks = {r.target for r in (view.seer_reports + view.medium_reports)
                  if r.wolf and r.target in view.alive}

        def score(p: int) -> float:
            s = probs.get(p, 0.0)
            if p in blacks:
                s += self.BLACK_PRIOR
            return s

        return max(cand, key=lambda p: (score(p), view.rng.random()))

    def vote(self, view: View) -> int:
        role = view.self_role
        if role in (Role.WEREWOLF, Role.MADMAN):
            return super().vote(view)  # 狼陣営は定石のまま

        me = view.self_id
        cand = [p for p in view.alive if p != me]
        if not cand:
            return me

        # 反証（対抗占い）が無い＝真偽を裁く必要がない局面では実績ある定石に任せる。
        seer_cos = self._claimed_seers(view)
        if not self.aggressive and len(seer_cos) <= 1:
            return super().vote(view)

        # CO割れ（または aggressive）: あり得る配役の数え上げで最尤の人狼を吊る。
        return self._belief_vote(view, cand)
