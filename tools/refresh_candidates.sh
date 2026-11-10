#!/bin/bash
# 候補ブランチ（名前に candidate / -cand）のうち、本体から MIN 以上遅れていて衝突しない物に本体を取り込み、
# GameCore とアプリのテストが green の時だけ push する。衝突（pbxproj だけなら xcodegen で作り直す）・赤は push しない。
# 使い方: tools/refresh_candidates.sh [derivedDataPath] [MIN=50] [名前の正規表現=全部]（11/09：3つ目で対象の候補を絞れる＝本体と pbxproj だけ衝突した数本を直す時など）   作業場所は一時ディレクトリに作って消す。
# 本体に別の形で入った候補（vitalbar-numberpop＝d3c26557・the-hana 2本＝THE HANA 本実装）は対象から外す（11/09）。
# 別の作業場所に出しっぱなしの候補は origin の版を分離 HEAD で扱う（11/09）。
# 11/08 の自走で手で回した手順を道具にした（AUTOPILOT 済 11/08 昼・続き7）。1本あたり約2分。シミュレータ iPhone 17 を使う。
set -u
cd "$(dirname "$0")/.."
R=$(pwd)
DD=${1:-/tmp/mz_dd_cand}
MIN=${2:-50}
U=E5D11233-FE99-429F-A55C-8B0FA5793568
MAIN=$(git rev-parse --abbrev-ref HEAD)
TMP=$(mktemp -d)
for b in $(git branch --format='%(refname:short)' | grep -E 'candidate|-cand' | grep -vE '^claude/(q-candidate|vitalbar-numberpop-cand|the-hana-candidate|the-hana-candidate-r1027)$' | grep -E "${3:-.}"); do
  # 11/10：遅れは遠隔の枝で数える（手元にだけ取り込み済み・未 push の枝を飛ばさない＝AUTOPILOT 312）
  GIT_TERMINAL_PROMPT=0 git fetch -q origin "+refs/heads/${b}:refs/remotes/origin/${b}" 2>/dev/null
  if git rev-parse -q --verify "origin/${b}" >/dev/null; then behind=$(git rev-list --count "origin/${b}..$MAIN"); else behind=$(git rev-list --count "$b..$MAIN"); fi
  [ "$behind" -ge "$MIN" ] || continue
  # 11/09 夜：手元の候補の枝が遠隔より古いと、古い版で取り込んで偽の衝突になる（first-pass-share）＝先に遠隔を取り、手元が祖先なら進める
  if GIT_TERMINAL_PROMPT=0 git fetch -q origin "+refs/heads/${b}:refs/remotes/origin/${b}" 2>/dev/null \
     && [ "$(git rev-parse "$b")" != "$(git rev-parse "origin/${b}")" ] \
     && git merge-base --is-ancestor "$b" "origin/${b}"; then
    git branch -f "$b" "origin/${b}" 2>/dev/null
  fi
  W=$TMP/${b//\//_}
  if ! git worktree add -q "$W" "$b" 2>/dev/null; then
    # 11/09：古いエージェントの作業場所に候補が出しっぱなしだと add できない＝origin の版を分離 HEAD で取り込み、HEAD:$b で push（その作業場所には触らない）
    # remote.origin.fetch は本体ブランチだけ＝origin/$b は古いことがある（11/09 に invite-variants で非 fast-forward）。必ずその枝を取り直す
    GIT_TERMINAL_PROMPT=0 git fetch -q origin "+refs/heads/$b:refs/remotes/origin/$b" 2>/dev/null || { echo "$b: 見送り（別の作業場所が使用中・origin なし）"; continue; }
    behind=$(git rev-list --count "origin/$b..$MAIN")
    [ "$behind" -ge "$MIN" ] || continue
    git worktree add -q --detach "$W" "origin/$b" 2>/dev/null || { echo "$b: 見送り（作業場所を作れない）"; continue; }
  fi
  cd "$W"
  if ! git merge -q --no-edit "$MAIN" >/dev/null 2>&1; then
    UF=$(git diff --name-only --diff-filter=U)
    if [ "$UF" = "ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj" ]; then
      git checkout --theirs ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj
    elif [ -n "$UF" ] && ! grep -l '^<<<<<<<' $UF >/dev/null 2>&1; then
      # 11/09 夜：rerere（記録した解き方）で印なしに解けている＝確定して続ける（テストが green の時だけ push されるのは同じ）
      git add $UF && git commit -q --no-edit
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
    if GIT_TERMINAL_PROMPT=0 git push -q origin "HEAD:$b" >/dev/null 2>&1; then
      echo "$b: 遅れ$behind → green で push $(git log -1 --format=%h)"
    else
      echo "$b: green だが push 失敗（非 fast-forward 等・手で確かめる）$(git log -1 --format=%h)"
    fi
  else
    echo "$b: 赤（push せず）| $g | $a"
  fi
  cd "$R"; git worktree remove --force "$W"
done
rmdir "$TMP" 2>/dev/null
echo "== 終わり"
