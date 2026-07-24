"""役職定義（MVP: 標準村の6種）。

このリポジトリ方針に準じ、固有名・大会名は使わない。
まず土台になる標準的な6役のみを実装し、拡張（妖狐・共有者・大狼・
囁き狂人 …）は ROLE_SPECS に1行足すだけで済むよう、役職メタデータ
（陣営・占い結果・霊媒結果・夜行動）をここに集約する。
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Camp(Enum):
    VILLAGE = "村人陣営"
    WEREWOLF = "人狼陣営"
    # FOX = "妖狐陣営"  # 第三陣営は後で追加する


class NightAction(Enum):
    NONE = "なし"
    DIVINE = "占う"   # 占い師
    GUARD = "護衛"    # 狩人
    ATTACK = "襲撃"   # 人狼
    # 霊媒は「処刑者の役職を知る」受動効果なので夜アクションではなく朝の通知で扱う


class Role(Enum):
    VILLAGER = "村人"
    SEER = "占い師"
    MEDIUM = "霊媒師"
    HUNTER = "狩人"
    WEREWOLF = "人狼"
    MADMAN = "狂人"


@dataclass(frozen=True)
class RoleSpec:
    role: Role
    camp: Camp                 # 勝敗判定上の陣営（狂人は人狼陣営）
    is_werewolf: bool          # 実際の人狼か（襲撃・仲間認識・生存数パリティに使う）
    divined_as_wolf: bool      # 占い結果が「人狼(黒)」か
    medium_as_wolf: bool       # 霊媒結果が「人狼(黒)」か
    night_action: NightAction
    knows_execution: bool = False  # 処刑者の霊媒結果を受け取るか（霊媒師）


# 狂人(MADMAN): 勝敗は人狼陣営だが、is_werewolf=False（人数カウントは人間側・占いは白・
# 仲間としては人狼から見えない）。この二面性が狂人の肝。
ROLE_SPECS: dict[Role, RoleSpec] = {
    Role.VILLAGER: RoleSpec(Role.VILLAGER, Camp.VILLAGE,  False, False, False, NightAction.NONE),
    Role.SEER:     RoleSpec(Role.SEER,     Camp.VILLAGE,  False, False, False, NightAction.DIVINE),
    Role.MEDIUM:   RoleSpec(Role.MEDIUM,   Camp.VILLAGE,  False, False, False, NightAction.NONE, knows_execution=True),
    Role.HUNTER:   RoleSpec(Role.HUNTER,   Camp.VILLAGE,  False, False, False, NightAction.GUARD),
    Role.WEREWOLF: RoleSpec(Role.WEREWOLF, Camp.WEREWOLF, True,  True,  True,  NightAction.ATTACK),
    Role.MADMAN:   RoleSpec(Role.MADMAN,   Camp.WEREWOLF, False, False, False, NightAction.NONE),
}


def spec(role: Role) -> RoleSpec:
    return ROLE_SPECS[role]
