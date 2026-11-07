#!/bin/bash
# 主な画面の重さを iPhone 17 のシミュレータで測り、1画面1行で出す（CPU% は1コア=100%・Debug ビルド・相対比較用）。
# 使い方: [SETTLE=秒] tools/run_perf.sh [derivedDataPath] [画面の設定…]（設定は MZ_UI の値、または KEY=VAL をカンマでつないだ物。インストールと起動だけでタップしない）
# 注意: Simulator の窓が隠れていると動く演出が低く出る（docs/perf_check_1108.md）。窓を出して測る。
set -u
cd "$(dirname "$0")/.."
SIM=E5D11233-FE99-429F-A55C-8B0FA5793568
DD=${1:-/tmp/mz_dd}; shift
[ $# -eq 0 ] && set -- glossary MZ_SMOKE=0 week event,MZ_EV=styleTalk yearend notebook shop calendar
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/ManzaiGame.app" || exit 1
for spec in "$@"; do
  envs=(); first=1
  IFS=',' read -ra parts <<< "$spec"
  for p in "${parts[@]}"; do
    if [[ "$p" == *=* ]]; then envs+=("SIMCTL_CHILD_$p"); else envs+=("SIMCTL_CHILD_MZ_UI=$p"); fi
  done
  pid=$(env "${envs[@]}" xcrun simctl launch --terminate-running-process "$SIM" com.manzaigame.mvp | awk '{print $NF}')
  sleep "${SETTLE:-8}"
  top -pid "$pid" -l 11 -s 1 -stats cpu,mem 2>/dev/null | grep -E '^[0-9.]+ +[0-9]' | tail -10 > /tmp/mz_perf.$$
  awk -v s="$spec" '{c+=$1; if($1>m)m=$1; last=$2} END{ if(NR) printf "%-28s CPU平均 %.1f 最大 %.1f メモリ %s\n", s, c/NR, m, last; else print s" 測れず" }' /tmp/mz_perf.$$
done
rm -f /tmp/mz_perf.$$
xcrun simctl terminate "$SIM" com.manzaigame.mvp 2>/dev/null
