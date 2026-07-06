#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
golden同期チェック（CLAUDE.md 開発規律A の自動化）。
gen_golden.py（Python正典）の出力データ行が、GameCore の CareerGoldenTests.swift に
そのまま反映されているかを照合する。Python側の数式・乱数消費順を変えて golden 再生成を
忘れた「Python⇄Swift golden ドリフト」を検出する（swift test だけでは Swift が旧goldenに
一致してしまい素通りする穴を塞ぐ）。

使い方: python3 tools/check_golden_sync.py   （exit 0=一致 / 1=ドリフト / 2=実行不能）
"""

import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
SWIFT = HERE.parent / "GameCore/Tests/GameCoreTests/CareerGoldenTests.swift"


def data_rows(text):
    """`(int, int, ...` で始まる golden データ行だけを正規化して拾う"""
    rows = []
    for line in text.splitlines():
        s = line.strip().rstrip(",")
        if re.match(r"^\(\d+,\s*\d+,", s):
            rows.append(s)
    return rows


def main():
    gen = subprocess.run([sys.executable, str(HERE / "gen_golden.py")],
                         capture_output=True, text=True)
    if gen.returncode != 0:
        print("❌ gen_golden.py が失敗:\n" + gen.stderr, file=sys.stderr)
        return 2

    expected = data_rows(gen.stdout)
    if not expected:
        print("❌ 生成器からデータ行を抽出できない（出力フォーマット変更?）", file=sys.stderr)
        return 2

    if not SWIFT.exists():
        print(f"❌ {SWIFT} が無い", file=sys.stderr)
        return 2
    swift = SWIFT.read_text(encoding="utf-8")

    missing = [r for r in expected if r not in swift]
    if missing:
        print(f"❌ golden drift: Python正典 {len(missing)}/{len(expected)} 行が Swift golden に不在。")
        print("   → cd tools && python3 gen_golden.py で再生成し、")
        print("     CareerGoldenTests.swift の year1/yearEnds を貼り替えること（CLAUDE.md 規律A）。")
        for r in missing[:5]:
            print("   MISS:", r)
        return 1

    print(f"✅ golden同期OK: {len(expected)} 行すべて一致（Python正典 ⇄ Swift golden）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
