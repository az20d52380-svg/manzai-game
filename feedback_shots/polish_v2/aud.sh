#!/bin/zsh
# usage: aud.sh g1 05
awk -v h="## $2_" 'index($0,h)==1{f=1;print;next} /^## /{f=0} f' ~/manzai-game/docs/design_audit_argon_$1_r2_v0.md | grep -vE '^\s*$' | cut -c1-600
