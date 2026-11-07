#!/bin/bash
# アプリの自己点検（MZ_SMOKE=selftest）を iPhone 17 で1回回し、[ST] 行の数と失敗行だけ出す。
# 使い方: tools/run_selftest.sh [derivedDataPath]（既定 /tmp/mz_dd）。ビルド→インストール→起動→DONE を待って終了。
# macOS には timeout が無いので、launch を背景で回して DONE を待ってから止める（10/27 の空振りの対策）。
# 注意: MZ_ALLOWSAVE=1 で回すので、iPhone 17 の試験用 sim のセーブは消える（AUTOPILOT §常設）。
set -u
cd "$(dirname "$0")/.."
SIM=E5D11233-FE99-429F-A55C-8B0FA5793568
DD=${1:-/tmp/mz_dd}
OUT=$(mktemp)
xcodebuild -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" -quiet build 2>&1 | grep error && exit 1
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/ManzaiGame.app" || exit 1
SIMCTL_CHILD_MZ_SMOKE=selftest SIMCTL_CHILD_MZ_ALLOWSAVE=1 \
  xcrun simctl launch --console --terminate-running-process "$SIM" com.manzaigame.mvp > "$OUT" 2>&1 &
P=$!
for _ in $(seq 1 60); do grep -q '\[ST\] DONE' "$OUT" && break; sleep 5; done
kill "$P" 2>/dev/null
N=$(grep -c '\[ST\]' "$OUT")
grep -q '\[ST\] DONE' "$OUT" && echo "selftest: $N 行・DONE" || echo "selftest: $N 行・DONE に届かず（5分で打ち切り）"
# 失敗の印：FAIL/NG、または ending= の行で末尾が ok でないもの
grep '\[ST\]' "$OUT" | grep -E 'FAIL|NG|✗|ending=.*[^k]$|ending=.*[^o]k$' | head
rm -f "$OUT"
