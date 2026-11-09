#!/bin/bash
# 候補ブランチを本体の上に順に merge して1本にまとめ、GameCore・アプリのテストと golden/定数の同期を回す。green の時だけ origin に push（PUSH=1 の時）。
# 使い方: [PUSH=1] tools/make_bundle.sh <まとめの枝名 例 claude/c-bundle-1109-cand> [dd] <候補1> <候補2> …（候補は claude/ を除いた名前でも可）
# 衝突の解き方：project.pbxproj＝こちら＋xcodegen／ManzaiGameTests.swift＝相手が分岐点の版の末尾に足した分をこちらの版に付け足す（末尾以外も変えていたら見送り）。他のファイルの衝突はその候補を見送り（手で解く）。
# 11/09 定期で C 表・B 表・文の量のまとめを作った手順を道具にした（AUTOPILOT 209〜211）。シミュレータ iPhone 17 を使う。
set -u
NAME=${1:?まとめの枝名}; DD=${2:?derivedDataPath}; shift 2
U=E5D11233-FE99-429F-A55C-8B0FA5793568
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
MAIN=$(git rev-parse --abbrev-ref HEAD)
W=$(mktemp -d)/wt
GIT_TERMINAL_PROMPT=0 git fetch -q origin '+refs/heads/claude/*:refs/remotes/origin/claude/*'
git worktree add -q --detach "$W" "$MAIN" || exit 1
trap 'cd "$R"; git worktree remove --force "$W" 2>/dev/null' EXIT
cd "$W"
F=ManzaiGame/Tests/ManzaiGameTests.swift
skipped=""
for c in "$@"; do
  b=${c#claude/}; ref=origin/claude/$b
  git rev-parse -q --verify "$ref" >/dev/null || { echo "$b: origin に無い"; skipped="$skipped $b"; continue; }
  if git merge -q --no-edit "$ref" >/dev/null 2>&1; then echo "$b: ok"; continue; fi
  for f in $(git diff --name-only --diff-filter=U); do
    case "$f" in
      ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj) git checkout --ours "$f";;
      "$F") python3 - "$ref" <<'PY' && git add "$F"
import subprocess,sys
F="ManzaiGame/Tests/ManzaiGameTests.swift"
g=lambda *a: subprocess.run(["git",*a],capture_output=True,text=True,check=True).stdout
T=sys.argv[1]; mb=g("merge-base","HEAD",T).strip()
base=g("show",f"{mb}:{F}").rstrip("\n"); theirs=g("show",f"{T}:{F}"); ours=g("show",f"HEAD:{F}")
if not theirs.startswith(base): sys.exit(1)
tail=theirs[len(base):]
open(F,"w").write(ours.rstrip("\n")+tail if tail.strip() else ours)
PY
      ;;
    esac
  done
  (cd ManzaiGame && xcodegen generate -q >/dev/null 2>&1); git add ManzaiGame/ManzaiGame.xcodeproj/project.pbxproj 2>/dev/null
  left=$(git diff --name-only --diff-filter=U; grep -l '^<<<<<<< ' "$F" 2>/dev/null)
  if [ -n "$left" ]; then echo "$b: 見送り（手で解く所 $(echo $left | tr '\n' ' ')）"; git merge --abort; skipped="$skipped $b"
  else git commit -qm "まとめ：$b を入れる（tools/make_bundle.sh）" && echo "$b: 解いて ok"; fi
done
(cd ManzaiGame && xcodegen generate -q >/dev/null 2>&1)
g=$(cd GameCore && swift test 2>&1 | grep -E 'Executed [0-9]+ tests' | tail -1 | sed 's/^[[:space:]]*//;s/ in .*//')
a=$(xcodebuild test -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame -destination "platform=iOS Simulator,id=$U" -derivedDataPath "$DD" 2>&1 | grep -E 'Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)' | tail -2 | tr '\n' ' ')
s=$(cd tools && python3 check_golden_sync.py >/dev/null 2>&1 && echo 一致 || echo 不一致)
echo "GameCore: $g | アプリ: $a | golden/定数: $s | 見送り:${skipped:- なし}"
if echo "$g" | grep -q ' 0 failures' && echo "$a" | grep -q 'TEST SUCCEEDED' && [ "$s" = 一致 ]; then
  if [ "${PUSH:-0}" = 1 ]; then
    GIT_TERMINAL_PROMPT=0 git push -q -f origin "HEAD:refs/heads/$NAME" >/dev/null 2>&1 && echo "push $NAME $(git rev-parse --short HEAD)" || echo "push 失敗"
  else echo "green（PUSH=1 で push）"; fi
else echo "赤（push しない）"; fi
