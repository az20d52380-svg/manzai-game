# 選択肢イベント効果の突き合わせ（Swift ↔ Python 鏡像）1108 v0

## 結論
- 一致 62 / 不一致 0 / 未対応 0（Python キー29＝`_app_apply` 13 + `_others_apply` 16、Swift case 36）。効果は現時点で全て同値。
- Python ボットが一度も選ばない Swift 選択肢は styleTalk/A のみ（ボットは B 固定の方針。仕様どおり）。
- 読めなかった効果なし（growthCeiling・rift は記録のみで比較対象外）。

## 方法
`tools/check_event_parity.py`（読むだけ・不一致で終了コード1）。ChoiceEvent.swift の `choices(for:)` を正規表現で読み、
Python の `_app_apply`/`_others_apply` を状態格子（体力15値×所持金23値×能力配置2、知名度50・メンタル50・相性10＝クランプ非発動）で実行して
前後差分を取り、Swift のどれかの選択肢（weakest/weaker は状態で解決）と完全一致するか判定。
対応表（Python キー→Swift case）はスクリプト内 KEYMAP。netaBoost(2週)・preoccupy(1週)・regularJobCeilingCost(1.5)は GameConfig 既定を固定値で照合。

## 不一致の表
なし。

## 読めなかった物
なし（growthCeiling／rift は Python 鏡像に無い効果として記録のみ）。

## 限界
- ゲート（`gate:`）条件と Python 方針の閾値（例: 所持金>=X）は照合していない。差分一致のみ。
- 発火帯（weeklyBandFireable と `_app_band`/`_others_fireable`）は対象外。
- Python 鏡像が無い Swift case（regularEmployment=廃止, riftWarning, weekendInvite, フレーバー4種）は対象外。
- ボットが何もしない状態（所持金不足で効果なし）2件は不一致扱いにしていない。
- GameConfig の既定値はスクリプト内に固定で写している（変わったら要更新）。

## §発火条件（2026-11-08 追記）
`tools/check_event_trigger_parity.py`（読むだけ・追加ファイルのみ・既存 .py/Swift は無変更。`--choice`/`--session` で Swift の差し替え可。読めない条件か不一致があれば終了コード1）。

### 方法
- Swift 側は正規表現で式を読み Python 式に機械翻訳して評価：`ChoiceEvent.swift` の `isWeeklyRandom`（プール）・`weeklyBandFireable`（帯）・`choices(for:)` の `gate:`（1つも選べないイベントは出さない共通ルール）、`GameSession.swift` の `weeklyExtraGate`（年・バイト回数・本番までの週・連敗など）と `evaluateChoiceEventFire`（確定発火の連鎖と優先順位）。翻訳できない式は「読めない」。
- Python 側は `sim_career._app_band`＋yearend の所持金ゲート（週次候補）と `_app_week_event`（確定発火。`EVENT_RATE=0` にして抽選を止めて呼ぶ）。
- 状態は固定シード乱択 20万件ずつ：週次＝年(1-3)・週(閾値±1)・体力・知名度・所持金・相性(小数含む)・持ちネタ有無・バイト回数・連敗・本番までの週(1-9/無し)を閾値の両側で振る。確定発火＝上に各「一発」フラグを1つずつ立てた状態・連敗・通過/敗退直後・次本番までの週と格を振り、Swift の連鎖の勝者と Python が発火させたキーを比べる。

### 結果
- 一致 26／不一致 0／読めない 1。
  - 週次抽選：プール25種の顔ぶれが一致。全25種×20万状態で、Python の候補判定と Swift（帯＋追加ゲート＋選択肢 gate）が全件一致。COMPAT_CAP も 20 で一致。
  - 確定発火：連鎖の優先順位（justLost > styleTalk > passFork > eve > early > tsuuka > nameless > taniguchi）と各条件が全件一致。
- 読めない 1：`preTournamentEve` の `!(state.femaleCombo == true && 週==花の大会)` 節（花の動画審査は前夜を出さない）。Python 鏡像に femaleCombo が無いので未照合（True 扱いで比べた）。
- 検査の効き確認：Swift のコピーで閾値を6か所（fan 15→16・homecoming 週38→37・kouhai 週24→25・tsuuka 相性15→14・taniguchi 3週→2週 等）変えると、週次3種＋確定発火3通りの不一致を検出（終了コード1）。元ファイルは無変更。

### 限界（未照合）
- フラグの立て方・下ろし方（例: earlyFormality/tsuuka は Swift では発火時でなく選択時にフラグが立つ、jp/jl の失効タイミング、styleTalk の再武装）は静的な状態として与えただけで、遷移は比べていない。
- riftWarning・weekendInvite（別実装）は連鎖の読み取りのみで Python 側に対応なし。
- `weeklyEventCap`(15)・`EVENT_RATE`(0.12 vs weeklyEventRate)・抽選の候補選び方の一様性・同一週の二重抽選ガードは対象外（値の写し合わせのみ別途）。
- 週次の「本番までの週」は Python の stages 先頭と Swift の `nextStage` が同じ週を指す前提で、その算出（`_app_stages`／`upcomingStages`）自体は比べていない。

## §終盤40本（候補ブランチ claude/late-events-cand・2026-11-08 追記）
本体の2本の検査を、終盤イベント40本（E1〜E20＝6年目〜／N1〜N20＝11年目〜）も対象に広げた。検査だけを直し、`late_events_data.py`・`ChoiceEventLate.swift`・`GameSession.swift`・`sim_career.py` の中身（数値・条件）は無変更。

### 効果（`tools/check_event_parity.py`）
- Swift 側は `ChoiceEventLate.swift` の `lateChoices` を読み（効果＋お金 gate `$0.money >= N`）、`late_events_data.py` の表と選択肢ごとに照合。さらに `sim_career._late_apply`（方針＝体力50以上で A）を体力15値×所持金23値×能力配置2 で実行し、差分が Swift の「選べる選択肢」のどれかと一致するかを見た。
- 結果：**一致 120／不一致 0／読めない 0**（40本×選択肢2＝80件の表照合＋40本の実行照合）。終了コード0。

### 発火条件（`tools/check_event_trigger_parity.py`・`--late` で ChoiceEventLate.swift を差し替え可）
- Swift 側：`lateEventMinYear`（出る年）・`lateEventNeedsChampion`・`isWeeklyRandom` の `isLateEvent` 入り・`ChoiceEvent.swift` の default 節 `year >= minYear`・`GameSession.weeklyExtraGate`（N17〜N20）・`lateChoices` の gate を読み、Python 式に翻訳して評価。
- 「読めない」だった `wonLastYear`／`wonTwoYearsAgo`／`hasWonBefore` を評価できる変数に追加（`yearHistory` の定義どおり、前年・前々年に優勝なら過去優勝も真）。
- 週次抽選：年 {1,2,3,5,6,7,10,11,12}×他の状態 20万件で、全65種（既存25＋終盤40）の Python 候補判定（`_app_band`＋`LATE_POOL`＋`_late_pick` が選べる）と Swift（帯＋追加ゲート＋選択肢 gate）が全件一致。N17〜N20 は sim が初優勝でキャリアを閉じる＝優勝状態を作れないので、Python は常に「出ない」、Swift も優勝歴なしの状態では常に「出ない」で一致（意図どおり）。
- 優勝状態の網羅（Swift のみ）：(前年,前々年,過去優勝) = (F,F,T)→N20／(T,F,T)→N17／(F,T,T)→N18／(T,T,T)→N19／優勝歴なし→どれも出ない。各状態でちょうど1本＝排他で漏れなし。
- 結果：**一致 66／不一致 0／読めない 0**（既知1＝femaleCombo 節は従来どおり）。終了コード0。

### 検査の効き確認（わざとずらしたコピーで NG）
- 効果：`lateE03` A の fame 1→2 にすると、表照合と実行照合の2件で不一致（終了コード1）。
- 発火条件：終盤の出る年（11→10）と `lateN19` の条件（`&&`→`||`）を変えると、週次の不一致が38種分、優勝状態の網羅でも N18／N19 の二重該当を検出（終了コード1）。変更は確認後に全て元へ戻した（git 差分は検査2本と本書のみ）。

### 限界（この節）
- N17〜N20 の「優勝経験者」状態は Python に無いため、Python 対 Swift の突き合わせは優勝歴なしの状態のみ（優勝歴ありは Swift 内の網羅確認だけ）。
- 終盤イベントは各1回制（firedWeeklyEvents）・通算上限・抽選の一様性は対象外（本体と同じ）。
- 不一致は見つからなかったので何も直していない。
