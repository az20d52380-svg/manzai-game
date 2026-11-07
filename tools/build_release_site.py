#!/usr/bin/env python3
"""発売用の公開ページ（サポート・プライバシー・特商法・提供割合）を docs/release/*.md から静的 HTML にする。
公開はしない（docs/release/site/ に作るだけ。GitHub Pages に置くのはオーナー＝release_checklist §6）。
正本は .md。「---」より下だけを公開する。埋まっていない【　】の数を出す（残っていれば終了コード1＝まだ公開できない）。"""
import html, re, sys
from pathlib import Path

REL = Path(__file__).resolve().parent.parent / "docs" / "release"
OUT = REL / "site"
PAGES = {"support": "support_ja.md", "privacy": "privacy_policy_ja.md",
         "tokushoho": "tokushoho_ja.md", "gacha_rates": "gacha_rates_page.md"}
CSS = """:root{--bg:#f7f2e6;--fg:#2a2622;--line:#cfc6b2;--link:#a8321f}
@media (prefers-color-scheme:dark){:root{--bg:#1d1a17;--fg:#ece6d8;--line:#4a443a;--link:#e58a74}}
body{background:var(--bg);color:var(--fg);font:16px/1.75 "Hiragino Sans",sans-serif;margin:0 auto;max-width:720px;padding:24px 16px}
h1{font-size:1.4em;line-height:1.4}h2{font-size:1.15em;margin-top:2em;border-bottom:1px solid var(--line)}h3{font-size:1em;margin-top:1.5em}
a{color:var(--link)}table{border-collapse:collapse;width:100%}th,td{border:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}"""


def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)


def convert(md):
    out, rows, items = [], [], []

    def flush():
        if items:
            out.append("<ul>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>")
            items.clear()
        if rows:
            head, *body = rows
            t = "<tr>" + "".join(f"<th>{c}</th>" for c in head) + "</tr>"
            t += "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in body)
            out.append(f"<table>{t}</table>")
            rows.clear()

    for line in md.splitlines():
        s = line.strip()
        if s.startswith("|"):
            if not re.fullmatch(r"[|\s:-]+", s):
                rows.append([inline(c.strip()) for c in s.strip("|").split("|")])
            continue
        if s.startswith("- "):
            items.append(inline(s[2:]))
            continue
        flush()
        if m := re.match(r"(#{1,4}) (.+)", s):
            out.append(f"<h{len(m[1])}>{inline(m[2])}</h{len(m[1])}>")
        elif s:
            out.append(f"<p>{inline(s)}</p>")
    flush()
    return "\n".join(out)


def main():
    OUT.mkdir(exist_ok=True)
    total = 0
    for name, src in PAGES.items():
        text = (REL / src).read_text(encoding="utf8")
        body = text.split("\n---\n", 1)[1]
        left = re.findall(r"【[^】]*】", body)
        total += len([x for x in left if x != "【仮】"])
        title = re.search(r"^# (.+)$", body, re.M)[1]
        (OUT / f"{name}.html").write_text(
            f'<!doctype html><html lang="ja"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f"<title>{html.escape(title)}</title><style>{CSS}</style></head><body>\n{convert(body)}\n</body></html>\n",
            encoding="utf8")
        print(f"{name}.html: 【】残り {len(left)}（うち【仮】{left.count('【仮】')}）")
    print("まだ公開できない（埋まっていない【】あり）" if total else "【仮】以外は埋まった")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
