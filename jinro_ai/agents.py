"""エージェント（頭脳）。エンジンから View を受け取り合法手を返す“口”。

差し替え可能にしてあるのが肝:
- RandomAgent   … 合法ランダム。強さ測定のベースライン（弱い村の基準線）。
- HeuristicAgent … 定石ベース。占い師の黒を吊る／狩人は占い師護衛／人狼は騙り＆
                    占い先を襲撃…など“最低限の強さ”。self-play で村勝率が
                    ランダムより明確に上がることを確認するための土台。

将来: ここに ①確率エンジン参照の強ポリシー か ②Claude ブレイン を足す。
インターフェイス（day/divine/guard/attack）は変えない。
"""
from __future__ import annotations

from .roles import Role
from .game import View


class Agent:
    """既定は合法ランダム。各フックを override して頭脳を実装する。"""

    def day(self, view: View) -> dict:
        cand = [q for q in view.alive if q != view.self_id]
        vote = view.rng.choice(cand) if cand else view.self_id
        return {"vote": vote}

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
        """公開占い/霊媒で『黒』と申告され、まだ生存している者。"""
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

    # --- 昼 ------------------------------------------------------------------
    def day(self, view: View) -> dict:
        role = view.self_role
        me = view.self_id

        if role == Role.SEER:
            # 占い師: CO して最新の真結果を申告、黒がいれば吊る
            report = None
            if view.my_divinations:
                d = view.my_divinations[-1]
                report = (d.target, d.wolf)
            return {"co": Role.SEER, "seer_report": report, "vote": self._pick_vote(view, avoid=set())}

        if role == Role.MEDIUM:
            report = None
            co = None
            if view.executions:                       # 処刑が起きてからCO
                co = Role.MEDIUM
                if view.my_medium:
                    m = view.my_medium[-1]
                    report = (m.target, m.wolf)
            return {"co": co, "medium_report": report, "vote": self._pick_vote(view, avoid=set())}

        if role == Role.WEREWOLF:
            fellows = set(view.fellow_wolves) | {me}
            # 対抗占い師がいなければ 40% で占い騙り（仲間を白、対抗/村を黒）
            act: dict = {}
            if self._claimed_seers(view) and view.rng.random() < 0.5 and view.claims.get(me) != Role.SEER:
                # 既に本物っぽい占い師がいる→黒を打って対抗、ヘイトを逸らす
                targets = [q for q in view.alive if q not in fellows]
                if targets:
                    act = {"co": Role.SEER, "seer_report": (view.rng.choice(targets), True)}
            elif view.claims.get(me) == Role.SEER:
                targets = [q for q in view.alive if q not in fellows]
                if targets:
                    act = {"co": Role.SEER, "seer_report": (view.rng.choice(targets), True)}
            # 投票: 本物の占い師（＝自分たちを黒に出しうる者）や黒指定された仲間を避け、村を吊る
            seers = [s for s in self._claimed_seers(view) if s not in fellows]
            if seers:
                act["vote"] = view.rng.choice(seers)
            else:
                act["vote"] = self._pick_vote(view, avoid=fellows)
            return act

        if role == Role.MADMAN:
            # 狂人: 混乱要員。対抗占いに乗って偽COし、村の視線を散らす
            act = {}
            if view.rng.random() < 0.5 and view.claims.get(me) != Role.SEER:
                targets = [q for q in view.alive if q != me]
                if targets:
                    act = {"co": Role.SEER, "seer_report": (view.rng.choice(targets), True)}
            act["vote"] = self._pick_vote(view, avoid=set())
            return act

        # 村人・狩人: 潜伏して占い師の指示に乗る
        return {"vote": self._pick_vote(view, avoid=set())}

    # --- 夜 ------------------------------------------------------------------
    def divine(self, view: View) -> int:
        # まだ占っていない生存者を優先（白確定を増やす）。既知は除外。
        known = {r.target for r in view.my_divinations}
        cand = [q for q in view.alive if q != view.self_id and q not in known]
        if not cand:
            cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def guard(self, view: View) -> int:
        # 狩人: 一番襲われそうな“占い師CO者”を護衛
        seers = self._claimed_seers(view)
        seers = [s for s in seers if s != view.self_id]
        if seers:
            return view.rng.choice(seers)
        cand = [q for q in view.alive if q != view.self_id]
        return view.rng.choice(cand) if cand else view.self_id

    def attack(self, view: View) -> int:
        # 人狼: 占い師CO者（村の情報源）を最優先で噛む
        fellows = set(view.fellow_wolves) | {view.self_id}
        seers = [s for s in self._claimed_seers(view) if s not in fellows]
        if seers:
            return view.rng.choice(seers)
        cand = [q for q in view.alive if q not in fellows]
        return view.rng.choice(cand) if cand else view.self_id
