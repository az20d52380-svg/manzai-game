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


GOLDEN12 = HERE.parent / "GameCore/Tests/GameCoreTests/GoldenTests.swift"


def _norm(s):
    return re.sub(r"\s+", "", s)


def check_12week():
    """gen_golden12.py の出力と GoldenTests.swift の script 表を突き合わせる（空白は無視）。
    0=一致 / 1=ずれ / 2=実行不能"""
    gen = subprocess.run([sys.executable, str(HERE / "gen_golden12.py")],
                         capture_output=True, text=True)
    if gen.returncode != 0:
        print("❌ gen_golden12.py が失敗:\n" + gen.stderr, file=sys.stderr)
        return 2
    if not GOLDEN12.exists():
        print(f"❌ {GOLDEN12} が無い", file=sys.stderr)
        return 2
    swift = [_norm(l.strip()) for l in GOLDEN12.read_text(encoding="utf-8").splitlines()
             if l.strip().startswith("(.")]
    exp = [l.strip() for l in gen.stdout.splitlines() if l.strip()]
    bad = 0
    for i, e in enumerate(exp, 1):
        if _norm(e) not in swift:
            bad += 1
            print(f"❌ 12週台本 ずれ: 第{i}週 Python={e}")
    if bad:
        print("   → python3 gen_golden12.py の出力で GoldenTests.swift の script を貼り替えること")
        return 1
    print(f"✅ 12週台本 OK（{len(exp)}週一致）")
    return 0


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
    rc = check_12week()
    return rc or check_features()


def check_features():
    """gen_golden_features.py を一時ファイルへ書かせ、golden_features.json と中身を突き合わせる（再生成忘れを拾う・10/19）。
    0=一致 / 1=ずれ / 2=実行不能"""
    import json, os, tempfile
    committed = HERE.parent / "GameCore/Tests/GameCoreTests/Resources/golden_features.json"
    with tempfile.TemporaryDirectory() as d:
        tmp = pathlib.Path(d) / "gf.json"
        r = subprocess.run([sys.executable, str(HERE / "gen_golden_features.py")], cwd=HERE,
                           env=dict(os.environ, GOLDEN_FEATURES_OUT=str(tmp)), capture_output=True, text=True)
        if r.returncode != 0 or not tmp.exists():
            print("❌ gen_golden_features.py を実行できない", file=sys.stderr); print(r.stderr[-500:], file=sys.stderr)
            return 2
        if json.loads(tmp.read_text(encoding="utf-8")) != json.loads(committed.read_text(encoding="utf-8")):
            print("❌ golden_features drift: cd tools && python3 gen_golden_features.py で再生成し swift test（規律A）")
            return 1
    print("✅ golden_features 一致（部屋・特技・店の台本）")
    import check_config_sync  # 10/27〜：定数の既定値の突き合わせも同じ点検で回す
    if check_config_sync.main() != 0:
        print("❌ config drift: GameConfig/Calendar の既定値と Python 正典がずれている（規律A）")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
