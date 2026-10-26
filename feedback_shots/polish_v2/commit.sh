#!/bin/zsh
# usage: commit.sh "msg" file...
cd ~/mz-preview-all
m="$1"; shift
git add "$@"
git commit -q -m "$m

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
GIT_TERMINAL_PROMPT=0 git push -q origin preview-all 2>&1 | tail -2
git log --oneline | head -1 | cut -c1-60
