#!/usr/bin/env python3
"""本番画面の明るさの検収（見た目の作り直し v1・docs/visual_genre_overhaul_v1.md §4-1）。

使い方: python3 tools/measure_brightness.py feedback_shots/overhaul_v1/after_*.png
出力: 画面ごとに 平均L（WCAG 相対輝度）／点灯面積（L>0.3 の割合）／紫の暗部（L<0.1 かつ B>R+8 の割合）。
目標【仮】: 本番画面は 平均L 0.18以上・点灯面積35%以上・紫の暗部ほぼ0。
方法: macOS の sips で 201px 幅に縮めてから標準ライブラリだけで PNG を復号（上端7%＝ステータスバーと下端2%を除く）。
GameCore とは無関係（表示の計測だけ）。
"""
import os
import struct
import subprocess
import sys
import tempfile
import zlib


def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def _decode_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'PNG ではない'
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        ln, typ = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and interlace == 0, '8bit 非インターレースだけ対応'
            bpp = {2: 3, 6: 4}[ctype]
        elif typ == b'IDAT':
            idat += body
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line); prev = line
    return w, h, bpp, rows


def measure(path):
    with tempfile.TemporaryDirectory() as d:
        small = os.path.join(d, 's.png')
        subprocess.run(['sips', '-s', 'format', 'png', '-Z', '440', path, '--out', small],
                       check=True, capture_output=True)
        w, h, bpp, rows = _decode_png(small)
    total = lit = purple = 0
    acc = 0.0
    for y in range(int(h * 0.07), int(h * 0.98)):
        r_ = rows[y]
        for x in range(0, w * bpp, bpp):
            r, g, b = r_[x], r_[x + 1], r_[x + 2]
            L = 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)
            acc += L; total += 1
            if L > 0.3: lit += 1
            if L < 0.1 and b > r + 8: purple += 1
    return acc / total, lit / total, purple / total


if __name__ == '__main__':
    for p in sys.argv[1:]:
        m, l, pu = measure(p)
        print(f'{os.path.basename(p):40s} 平均L {m:.3f}  点灯面積 {l * 100:5.1f}%  紫の暗部 {pu * 100:5.1f}%')
