"""LLMブレインのデモ: 1試合を進めて発言つきで実況し、Claudeに渡すプロンプト実例も表示。

キー無し（既定）: BeliefAgent の強い手＋テンプレ発言で進む（パイプライン確認用）。
本物のClaude発言: 環境変数 ANTHROPIC_API_KEY を設定し、`--api` を付けて実行。
  例)  ANTHROPIC_API_KEY=sk-... python3 -m jinro_ai.demo_llm --api

実行:  python3 -m jinro_ai.demo_llm
"""
from __future__ import annotations

import random
import sys

from .roles import Role
from .game import WerewolfGame, View
from .llm_agent import LLMAgent, build_context
from .selfplay import STANDARD_9


def main() -> None:
    use_api = "--api" in sys.argv
    seed = 42
    assign = list(STANDARD_9)
    random.Random(seed).shuffle(assign)
    agents = [LLMAgent(use_api=use_api) for _ in assign]
    game = WerewolfGame(assign, agents, seed=seed)

    mode = "本物のClaude発言 (use_api=True)" if use_api else "オフライン (BeliefAgent＋テンプレ発言)"
    print(f"=== LLMブレイン デモ / {mode} ===\n")

    result = game.run()
    for line in result.log:
        print(line)
    print("\n配役:", {p.name: p.role.value for p in game.players})

    # Claude に実際に渡す「状況プロンプト」の実例（1日目の占い師視点）を見せる
    print("\n" + "=" * 60)
    print("参考: Claude に渡す状況プロンプトの実例（占い師の視点・初日）")
    print("=" * 60)
    seer_pid = next(p.pid for p in game.players if p.role == Role.SEER)
    demo_game = WerewolfGame(assign, [LLMAgent() for _ in assign], seed=seed)
    demo_game._night(initial=True)   # 初日占いだけ進めて情報を持たせる
    demo_game.day = 1
    print(build_context(demo_game._view(seer_pid)))
    print("\n（キーを入れて --api を付けると、この状況を読んで Claude が発言・投票を返す）")


if __name__ == "__main__":
    main()
