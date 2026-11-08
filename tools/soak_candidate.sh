#!/bin/bash
# 候補ブランチに漏れ点検（soak）をかける：origin の候補を分離 HEAD の一時作業場所でビルド→ iPhone 17 に入れて MZ_SMOKE=soak で回す→毎分の常駐メモリとクラッシュログの増減を出す。
# 使い方: tools/soak_candidate.sh <候補の枝名 例 claude/late-events-cand> [derivedDataPath] [分=10] [1手の待ちms=10]
# 11/09 定期で late-events に手で回した手順を道具にした（AUTOPILOT 204）。シミュレータ iPhone 17 だけを使う（同時に1本だけ）。書き込みはしない（push なし）。
set -u
B=${1:?候補の枝名}; DD=${2:-/tmp/mz_dd_soak}; MIN=${3:-10}; MS=${4:-10}
U=E5D11233-FE99-429F-A55C-8B0FA5793568
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
W=$(mktemp -d)/wt
GIT_TERMINAL_PROMPT=0 git fetch -q origin "+refs/heads/$B:refs/remotes/origin/$B" || { echo "$B: origin に無い"; exit 1; }
git worktree add -q --detach "$W" "origin/$B" || exit 1
trap 'cd "$R"; git worktree remove --force "$W" 2>/dev/null' EXIT
cd "$W" && (cd ManzaiGame && xcodegen generate -q >/dev/null 2>&1)
err=$(xcodebuild -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame -destination "platform=iOS Simulator,id=$U" -derivedDataPath "$DD" -quiet build 2>&1 | grep error: | head -3)
[ -n "$err" ] && { echo "$B: ビルド失敗"; echo "$err"; exit 1; }
APP="$DD/Build/Products/Debug-iphonesimulator/ManzaiGame.app"; BID=$(defaults read "$APP/Info.plist" CFBundleIdentifier)
before=$(ls ~/Library/Logs/DiagnosticReports/ManzaiGame-*.ips 2>/dev/null | wc -l | tr -d ' ')
xcrun simctl install $U "$APP"; xcrun simctl terminate $U $BID 2>/dev/null
SIMCTL_CHILD_MZ_SMOKE=soak SIMCTL_CHILD_MZ_SOAK_MS=$MS xcrun simctl launch $U $BID >/dev/null
line=""
for m in $(seq 1 $MIN); do
  sleep 60; pid=$(pgrep -f 'ManzaiGame.app/ManzaiGame' | head -1)
  [ -z "$pid" ] && { line="$line ${m}分:落ちた"; break; }
  line="$line ${m}分:$(( $(ps -o rss= -p $pid) / 1024 ))MB"
done
after=$(ls ~/Library/Logs/DiagnosticReports/ManzaiGame-*.ips 2>/dev/null | wc -l | tr -d ' ')
xcrun simctl terminate $U $BID 2>/dev/null
echo "$B $(git rev-parse --short HEAD):$line | クラッシュログ $before→$after"
