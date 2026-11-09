#!/usr/bin/env python3
"""文の長さの点検（AUTOPILOT 182 の「lens.py 相当」を常設に）。

Swift の文字列リテラルを、直前の `static let/var 名前` の配列ごとにまとめ、
本数と最長（表示の字数）を出す。--base を付けると、その版から増えた文のうち
「同じ配列の base での最長」を超えるものだけを列挙する（目視が要る候補）。

  python3 tools/text_lens.py                       # 既定 DialogueData.swift の配列ごとの本数・最長（上位10）
  python3 tools/text_lens.py --base origin/main FILE...
  python3 tools/text_lens.py --base a3406ee8 --all
  python3 tools/text_lens.py --base HEAD --head origin/claude/lull-plus-cand

字数：{me} 等の差し込みは4字・〈大会〉等の山括弧は中身の字数で数える（概算）。
出力は要約行だけ（超えた文があれば1行ずつ・最大20行）。
"""
import argparse
import re
import subprocess
import sys

DEFAULT = ["ManzaiGame/Sources/DialogueData.swift"]
DECL = re.compile(r"static\s+(?:let|var)\s+([^\s:=]+)")
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def width(s: str) -> int:
    s = re.sub(r"\\\(.*?\)", "xxxx", s)      # Swift の補間
    s = re.sub(r"\{[a-zA-Z0-9_]+\}", "xxxx", s)  # {me} {partner1}
    s = s.replace("〈", "").replace("〉", "")
    s = s.replace("\\n", "")
    return len(s)


def scan(text: str):
    """{配列名: [文...]}。コメント行は飛ばす。キーっぽい短い ASCII は数えない。"""
    out, cur = {}, "(top)"
    for line in text.splitlines():
        code = line.split("//", 1)[0] if '"' not in line.split("//", 1)[0] else line
        m = DECL.search(code)
        if m:
            cur = m.group(1)
        if code.lstrip().startswith("//"):
            continue
        for s in STR.findall(code):
            if not s or re.fullmatch(r"[A-Za-z0-9_.\- ]*", s):
                continue  # 辞書のキー・識別子
            out.setdefault(cur, []).append(s)
    return out


def read(ref, path):
    if ref is None:
        with open(path, encoding="utf-8") as f:
            return f.read()
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", default=DEFAULT)
    ap.add_argument("--base")
    ap.add_argument("--head", help="作業ツリーの代わりに読む版（候補ブランチ等）")
    ap.add_argument("--all", action="store_true", help="配列の一覧を全部出す")
    a = ap.parse_args()

    over, added_n, rows = [], 0, []
    for path in a.files:
        now = scan(read(a.head, path))
        for name, ss in now.items():
            rows.append((max(width(s) for s in ss), len(ss), f"{path.split('/')[-1]}:{name}"))
        if a.base:
            old = scan(read(a.base, path))
            for name, ss in now.items():
                prev = old.get(name, [])
                base_max = max((width(s) for s in prev), default=0)
                pool = list(prev)
                for s in ss:
                    if s in pool:
                        pool.remove(s)
                        continue
                    added_n += 1
                    if prev and width(s) > base_max:
                        over.append((width(s), base_max, name, s))

    rows.sort(reverse=True)
    allmax = rows[0][0] if rows else 0
    print(f"配列 {len(rows)} 個・文 {sum(r[1] for r in rows)} 本・最長 {allmax} 字")
    for w, n, name in (rows if a.all else rows[:10]):
        print(f"  {w:3d}字 {n:4d}本 {name}")
    if a.base:
        print(f"base {a.base} から増えた文 {added_n} 本・配列の元の最長を超えた {len(over)} 本")
        for w, bm, name, s in sorted(over, reverse=True)[:20]:
            print(f"  {w}字>{bm} {name}: {s[:40]}")
        return 1 if over else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
