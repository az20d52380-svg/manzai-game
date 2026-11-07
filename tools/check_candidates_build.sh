#!/bin/bash
# 候補ブランチを本体に試しに重ね、アプリとテストがビルドできるかを1行ずつ出す（どのブランチも書き換えない・一時の作業場所は最後に消す）。
# 使い方: tools/check_candidates_build.sh <作業用ディレクトリ> [候補…]（既定は名前に cand を含む claude/ のブランチ全部）
# RUN_TESTS=1 を付けるとビルドの代わりにアプリのテストまで回す（1本数分）。
set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd); WORK=$1; shift
MAIN=$(git branch --show-current)
SIM=E5D11233-FE99-429F-A55C-8B0FA5793568
WT="$WORK/cand_wt"; DD="$WORK/cand_dd"
if [ $# -gt 0 ]; then LIST=("$@"); else
  LIST=($(git for-each-ref --format='%(refname:short)' refs/heads/claude/ | grep -E 'cand'))
fi
git worktree add -q --detach "$WT" "$MAIN" || exit 1
trap 'cd "$ROOT"; git worktree remove --force "$WT"; git worktree prune' EXIT
cd "$WT"
for b in "${LIST[@]}"; do
  git reset -q --hard "$MAIN"; git clean -fdq
  if ! git merge -q --no-commit --no-ff "$b" >/dev/null 2>&1; then
    echo "$b  衝突（ビルドせず）"; git merge --abort 2>/dev/null; continue
  fi
  (cd ManzaiGame && xcodegen generate -q >/dev/null 2>&1)
  if [ "${RUN_TESTS:-0}" = 1 ]; then
    r=$(xcodebuild test -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" 2>&1 \
      | grep -E 'Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|: error:' | tail -2 | sed 's/^[[:space:]]*//;s/ in [0-9.]* ([0-9.]*) seconds//' | tr '\n' ' ' | cut -c1-200)
    echo "$b  $r"; git merge --abort 2>/dev/null; continue
  fi
  errs=$(xcodebuild build-for-testing -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame \
    -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" -quiet 2>&1 | grep -E 'error:' | sed "s#$WT/##" | sort -u)
  if [ -z "$errs" ]; then echo "$b  ビルドOK"; else echo "$b  ビルド失敗 $(echo "$errs" | wc -l | tr -d ' ')件: $(echo "$errs" | head -2 | cut -c1-140 | tr '\n' ' ')"; fi
  git merge --abort 2>/dev/null
done
