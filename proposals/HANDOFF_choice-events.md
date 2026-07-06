<!-- 引き継ぎメモ / 選択肢イベントをMVPへ実装（proposals専任セッション → MVP側CLIセッション）/ 2026-07-06 -->

# 【引き継ぎ】選択肢イベントを MVP に実装してください

会話/イベント強化の一環で、パワプロ サクセス風の「選択肢イベント」を14本 設計＆レッドチーム済み（`proposals/0010`〜`0023`）。オーナー確定で、この中の**薄い土台＋最初の3-4本**を MVP に入れることになった。実装は本体コードを持つ側（MVP側CLI）が担当。

## まず読む（正典＝この1枚）
- **`proposals/0024_choice-event-mvp-framework.md`** … 実装ブリーフ全部入り。
- 個別イベントの本文・効果値は `proposals/0017`・`0018`・`0019`・`0010` から転記。
- 着手前に `git pull --rebase` で `claude/manzai-slg-foundation-wprqlu` を最新化（0024含む proposals 一式が入っている）。

## 確定スコープ
- **入れる**: 確定発火（フラグを見て点火・**抽選しない**）＋確定効果（純加算/減算）の薄い土台。
- **入れない（本編送り）**: 週次ランダム抽選プール、効果内の乱数ロール（上振れ/下振れ等）。

## 絶対に守る一線（golden）
確定発火＋確定効果（`RandomSource` を一切呼ばないパッチ）に限れば、runner の乱数消費順が動かない＝**3年 golden ビット不変・Python正典同期も不要・`swift test` 緑のまま**。
→ ランダム抽選化 or 効果でサイコロを振った瞬間に消費順＝golden に触れる。そのときは必ず `tools/*.py`→GameCore→`gen_golden.py` 再生成→`swift test` 緑 を**1コミットで揃える**（＝別タスク・要相談）。**MVPではやらない。**

## 土台3ピース（詳細は0024に貼れる骨子あり）
1. **GameCore**: `WeekRunner.applyEventPatch((inout GameState)->Void)` ※RandomSource非呼出・~10行
2. **GameSession**: `justLost` フラグ / `pendingEvent` / `applyEventChoice`（UI層・golden非対象）
3. **UI**: `ChoiceEventOverlay`（2択＋話者切替の会話送り・新規SwiftUIビュー＝実工数の主）

## 最初の発火表（安い順）
| 採番 | イベント | 発火フラグ | 備考 |
|---|---|---|---|
| 0018 | 通った日の分かれ道 | `justPassedStage`（既存） | 最安・効果flat |
| 0019 | 型を捨てる相談 | `lossStreak>=3`（既存） | flat |
| 0017 | 負けた日の稽古場 | `justLost`（新設・0003と対称配線） | weakAbilityのメンタル混入バグは修正済 |
| 0010 | 前夜の一本 | `weeksLeft==1`・格の高い大会 | A内部ロールは本編送り＝B確定効果のみ |

## 完了の定義
- `swift test` 緑（golden不変を確認）＋ `applyEventPatch` の新規ユニットテスト
- `xcodegen generate` → simulator で各トリガまで送って**目視**（UIは swift test 不可）
- `sim_career.py` の `EVENTS_ON` で再計測 → 能力+効果の【仮】値を確定（`EVENT_FIRE_CAP=15` 予算内・優勝率1〜2%帯維持）

## 分担メモ
`proposals/` は提案専任セッションが持ち主、本体コードは実装側が持ち主。**同一ブランチの同時編集は禁止**（CLAUDE.md セッション運用ルール）＝提案側はこの件で本体コードを触らない。取り込み時は `event_design_v0` に「正典vN移行」バナーで設計→実装の差分を残すこと（§C-6）。
