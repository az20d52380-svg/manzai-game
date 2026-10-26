#!/usr/bin/env python3
"""候補ブランチに本体を取り込む途中で ManzaiGame/Tests/ManzaiGameTests.swift が末尾で衝突した時に解く。

使い方（候補ブランチを checkout して `git merge <本体>` が衝突で止まった状態で、リポジトリの直下で）:
    python3 tools/merge_candidate_tests.py <本体のブランチ名>
    git add ManzaiGame/Tests/ManzaiGameTests.swift && git commit --no-edit

考え方：候補の版 = 分岐点の版 + 候補が末尾に足したクラス なら、
結果 = 本体の版 + 候補が足したクラス。union マージは括弧が崩れるので使わない（10/27 定期で赤になった）。
候補が末尾以外も書き換えていたら何もせず止まる（手で解く）。
"""
import subprocess
import sys

F = "ManzaiGame/Tests/ManzaiGameTests.swift"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    main_branch = sys.argv[1]
    base = git("merge-base", "HEAD", main_branch).strip()
    base_v = git("show", f"{base}:{F}").rstrip("\n")
    cand_v = git("show", f"HEAD:{F}")
    main_v = git("show", f"{main_branch}:{F}").rstrip("\n")
    if not cand_v.startswith(base_v):
        print("候補が末尾以外も変えている＝手で解く")
        return 1
    added = cand_v[len(base_v):]
    with open(F, "w") as f:
        f.write(main_v + added)
    print(f"解いた：本体の版＋候補が足した {len(added.splitlines())} 行")
    return 0


if __name__ == "__main__":
    sys.exit(main())
