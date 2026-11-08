#!/bin/bash
# 候補ブランチ（名前に candidate / -cand）のうち、本体から MIN 以上遅れていて衝突しない物に本体を取り込み、
# GameCore とアプリのテストが green の時だけ push する。衝突（pbxproj だけなら xcodegen で作り直す）・赤は push しない。
# 使い方: tools/refresh_candidates.sh [derivedDataPath] [MIN=50]   作業場所は一時ディレクトリに作って消す。
# 11/08 の自走で手で回した手順を道具にした（AUTOPILOT 済 11/08 昼・続き7）。1本あたり約2分。シミュレータ iPhone 17 を使う。
set -u
cd "$(dirname "$0")/.."
R=$(pwd)
DD=${1:-/tmp/mz_dd_cand}
MIN=${2:-50}
U=E5D11233-FE99-429F-A55C-8B0FA5793568
MAIN=$(git rev-parse --abbrev-ref HEAD)
TMP=$(mktemp -d)
for b in $(git branch --format='%(refname:short)' | grep -E 'candidate|-cand' | grep -v '^claude/q-candidate$'); do
  behind=$(git rev-list --count "$b..$MAIN")
  [ "$behind" -ge "$MIN" ] || continue
  W=$TMP/${b//\//_}
  if ! git worktree add -q "$W" "$b" 2>/dev/null; then echo "$b: 見送り（別の作業場所が使用中）"; continue; fi
  cd "$W"
  if ! git merge -q --no-edit "$MAIN" >/dev/null 2>&1; then
    if [ "$(git diff --name-only --diff-filter=U)" = "ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj" ]; then
      git checkout --theirs ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj
    else
      echo "$b: 衝突（push せず）$(git diff --name-only --diff-filter=U | sed 's#.*/##' | tr '\n' ' ')"
      git merge --abort; cd "$R"; git worktree remove --force "$W"; continue
    fi
  fi
  (cd ManzaiGame && xcodegen generate -q >/dev/null 2>&1); git add ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj
  g=$(cd GameCore && swift test 2>&1 | grep -E 'Executed [0-9]+ tests' | tail -1 | sed 's/^[[:space:]]*//;s/ in .*//')
  a=$(xcodebuild test -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame -destination "platform=iOS Simulator,id=$U" \
      -derivedDataPath "$DD" 2>&1 | grep -E 'Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)' | tail -2 | tr '\n' ' ')
  if echo "$g" | grep -q ' 0 failures' && echo "$a" | grep -q 'TEST SUCCEEDED'; then
    git rev-parse -q --verify MERGE_HEAD >/dev/null && git commit -qm "本体を取り込む（tools/refresh_candidates.sh・GameCore とアプリのテスト green）

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
    GIT_TERMINAL_PROMPT=0 git push -q origin "HEAD:$b" 2>&1 | tail -1
    echo "$b: 遅れ$behind → green で push $(git log -1 --format=%h)"
  else
    echo "$b: 赤（push せず）| $g | $a"
  fi
  cd "$R"; git worktree remove --force "$W"
done
rmdir "$TMP" 2>/dev/null
echo "== 終わり"
