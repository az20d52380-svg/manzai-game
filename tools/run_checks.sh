#!/bin/bash
# 定期の点検を1本で：GameCore swift test・golden/定数の同期・アプリのテスト（iPhone 17）。要約の行だけ出す。
# 使い方: tools/run_checks.sh [derivedDataPath]（既定 /tmp/mz_dd）。どれかが赤なら終了コード1。
set -u
cd "$(dirname "$0")/.."
SIM=E5D11233-FE99-429F-A55C-8B0FA5793568
DD=${1:-/tmp/mz_dd}
rc=0
g=$(cd GameCore && swift test 2>&1 | grep -E 'Executed [0-9]+ tests' | tail -1 | sed 's/^[[:space:]]*//;s/ in [0-9.]* ([0-9.]*) seconds//')
echo "GameCore: ${g:-（結果の行なし＝ビルド失敗）}"
echo "$g" | grep -q ' 0 failures' || rc=1
s=$(cd tools && python3 check_golden_sync.py 2>&1); src=$?
echo "同期: $(echo "$s" | grep -cE '✅') 項目 OK・$(echo "$s" | tail -1)"
[ $src -ne 0 ] && { echo "$s" | grep -vE '✅' | head -5; rc=1; }
a=$(xcodebuild test -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" 2>&1 \
  | grep -E 'Executed [0-9]+ tests|error:|TEST (SUCCEEDED|FAILED)' | tail -2 | sed 's/^[[:space:]]*//;s/ in [0-9.]* ([0-9.]*) seconds//' | tr '\n' ' ')
echo "アプリ: $a"
echo "$a" | grep -q 'TEST SUCCEEDED' || rc=1
exit $rc
