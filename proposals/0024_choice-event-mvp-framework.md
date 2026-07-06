<!-- 提案 0024 / 選択肢イベントを MVP に入れる実装ブリーフ（MVP側CLIへの引き継ぎ）/ コード改変なし・設計のみ -->
<!-- オーナー確定(2026-07-06): MVPスコープ=「薄い確定発火の土台＋着火即可の3-4本」。実装はMVP側CLIが取り込む。本セッションはproposals専任＝コードは触らない。 -->

# 選択肢イベント MVP 実装ブリーフ v0（2026-07-06）

**このドキュメントは実装指示ではなく "MVP側CLIが着手するための地図" です。** 0010-0023 で設計・レッドチーム済の選択肢イベント群を、**golden をビット不変に保ったまま** MVP に載せる最小土台と、最初に入れる3-4本を定義する。数値は全て【仮】。

## 確定スコープ（オーナー判断・2026-07-06）

- **入れる**: 確定発火（フラグを見て点火・**抽選しない**）＋確定効果（純加算/減算）の**薄い土台**。
- **入れない（本編送り）**: 週次12%の**ランダム抽選プール**、効果内での**乱数ロール**（上振れ/下振れ等）。＝**これらは新規RNG消費＝golden破壊**なので MVP では触らない。
- **最初の3-4本**: 既存フラグで撃てるものを優先 → **0018 / 0019 / 0017（+ 0010）**（下記 発火表）。

## なぜ golden がビット不変で入るか（土台設計の芯）

現状の週ループ（`GameSession.pump()` → `freeAction` → `choose(action)` → `pump()`）で、**オファー抽選も含む乱数は runner が消費し終えた後**に `freeAction(offer:)` が来る。ここに:

1. **発火判定を "決定的フラグ" で行う**（`justPassedStage`・`lossStreak`・`weeksLeft`・自前の`justLost`）＝新しい乱数を引かない。
2. **効果を "決定的パッチ"（`RandomSource` を一切呼ばない `(inout GameState)->Void`）で適用**する。

この2条件を満たす限り、**runner の乱数列の位置は1ビットも動かない**＝ `gen_golden.py` / `WeekRunner` のビット一致（3年golden）は不変。しかも **`tools/*.py`（正典）の同期も不要**：数式も乱数消費順も変えていないから（CLAUDE §A-1 の対象外）。`swift test` は緑のまま。

> **一線（止めて相談）**: 「ランダムでイベントを選ぶ」「効果でサイコロを振る」を入れた瞬間に上の前提が崩れ、乱数消費順＝golden に触れる。**そのときだけ** ①`tools/*.py`→②GameCore→③`gen_golden.py`再生成→④`swift test`緑 を1コミットで揃える（§A-1/A-2）。MVPではやらない。

## 土台の3ピース（貼れる骨子・実APIに合わせた提案・未適用）

### ピース1: GameCore に決定的パッチの seam を足す（golden不変）

`GameSession.runner` は private・`state` は `pump()` が summary から毎週上書きするため、選択後のパッチを **runner の権威 state に永続させる口が無い**（0017レッドチーム指摘）。`RandomSource` を呼ばない mutating API を1本足す。

```swift
// 【提案・未適用】WeekRunner.swift に追加。RandomSource を一切呼ばない＝golden の乱数列に非干渉。
public mutating func applyEventPatch(_ patch: (inout GameState) -> Void) {
    patch(&state)          // state は runner の権威コピー。乱数を引かないので消費順に影響しない。
    state.clampAll()        // 既存の clamp 規約に合わせる（能力0-120・体力・money等）。※既存の clamp 関数名に合わせて呼ぶ
}
```

- `swift test`: golden 生成器はイベントを走らせない＝**期待値は不変**（緑のまま）。テストは「applyEventPatch 後に state が期待通り」の**新規ユニットテストのみ追加**（golden とは別系統）。
- Python同期: **不要**（数式・消費順を変えないため）。

### ピース2: GameSession に発火判定と保留状態を足す（UI層・golden不変）

```swift
// 【提案・未適用】GameSession.swift
// (a) justLost を pump() の敗退分岐で立てる（0003 と対称・§0017参照）。GameStateには足さない＝UI層フラグ＝golden不変。
private(set) var justLost = false
// pump() 内 :150-151 付近:
//   if r.passed { lossStreak = 0; justPassedStage = true;  justLost = false }
//   else        { lossStreak += 1; justPassedStage = false; justLost = true  }
// choose() :64 で justPassedStage=false と対称に justLost=false（行動したら余韻失効）。

// (b) freeAction 週頭で確定発火を判定し、保留イベントを1件持つ。
private(set) var pendingEvent: ChoiceEvent? = nil
// pump() が phase=.freeAction を確定した直後に評価（抽選しない・優先順で最初の1件だけ）:
//   pendingEvent = ChoiceEventTable.fire(state: state, lossStreak: lossStreak,
//                     justPassed: justPassedStage, justLost: justLost,
//                     nextMilestone: nextMilestone, config: config)

// (c) 選択の適用。決定的パッチを runner に流し、保留を消す。RNG非消費。
func applyEventChoice(_ choice: ChoiceEvent.Choice) {
    runner.applyEventPatch(choice.patch)   // ピース1
    pendingEvent = nil
    objectWillChange... / state = runner.snapshot() 等、既存の state 同期経路に合わせて反映
}
```

`ChoiceEvent` はGameCore純データ（`id` / `[Choice(label, patch, lines:[Advice])]`）。テキストは既に 0010-0023 に確定。効果 `patch` は各提案の【効果】節そのまま（純加算/減算のみ）。

### ピース3: UI に2択オーバーレイ＋話者切替の会話送り（新規SwiftUIビュー・**ここが実工数の主**）

`WeekMainView` は `monoBox`（`Advice` 1行）しか描かない。イベントは **`session.pendingEvent != nil` のとき全面オーバーレイ**で割り込む。

```swift
// 【提案・未適用】ChoiceEventOverlay.swift（新規）。WeekMainView に .overlay で重ねる。
// 構成: セットアップ地の文 → 話者切替の会話送り(タップで1セリフずつ) → 2-3択ボタン → applyEventChoice → dismiss。
// 話者切替: Advice.name は既に nullable（"俺"/相方ID）。谷口=関西弁プール/俺=標準語/相方は相方IDで差し替え。
//   ＝monoBoxの1行描画を "話者名ラベル＋1セリフ＝タップ送り" に拡張した専用ビュー。
// 選択後の会話(各Choice.lines)も同じ送りで見せてから dismiss。
```

- **UIは `swift test` で検証不可**＝`cd ManzaiGame && xcodegen generate` → simulator でビルド→各トリガまで送って**目視**まで込みで「完了」（CLAUDE §D-9/D-10）。新規Swiftファイルは `project.yml` 正本・pbxproj手編集しない。

## 発火表（最初の3-4本・全て確定発火・golden不変）

| 採番 | イベント | 発火フラグ（実在確認） | 効果の性質 | MVP準備コスト |
|---|---|---|---|---|
| **0018** | 通った日の分かれ道 | `justPassedStage`（**GameSessionに実在**）＋`weeksLeft>=3` | flat（知名度 vs 能力+1）※原案の「稽古枠-1」は撤回済→メンタル-1 | **最安**（フラグ既存・効果flat） |
| **0019** | 型を捨てる相談 | `lossStreak >= 3`（**実在**） | flat（発想+2/相性-2 ↔ 表現+2/相性+1）※支配戦略穴は表現-1追加で修正済 | 安（フラグ既存） |
| **0017** | 負けた日の稽古場 | `justLost`（**新設・ピース2a**／0003と対称配線） | flat（最弱**4技能**+2・**メンタル除外版**で効果バグ回避済）/メンタル-2/体力-10 | 中（justLost配線が要る） |
| **0010** | 前夜の一本 | `weeksLeft==1` かつ格の高い大会 | B=flat（体力+10/メンタル+1）。**A内部ロールは本編送り**＝MVPはA確定効果のみ | 中（格判定＝calendarラベル突合） |

- **0011-0016・0020-0023** は「金欠×抽選」「相性帯の新設」「オファー変種」等、**追加の土台（抽選 or 帯フック or OfferSpec拡張）**が要るので第2弾以降。0022 は既存 `OfferSpec` 変種として比較的安く足せる候補（golden不変）。

## バランス（sim）— 数値確定の前に一度回す

- 0017/0018/0019 は **能力+1〜2（恒久）** を配る＝分布に効く。`tools/sim_career.py` の `EVENTS_ON`（既定OFF）に近似効果を足し、**`EVENT_FIRE_CAP=15`（§4-B）予算内**で優勝率1〜2%帯維持を再計測してから最終値を確定（体感を数値で直さない・ui_design §7-B）。**golden は動かない**（sim と golden は別系統）。
- 数値は全て各提案の【仮】。sim実測でA/B拮抗（明白な最適解が出ないか）を確認。

## 実装チェックリスト（MVP側CLI向け）

1. [ ] ピース1 `applyEventPatch` を GameCore に追加 → `swift test` 緑（golden不変を確認）＋新規ユニットテスト。
2. [ ] ピース2 `justLost` / `pendingEvent` / `applyEventChoice` を GameSession に追加（UI層・golden非対象）。
3. [ ] `ChoiceEvent` 純データ＋発火表（0018→0019→0017→0010 の優先順）を定義。テキスト/効果は 0010/0017/0018/0019 から転記。
4. [ ] ピース3 `ChoiceEventOverlay` 新規ビュー → `xcodegen generate` → simulator で各トリガ目視。
5. [ ] `sim_career.py` EVENTS_ON で再計測 → 【仮】値を確定。
6. [ ] **禁止**: 抽選プール化・効果の乱数ロールは入れない（入れるなら golden 正典同期を1コミットで揃える＝別タスク・要相談）。

## リスク・注意

- **golden の一線**（再掲）: 確定発火＋確定効果に限り不変。ランダム化した瞬間に消費順＝golden に触れる＝止めて相談。
- **0017 は 0003（justLost 内心一言）とセット**。justLost フラグの配線を共有する。
- **話者切替UIは 0003 とも共通の未実装前提**＝一度作れば全会話イベントで再利用できる（先行投資）。
- **効果バグ（0017）**: 既存 `weakAbility()` はメンタルを含む＝そのまま流用するとA「弱い能力+2」がメンタルに当たり同Aのメンタル-2と相殺。**メンタル除外版**を使う（0017本文に修正済）。
- **セッション分担**: 本体コードはMVP側CLIが持ち主。本セッション（proposals専任）はコードを触らない。取り込み時は該当docへ「正典vN移行」バナーで event_design_v0 の設計→実装差分を残す（§C-6）。
