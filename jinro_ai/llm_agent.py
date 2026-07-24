"""LLMAgent: Claude をブレインにした人狼プレイヤー（信念エンジンで地固め）。

CICERO 流のハイブリッド:
- 決定論の信念エンジン(belief.py)が各人の人狼確率を出して「計算ミスしない」地固めをし、
- その確率＋全公開情報＋自分の秘密情報をプロンプトに載せて、Claude が推論と自然な日本語の
  発言／弁明／（人狼・狂人なら）騙り／投票・夜行動を出す。

キー無し(use_api=False)では BeliefAgent の強い手にテンプレ発言を添えて動く——ロジック核は
決定論のままテストでき、環境変数 ANTHROPIC_API_KEY を入れて use_api=True にすると本物の発言に。

必要（API利用時）: `pip install anthropic` ＋ 環境変数 ANTHROPIC_API_KEY（＝あなたの課金）。
モデルは claude-opus-4-8 既定・adaptive thinking・構造化出力(JSON)。self-play で大量に回すなら
effort/model を下げてコスト調整（強さ優先なら既定のまま）。
"""
from __future__ import annotations

import json
import os

from .roles import Role, Camp, spec
from .game import View
from .agents import BeliefAgent
from .belief import wolf_probabilities

MODEL = "claude-opus-4-8"

# ---- 構造化出力スキーマ（json_schema: strict なので additionalProperties/required 必須）----
STATEMENT_SCHEMA = {
    "type": "object",
    "properties": {
        "reasoning": {"type": "string"},
        "co": {"type": "string", "enum": ["占い師", "霊媒師", "狩人", "村人", "なし"]},
        "claim_target": {"type": "integer"},  # 占い/霊媒を騙る時の対象 pid。しないなら -1
        "claim_wolf": {"type": "boolean"},     # その申告を「人狼(黒)」とするか
        "talk": {"type": "string"},            # 自然な日本語の発言（簡潔に）
    },
    "required": ["reasoning", "co", "claim_target", "claim_wolf", "talk"],
    "additionalProperties": False,
}
VOTE_SCHEMA = {
    "type": "object",
    "properties": {"reasoning": {"type": "string"}, "vote": {"type": "integer"}},
    "required": ["reasoning", "vote"],
    "additionalProperties": False,
}
TARGET_SCHEMA = {
    "type": "object",
    "properties": {"reasoning": {"type": "string"}, "target": {"type": "integer"}},
    "required": ["reasoning", "target"],
    "additionalProperties": False,
}


def _name(view: View, pid: int) -> str:
    for q, nm, _ in view.players:
        if q == pid:
            return nm
    return f"P{pid}"


def build_context(view: View) -> str:
    """View を Claude が読める日本語のゲーム状況テキストにする（信念確率つき地固め）。"""
    L: list[str] = []
    comp = ", ".join(f"{r.value}{n}" for r, n in view.composition.items())
    L.append(f"【構成】{comp}（全{len(view.players)}人）  現在: {view.day}日目")
    alive = [_name(view, p) for p in view.alive]
    L.append(f"【生存】{', '.join(alive)}")

    if view.claims:
        cos = ", ".join(f"{_name(view, p)}→{rl.value}" for p, rl in view.claims.items())
        L.append(f"【CO】{cos}")
    for label, reps in (("占い報告", view.seer_reports), ("霊媒報告", view.medium_reports)):
        if reps:
            s = "; ".join(f"{_name(view, r.reporter)}→{_name(view, r.target)}:"
                          f"{'人狼' if r.wolf else '人間'}" for r in reps)
            L.append(f"【{label}】{s}")
    if view.executions:
        L.append(f"【処刑】{', '.join(_name(view, p) for p in view.executions)}")
    if view.night_deaths:
        L.append(f"【襲撃死】{', '.join(_name(view, p) for p in view.night_deaths)}")
    if view.speeches:
        L.append("【これまでの発言】")
        for sp in view.speeches[-15:]:
            L.append(f"  {_name(view, sp['pid'])}: {sp['text']}")

    # 信念エンジン（論理の地固め）
    probs = wolf_probabilities(view)
    ranked = sorted((p for p in view.alive), key=lambda p: -probs.get(p, 0.0))
    L.append("【信念エンジンの人狼確率（生存者・降順）】")
    L.append("  " + ", ".join(f"{_name(view, p)}:{probs.get(p, 0.0):.0%}" for p in ranked))

    # 自分の情報
    role = view.self_role
    L.append(f"【あなた】{_name(view, view.self_id)} / 役職: {role.value} / 陣営: {view.self_camp.value}")
    if view.fellow_wolves:
        L.append(f"  （秘密）仲間の人狼: {', '.join(_name(view, w) for w in view.fellow_wolves)}")
    if role == Role.SEER and view.my_divinations:
        s = "; ".join(f"{_name(view, r.target)}:{'人狼' if r.wolf else '人間'}" for r in view.my_divinations)
        L.append(f"  （秘密）自分の占い結果: {s}")
    if role == Role.MEDIUM and view.my_medium:
        s = "; ".join(f"{_name(view, r.target)}:{'人狼' if r.wolf else '人間'}" for r in view.my_medium)
        L.append(f"  （秘密）自分の霊媒結果: {s}")
    return "\n".join(L)


_SYSTEM = (
    "あなたは人狼ゲームの熟練プレイヤーAI。目的は自分の陣営の勝利のみ。"
    "『信念エンジンの人狼確率』は論理的な地固め（数え上げに基づく計算補助・鵜呑みにはしない）。"
    "それと全公開情報・自分の秘密情報を踏まえ、勝利確率を最大化する判断をせよ。"
    "村人陣営なら人狼を炙り出し吊る。人狼・狂人なら疑いを逸らし村を欺く（占い騙り等）。"
    "本物の占い師/霊媒師は自分の結果を偽らない。発言(talk)は自然で簡潔な日本語。"
    "出力は指定スキーマのJSONのみ。"
)


class LLMAgent(BeliefAgent):
    """Claude ブレイン。use_api=False なら BeliefAgent の手＋テンプレ発言で動く。"""

    def __init__(self, use_api: bool = False, model: str = MODEL,
                 effort: str = "medium", max_tokens: int = 2048):
        super().__init__()
        self.use_api = use_api
        self.model = model
        self.effort = effort
        self.max_tokens = max_tokens
        self._client = None

    # ---- Claude 呼び出し（遅延import: キー無し環境でもモジュールのimportは通る）----
    def _ask(self, view: View, instructions: str, schema: dict) -> dict:
        if self._client is None:
            import anthropic
            self._client = anthropic.Anthropic()
        resp = self._client.messages.create(
            model=self.model,
            max_tokens=self.max_tokens,
            thinking={"type": "adaptive"},
            output_config={"effort": self.effort,
                           "format": {"type": "json_schema", "schema": schema}},
            system=_SYSTEM,
            messages=[{"role": "user", "content": build_context(view) + "\n\n" + instructions}],
        )
        text = next((b.text for b in resp.content if b.type == "text"), "{}")
        return json.loads(text)

    # ---- 昼: 発言 ----
    def statement(self, view: View) -> dict:
        if not self.use_api:
            act = super().statement(view)
            act["talk"] = self._offline_talk(view, act)
            return act
        try:
            d = self._ask(view, (
                "いま昼の発言フェーズ。COするか、占い/霊媒を騙るか、潜伏か決め、talk を書け。"
                "占い師/霊媒師を騙る場合のみ claim_target に対象pid・claim_wolf に黒白を入れる"
                "（騙らないなら co=なし か 村人、claim_target=-1）。"), STATEMENT_SCHEMA)
            return self._apply_statement(view, d)
        except Exception:  # API/JSON 失敗時は強い定石にフォールバック
            act = super().statement(view)
            act["talk"] = self._offline_talk(view, act)
            return act

    def _apply_statement(self, view: View, d: dict) -> dict:
        role = view.self_role
        act: dict = {"talk": d.get("talk", "")}
        # 本物の占い師/霊媒師は自分の結果を偽らせない（地の真実を保護）
        if role == Role.SEER:
            act["co"] = Role.SEER
            if view.my_divinations:
                r = view.my_divinations[-1]
                act["seer_report"] = (r.target, r.wolf)
            return act
        if role == Role.MEDIUM:
            if view.executions:
                act["co"] = Role.MEDIUM
                if view.my_medium:
                    r = view.my_medium[-1]
                    act["medium_report"] = (r.target, r.wolf)
            return act
        # それ以外は Claude の判断（騙り含む）を尊重
        co = d.get("co", "なし")
        tgt, wolf = int(d.get("claim_target", -1)), bool(d.get("claim_wolf", False))
        if co == "占い師":
            act["co"] = Role.SEER
            if tgt in view.alive:
                act["seer_report"] = (tgt, wolf)
        elif co == "霊媒師":
            act["co"] = Role.MEDIUM
            if tgt in view.alive:
                act["medium_report"] = (tgt, wolf)
        elif co in ("狩人", "村人"):
            act["co"] = Role.HUNTER if co == "狩人" else Role.VILLAGER
        return act

    # ---- 昼: 投票 ----
    def vote(self, view: View) -> int:
        if not self.use_api:
            return super().vote(view)
        try:
            d = self._ask(view, "いま投票フェーズ。誰を吊るか vote に対象の生存者pidで答えよ。", VOTE_SCHEMA)
            v = int(d.get("vote", -1))
            return v if (v in view.alive and v != view.self_id) else super().vote(view)
        except Exception:
            return super().vote(view)

    # ---- 夜 ----
    def divine(self, view: View) -> int:
        return self._night_target(view, "占う相手", super().divine)

    def guard(self, view: View) -> int:
        return self._night_target(view, "護衛する相手", super().guard)

    def attack(self, view: View) -> int:
        return self._night_target(view, "襲撃する相手（人狼として）", super().attack)

    def _night_target(self, view: View, what: str, fallback) -> int:
        if not self.use_api:
            return fallback(view)
        try:
            d = self._ask(view, f"いま夜。{what}を target に生存者pidで答えよ。", TARGET_SCHEMA)
            t = int(d.get("target", -1))
            return t if (t in view.alive and t != view.self_id) else fallback(view)
        except Exception:
            return fallback(view)

    # ---- オフライン用テンプレ発言（キー無しでもパイプラインが動くように）----
    def _offline_talk(self, view: View, act: dict) -> str:
        role = view.self_role
        sr = act.get("seer_report")
        if act.get("co") == Role.SEER:
            if sr and sr[1]:
                return f"占い師CO。{_name(view, sr[0])}を占って人狼だった。吊りたい。"
            if role == Role.SEER:
                return "占い師CO。今のところ白しか出ていない。グレーを詰めよう。"
            return f"占い師CO。{_name(view, sr[0]) if sr else 'あいつ'}が人狼だ。"
        if act.get("co") == Role.MEDIUM:
            mr = act.get("medium_report")
            if mr:
                return f"霊媒師CO。昨日の処刑者は{'人狼' if mr[1] else '人間'}。"
            return "霊媒師CO。結果はこれから伝える。"
        probs = wolf_probabilities(view)
        cand = [p for p in view.alive if p != view.self_id]
        if cand:
            top = max(cand, key=lambda p: probs.get(p, 0.0))
            if probs.get(top, 0.0) > 0.3:
                return f"{_name(view, top)}が怪しいと思う。"
        return ""
