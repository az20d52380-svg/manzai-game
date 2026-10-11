"""型×審査員の◎○△×表を「どの型も・どの審査員も ◎2 ○3 △1 ×1」に揃える（旧表に最も近い形で）。"""
import itertools
KATA = ["王道", "関係性", "伏線", "リターン", "非定型", "瞬発", "華先行"]
JUDGES = ["天堂寺", "花園", "卯月", "目白", "白波", "神楽坂", "音羽"]
OLD = {"王道": "◎○○○△◎○", "関係性": "○◎△△○○○", "伏線": "○△◎◎△○△", "リターン": "○△○○○◎○",
       "非定型": "×△◎○△◎△", "瞬発": "△○△△◎○◎", "華先行": "△○××○△◎"}
V = {"◎": 3, "○": 1, "△": 0, "×": -3}
S = [[V[OLD[k][j]] for j in range(7)] for k in KATA]
used = [[None] * 7 for _ in range(7)]
perms = list(itertools.permutations(range(7)))
def pick(sym, sign):
    best, bv = None, None
    for p in perms:
        if any(used[r][p[r]] for r in range(7)):
            continue
        v = sum(S[r][p[r]] for r in range(7)) * sign
        if bv is None or v > bv:
            best, bv = p, v
    for r in range(7):
        used[r][best[r]] = sym
for sym, sign in (("×", -1), ("◎", 1), ("◎", 1), ("△", -1)):
    pick(sym, sign)
for r in range(7):
    for c in range(7):
        used[r][c] = used[r][c] or "○"
print("型＼審査員 " + " ".join(JUDGES))
changes = 0
for r, k in enumerate(KATA):
    row = "".join(used[r])
    diff = "".join("^" if row[c] != OLD[k][c] else " " for c in range(7))
    changes += diff.count("^")
    print(f"{k:<5} 新 {row}  旧 {OLD[k]}  変更 {diff}")
print("変更セル数", changes)
