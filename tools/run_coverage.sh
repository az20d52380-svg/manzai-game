#!/bin/bash
# run_coverage.sh — GameCore とアプリのテスト網羅を測って要約だけ出す（11/09〜・書き換えなし）。
# 使い方: tools/run_coverage.sh <derivedDataPath> [アプリの下限%=90]
#   GameCore: 行の網羅率と、一度も通っていない領域（ファイル:行）。
#   アプリ: 画面（View・Design/）以外のファイルで下限未満のもの（DEBUG フックは selftest で別に回る点に注意）。
set -u
DD="${1:?derivedDataPath を渡す}"; MIN="${2:-90}"
SIM=E5D11233-FE99-429F-A55C-8B0FA5793568   # iPhone 17 だけ
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DD/coverage"; mkdir -p "$OUT"

cd "$ROOT/GameCore" || exit 1
swift test --enable-code-coverage >/dev/null 2>&1 || { echo "GameCore: swift test が赤"; exit 1; }
D=.build/arm64-apple-macosx/debug
BIN=$D/GameCorePackageTests.xctest/Contents/MacOS/GameCorePackageTests
xcrun llvm-cov export "$BIN" -instr-profile=$D/codecov/default.profdata \
  -ignore-filename-regex='Tests|\.build' -format=text > "$OUT/gamecore.json"
python3 - "$OUT/gamecore.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))['data'][0]
t = d['totals']['lines']
print(f"GameCore: 行 {t['percent']:.2f}%（未通過 {t['count'] - t['covered']} 行）")
miss = []
for f in d['files']:
    for s in f['segments']:   # [line, col, count, hasCount, isRegionEntry, isGap]
        if s[3] and s[4] and s[2] == 0 and not s[5]:
            miss.append(f"{f['filename'].split('/')[-1]}:{s[0]}")
print("  0回の領域: " + ("・".join(miss) if miss else "なし"))
EOF

cd "$ROOT" || exit 1
rm -rf "$OUT/app.xcresult"
xcodebuild test -project ManzaiGame/ManzaiGame.xcodeproj -scheme ManzaiGame \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" \
  -enableCodeCoverage YES -resultBundlePath "$OUT/app.xcresult" >/dev/null 2>&1 \
  || { echo "アプリ: テストが赤"; exit 1; }
xcrun xccov view --report --json "$OUT/app.xcresult" > "$OUT/app.json"
python3 - "$OUT/app.json" "$MIN" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1])); lim = float(sys.argv[2])
rows = []
for t in d['targets']:
    if not t['name'].startswith('ManzaiGame.app'): continue
    for f in t['files']:
        p = f['path'].split('ManzaiGame/Sources/')[-1]
        if 'View' in p or p.startswith('Design/') or '/Tests/' in f['path']: continue
        if f['executableLines'] and f['lineCoverage'] * 100 < lim:
            rows.append(f"{p} {f['lineCoverage']*100:.0f}%（{f['coveredLines']}/{f['executableLines']}）")
print(f"アプリ（画面以外・{lim:.0f}%未満）: " + ("・".join(rows) if rows else "なし"))
EOF
