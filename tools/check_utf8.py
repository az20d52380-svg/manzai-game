#!/usr/bin/env python3
"""追跡中の文字ファイルが正しい UTF-8 かを確かめる（2026-11-10：START_HERE の行が途中で切れて不正バイトが入った事故の再発防止）。
mac の `cut -c`・`head -c` はバイト単位で切るので、日本語の行を切った結果を文書に書き戻すと壊れる。
使い方: python3 tools/check_utf8.py（壊れたファイルがあれば一覧して終了コード1）"""
import os, subprocess, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
exts = ('.md', '.swift', '.py', '.sh', '.json', '.yml', '.yaml', '.txt', '.csv')
files = subprocess.run(['git', 'ls-files'], cwd=root, capture_output=True, text=True).stdout.split('\n')
bad = []
n = 0
for f in files:
    p = os.path.join(root, f)
    if not f.endswith(exts) or not os.path.isfile(p):
        continue
    n += 1
    try:
        open(p, 'rb').read().decode('utf-8')
    except UnicodeDecodeError as e:
        bad.append(f'{f}（{e.start} バイト目）')
print(f'UTF-8: {n} 本中 壊れ {len(bad)}' + ('：' + '・'.join(bad) if bad else ''))
sys.exit(1 if bad else 0)
