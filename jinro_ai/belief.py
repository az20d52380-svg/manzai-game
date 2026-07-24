"""信念/確率エンジン: 公開情報から各プレイヤーの人狼確率を出す。

考え方（あり得る配役の世界を数える）:
- 部屋の役職構成（何人・何役）は公開情報。開始時の全 N スロットへの役職割当を「世界」とする。
- 占い師/霊媒師は真実しか言わない、という唯一のハード制約で世界を絞る:
  ある世界で本物の占い師に割り当たった人が公開申告をしているなら、その申告は真でなければ
  ならない（対象が人狼か否かが申告と一致）。矛盾する世界は不可能として除外。
  騙り（人狼/狂人/村人が占い師を騙る）は、その世界で本物ではないので申告は嘘＝制約なし。
- 各人狼確率 P(i=人狼) = (iが人狼である無矛盾な世界数) / (無矛盾な世界数)。

重要な性質: これは“論理の骨格”。単独COの黒は論理的には確定ではない（騙りの可能性）ため、
確率は拡散する。実戦の「COした人は本物寄り」という behavioral prior はここには入れない
（エージェント側で足す）。数式・乱数は使わない純関数なので golden 化しやすい。

計算量: 人狼位置の組合せ C(N, 狼数) を回すだけ（標準9人・狼2なら36通り）。占い師/霊媒師の
割当は解析的に数える（下記）。実測ミリ秒未満。占い師・霊媒師が各1（0でも可）の構成を対象。
"""
from __future__ import annotations

from itertools import combinations

from .roles import Role
from .game import View


def _reports_by(reports) -> dict[int, list[tuple[int, bool]]]:
    d: dict[int, list[tuple[int, bool]]] = {}
    for r in reports:
        d.setdefault(r.reporter, []).append((r.target, r.wolf))
    return d


def _consistent(reports: list[tuple[int, bool]], wolfset: set[int]) -> bool:
    """本物として、その申告が人狼集合 wolfset と全て一致するか。"""
    return all((t in wolfset) == wolf for (t, wolf) in reports)


def wolf_probabilities(view: View) -> dict[int, float]:
    players = [pid for pid, _, _ in view.players]
    n = len(players)
    comp = view.composition
    wolf_count = comp.get(Role.WEREWOLF, 0)
    seer_count = comp.get(Role.SEER, 0)
    medium_count = comp.get(Role.MEDIUM, 0)

    if wolf_count <= 0:
        return {p: 0.0 for p in players}
    if wolf_count >= n:
        return {p: 1.0 for p in players}

    seer_rep = _reports_by(view.seer_reports)
    med_rep = _reports_by(view.medium_reports)

    total = 0.0
    hits = {p: 0.0 for p in players}

    for W in combinations(players, wolf_count):
        Wset = set(W)
        nonw = [p for p in players if p not in Wset]

        # 本物の占い師になり得る非狼スロット数（申告があるなら無矛盾に限る）
        if seer_count >= 1:
            valid_seers = [p for p in nonw if p not in seer_rep or _consistent(seer_rep[p], Wset)]
            vs = valid_seers
        else:
            vs = None  # 占い師不在の構成: 占いCOは全て騙り＝制約なし

        if medium_count >= 1:
            valid_mediums = [p for p in nonw if p not in med_rep or _consistent(med_rep[p], Wset)]
            vm = valid_mediums
        else:
            vm = None

        # (占い師スロット, 霊媒師スロット) の割当数を数える（他役は残りに対称配置＝定数で相殺）
        if vs is not None and vm is not None:
            pairs = len(vs) * len(vm) - len(set(vs) & set(vm))  # s != m
        elif vs is not None:
            pairs = len(vs)
        elif vm is not None:
            pairs = len(vm)
        else:
            pairs = 1

        if pairs <= 0:
            continue  # この人狼配置は矛盾（本物の占い/霊媒を置けない）→ 不可能

        weight = float(pairs)
        total += weight
        for p in W:
            hits[p] += weight

    if total <= 0:  # 理論上到達しない（真の世界は必ず無矛盾）。保険で一様。
        base = wolf_count / n
        return {p: base for p in players}
    return {p: hits[p] / total for p in players}
