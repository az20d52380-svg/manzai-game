"""self-play で陣営別の勝率を測る。

「何回もやる上で強くする」の計測土台。片側の頭脳を固定してもう片側を差し替え、
勝率が動くこと＝エンジンが強さを測れていることを確認する。
実行:  python3 -m jinro_ai.selfplay
"""
from __future__ import annotations

import random
from collections import Counter

from .roles import Role, Camp, spec
from .game import WerewolfGame
from .agents import RandomAgent, HeuristicAgent

# MVP標準村（9人）: 占1・霊1・狩1・村3・狼2・狂1
STANDARD_9 = [
    Role.SEER, Role.MEDIUM, Role.HUNTER,
    Role.VILLAGER, Role.VILLAGER, Role.VILLAGER,
    Role.WEREWOLF, Role.WEREWOLF, Role.MADMAN,
]


def camp_factory(village_cls, wolf_cls):
    """役職を渡すと、その陣営に応じた頭脳を返すファクトリ（狂人は人狼陣営扱い）。"""
    def make(role: Role):
        return wolf_cls() if spec(role).camp == Camp.WEREWOLF else village_cls()
    return make


def run_matches(n: int, setup: list[Role], agent_factory, base_seed: int = 0) -> Counter:
    wins: Counter = Counter()
    for i in range(n):
        seed = base_seed + i
        assign = list(setup)
        random.Random(seed).shuffle(assign)  # 配役位置も seed で決定論的にシャッフル
        agents = [agent_factory(role) for role in assign]
        res = WerewolfGame(assign, agents, seed=seed).run()
        wins[res.winner] += 1
    return wins


def _report(label: str, wins: Counter, n: int) -> None:
    v, w = wins[Camp.VILLAGE], wins[Camp.WEREWOLF]
    print(f"{label:26s} | 村勝率 {v / n:5.1%} | 狼勝率 {w / n:5.1%} | N={n}")


def main() -> None:
    n = 2000
    print("=== self-play 勝率（陣営別マッチアップ）===")
    _report("村=random   狼=random",    run_matches(n, STANDARD_9, camp_factory(RandomAgent, RandomAgent)), n)
    _report("村=heuristic 狼=random",    run_matches(n, STANDARD_9, camp_factory(HeuristicAgent, RandomAgent)), n)
    _report("村=random   狼=heuristic", run_matches(n, STANDARD_9, camp_factory(RandomAgent, HeuristicAgent)), n)
    _report("村=heuristic 狼=heuristic", run_matches(n, STANDARD_9, camp_factory(HeuristicAgent, HeuristicAgent)), n)
    print("\n読み方: 狼を固定して村を random→heuristic に上げると村勝率が上がる、")
    print("        村を固定して狼を上げると狼勝率が上がる。両側で頭脳が効く＝土台OK。")


if __name__ == "__main__":
    main()
