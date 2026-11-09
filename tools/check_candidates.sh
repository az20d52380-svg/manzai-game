#!/bin/bash
# 判断待ちの候補ブランチ（名前に candidate / -cand を含む手元のブランチ）が今の本体にそのまま入るか、候補どうしが衝突するかを見る。
# 使い方: tools/check_candidates.sh [本体のブランチ]（既定は今のブランチ）。書き換えはしない（git merge-tree だけ）。
# 衝突が出たら：テストの末尾だけなら tools/merge_candidate_tests.py で解ける（AUTOPILOT §常設）。合わせ表 docs/candidate_merge_matrix_1027_v0.md。
set -u
cd "$(dirname "$0")/.."
BASE=${1:-$(git rev-parse --abbrev-ref HEAD)}
# 11/09：手元の枝は古いことがある（別の作業場所に出しっぱなし・refresh が分離 HEAD で push）＝ origin の候補を取り直し、origin に在ればそちらを見る。
# 本体に別の形で入った3本（vitalbar-numberpop・the-hana 2本）は外す（refresh_candidates.sh と同じ）。
SKIP='^claude/(q-candidate|vitalbar-numberpop-cand|the-hana-candidate|the-hana-candidate-r1027)$'
GIT_TERMINAL_PROMPT=0 git fetch -q origin '+refs/heads/claude/*:refs/remotes/origin/claude/*' 2>/dev/null
C=$(git branch --format='%(refname:short)' | grep -E 'candidate|-cand' | grep -vE "$SKIP" | while read -r b; do
  if git rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then echo "origin/$b"; else echo "$b"; fi; done)
files() { git merge-tree --write-tree --name-only "$1" "$2" 2>/dev/null | sed -n '2,/^$/p' | grep -v '^$' | sed 's#.*/##' | tr '\n' ' '; }
echo "== 本体 $BASE と"
for b in $C; do
  if git merge-tree --write-tree "$BASE" "$b" >/dev/null 2>&1; then r=ok; else r="衝突: $(files "$BASE" "$b")"; fi
  echo "$b  遅れ$(git rev-list --count "$b..$BASE")  $r"
done
echo "== 候補どうしの衝突"
for a in $C; do for b in $C; do
  [[ "$a" < "$b" ]] || continue
  git merge-tree --write-tree "$a" "$b" >/dev/null 2>&1 || echo "$a × $b: $(files "$a" "$b")"
done; done
