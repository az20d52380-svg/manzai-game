"""人狼ゲーム進行エンジン（決定論・SwiftUI非依存の純ロジック相当）。

方針:
- 乱数は seed 固定の random.Random を注入（このリポジトリの絶対ルール2に準拠）。
- UI や自然言語生成には一切依存しない。エージェント(頭脳)は差し替え可能な口だけ持つ。
- 昼＝各エージェントが {CO, 占い/霊媒の申告, 投票} を出す抽象議論。自然言語の「発言」は
  後段（Claude ブレイン等）で生成する層に委ねる。ここは合法手と情報の流れだけを司る。

進行順（初日占いあり = 人狼ジャッジメント標準寄り）:
  夜0: 占い師のみ占う（初日占い、結果は昼1で使える）
  → 昼d: 議論→投票→処刑→(霊媒が処刑者を知る)
  → 勝敗判定
  → 夜d: 占い師占う・狩人護衛・人狼襲撃→死亡確定
  → 勝敗判定  … を決着まで繰り返す
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Optional

from .roles import Camp, Role, NightAction, spec


@dataclass
class Player:
    pid: int
    name: str
    role: Role
    alive: bool = True


@dataclass
class Report:
    """占い師/霊媒師（を騙る者含む）の公開申告。"""
    day: int
    reporter: int
    target: int
    wolf: bool  # True=「人狼(黒)」と申告, False=「人間(白)」と申告


@dataclass
class View:
    """あるプレイヤーが“合法に知ってよい情報”だけを詰めた観測。

    エージェントはこの View だけを見て意思決定する（役職の直接漏洩は無し）。
    """
    day: int
    self_id: int
    self_role: Role
    self_camp: Camp
    alive: list[int]
    players: list[tuple[int, str, bool]]      # (pid, name, alive) 役職は含めない
    claims: dict[int, Role]                    # 誰が何をCOしているか（最新）
    seer_reports: list[Report]
    medium_reports: list[Report]
    executions: list[int]                      # 処刑された pid（順）
    night_deaths: list[int]                    # 襲撃死した pid（順）
    my_divinations: list[Report]               # 本物の占い師だけ: 自分の占い結果（真）
    my_medium: list[Report]                    # 本物の霊媒師だけ: 自分の霊媒結果（真）
    fellow_wolves: list[int]                    # 人狼だけ: 生存中の仲間
    rng: random.Random


@dataclass
class GameResult:
    winner: Camp
    days: int
    survivors: list[int]
    log: list[str]


class WerewolfGame:
    def __init__(
        self,
        roles: list[Role],
        agents: list,
        seed: int = 0,
        names: Optional[list[str]] = None,
    ):
        assert len(roles) == len(agents), "roles と agents は同数"
        self.rng = random.Random(seed)
        self.players: list[Player] = [
            Player(i, (names[i] if names else f"P{i}"), roles[i]) for i in range(len(roles))
        ]
        self.agents = agents
        self.day = 0
        self.log: list[str] = []

        # 公開状態
        self.claims: dict[int, Role] = {}
        self.seer_reports: list[Report] = []
        self.medium_reports: list[Report] = []
        self.executions: list[int] = []
        self.night_deaths: list[int] = []

        # 私的状態（役職本人のみ参照）
        self.divinations: dict[int, list[Report]] = {}   # 本物の占い師 pid -> 真の占い結果
        self.medium_known: dict[int, list[Report]] = {}  # 本物の霊媒師 pid -> 真の霊媒結果

        self.wolves = [p.pid for p in self.players if spec(p.role).is_werewolf]

    # ---- 生存・勝敗 ---------------------------------------------------------
    def alive_pids(self) -> list[int]:
        return [p.pid for p in self.players if p.alive]

    def _wolf_alive(self) -> int:
        return sum(1 for p in self.players if p.alive and spec(p.role).is_werewolf)

    def _nonwolf_alive(self) -> int:
        return len(self.alive_pids()) - self._wolf_alive()

    def _check_win(self) -> Optional[Camp]:
        w = self._wolf_alive()
        if w == 0:
            return Camp.VILLAGE
        if w >= self._nonwolf_alive():
            return Camp.WEREWOLF
        return None

    # ---- View 構築 ----------------------------------------------------------
    def _view(self, pid: int) -> View:
        p = self.players[pid]
        sp = spec(p.role)
        return View(
            day=self.day,
            self_id=pid,
            self_role=p.role,
            self_camp=sp.camp,
            alive=self.alive_pids(),
            players=[(q.pid, q.name, q.alive) for q in self.players],
            claims=dict(self.claims),
            seer_reports=list(self.seer_reports),
            medium_reports=list(self.medium_reports),
            executions=list(self.executions),
            night_deaths=list(self.night_deaths),
            my_divinations=list(self.divinations.get(pid, [])) if p.role == Role.SEER else [],
            my_medium=list(self.medium_known.get(pid, [])) if p.role == Role.MEDIUM else [],
            fellow_wolves=[w for w in self.wolves if w != pid and self.players[w].alive] if sp.is_werewolf else [],
            rng=self.rng,
        )

    # ---- 夜 -----------------------------------------------------------------
    def _night(self, initial: bool = False) -> None:
        alive = set(self.alive_pids())

        # 占い師（本物）が占う。結果は private に蓄積し、翌昼のCOで使える。
        for p in self.players:
            if p.alive and p.role == Role.SEER:
                tgt = self.agents[p.pid].divine(self._view(p.pid))
                if tgt is None or tgt == p.pid or tgt not in alive:
                    cand = [q for q in alive if q != p.pid]
                    tgt = self.rng.choice(cand) if cand else p.pid
                r = Report(self.day, p.pid, tgt, spec(self.players[tgt].role).divined_as_wolf)
                self.divinations.setdefault(p.pid, []).append(r)
                self.log.append(f"[夜{self.day}] 占い師({p.name})→{self.players[tgt].name}: "
                                f"{'人狼' if r.wolf else '人間'}")

        if initial:
            return  # 初日占いのみ。護衛・襲撃は無し。

        # 狩人（本物）が護衛
        guarded: set[int] = set()
        for p in self.players:
            if p.alive and p.role == Role.HUNTER:
                tgt = self.agents[p.pid].guard(self._view(p.pid))
                if tgt is not None and tgt in alive and tgt != p.pid:
                    guarded.add(tgt)

        # 人狼が襲撃（各狼の投票を集計→最多、同数は乱数）
        wolves_alive = [w for w in self.wolves if self.players[w].alive]
        if wolves_alive:
            tally: dict[int, int] = {}
            for w in wolves_alive:
                tgt = self.agents[w].attack(self._view(w))
                valid = [q for q in alive if not spec(self.players[q].role).is_werewolf]
                if tgt is None or tgt not in valid:
                    tgt = self.rng.choice(valid) if valid else None
                if tgt is not None:
                    tally[tgt] = tally.get(tgt, 0) + 1
            if tally:
                victim = self._argmax_with_tiebreak(tally)
                if victim in guarded:
                    self.log.append(f"[夜{self.day}] 襲撃は護衛で防がれた")
                else:
                    self.players[victim].alive = False
                    self.night_deaths.append(victim)
                    self.log.append(f"[夜{self.day}] {self.players[victim].name} が無残な姿で発見された")

    # ---- 昼 -----------------------------------------------------------------
    def _day(self) -> None:
        alive = self.alive_pids()

        # 議論フェーズ: 各生存者が {CO, 申告, 投票} を提出
        actions: dict[int, dict] = {}
        for pid in alive:
            a = self.agents[pid].day(self._view(pid)) or {}
            actions[pid] = a
            co = a.get("co")
            if co is not None:
                self.claims[pid] = co
            sr = a.get("seer_report")
            if sr is not None:
                self.seer_reports.append(Report(self.day, pid, sr[0], sr[1]))
            mr = a.get("medium_report")
            if mr is not None:
                self.medium_reports.append(Report(self.day, pid, mr[0], mr[1]))

        # 投票→処刑
        tally: dict[int, int] = {}
        for pid in alive:
            v = actions[pid].get("vote")
            if v is None or v == pid or v not in alive:
                cand = [q for q in alive if q != pid]
                v = self.rng.choice(cand) if cand else pid
            tally[v] = tally.get(v, 0) + 1
        executed = self._argmax_with_tiebreak(tally)
        self.players[executed].alive = False
        self.executions.append(executed)
        self.log.append(f"[昼{self.day}] {self.players[executed].name} が処刑された "
                        f"（得票 {tally.get(executed, 0)}）")

        # 霊媒師（本物・生存）が処刑者の陣営を知る
        for p in self.players:
            if p.alive and p.role == Role.MEDIUM:
                r = Report(self.day, p.pid, executed, spec(self.players[executed].role).medium_as_wolf)
                self.medium_known.setdefault(p.pid, []).append(r)

    # ---- 補助 ---------------------------------------------------------------
    def _argmax_with_tiebreak(self, tally: dict[int, int]) -> int:
        top = max(tally.values())
        winners = sorted(k for k, v in tally.items() if v == top)
        return winners[0] if len(winners) == 1 else self.rng.choice(winners)

    # ---- 実行 ---------------------------------------------------------------
    def run(self, max_days: int = 40) -> GameResult:
        self._night(initial=True)
        while True:
            self.day += 1
            self._day()
            if (w := self._check_win()) is not None:
                return self._finish(w)
            self._night(initial=False)
            if (w := self._check_win()) is not None:
                return self._finish(w)
            if self.day >= max_days:  # 安全弁（通常は毎昼1人減るので到達しない）
                return self._finish(Camp.VILLAGE if self._wolf_alive() == 0 else Camp.WEREWOLF)

    def _finish(self, winner: Camp) -> GameResult:
        self.log.append(f"=== {winner.value} の勝利（{self.day}日目） ===")
        return GameResult(winner, self.day, self.alive_pids(), self.log)
