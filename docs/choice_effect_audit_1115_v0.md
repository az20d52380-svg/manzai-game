# 選択肢イベントの「札・文」と実際の効果の食い違い点検（11/15・読むだけ）

結論：**効果が食い違うバグは無い**（選択肢の文に数字が出るのは §102 の「5,000円」だけで実際の -5,000 と一致。効果チップは適用前後の差から作る＝札と実際の取り違えが構造上起きない）。指摘は6件＝中1・低5。二重適用・取りこぼしの経路は無し。
最も重い1件：**効果チップが最大3枚で切れ、所持金の増減が落ちる選択肢が新たに2つ（0057 年末A・§102 先輩の誘い A の「発想付き」半分）**。既出の 0017C／0014B／0022A と同じ原因。
調べた所：`GameCore/ChoiceEvent.swift`（choices・weeklyFireable）・`ChoiceEventEffect.swift`／`ManzaiGame/Sources/ChoiceEventOverlay.swift`（showEffects・footer・choose）・`ChoiceEventData.swift`（choiceLabels・hiddenEffectNote）／`GameSession.swift`（applyEventChoice 777–814・availableEventChoices 820・evaluateChoiceEventFire 591・pump 1403・保存 1346）。

既出の照合：`docs/choice_gate_audit_1115_v0.md`（押せる選択肢0・§102 は金欠でも押せる）／`docs/choice_event_inventory_v0.md` 共通の仕組み・#2〜#8（チップ3枚切れ・0016B/0022A の予告なし）／`docs/save_restore_audit_1115_v0.md` #1（inviteWaiting 非保存）／`docs/decision_brief_2026-11-08.md` B-9／`docs/AUTOPILOT.md` 468 と「イベント効果 62 一致」（tools の効果表と GameCore の表の突き合わせ）。

## §1 指摘

| # | 重さ | 場所 | 起きる手順 | 直し方の案 |
|---|---|---|---|---|
| 1 | 中 | `ChoiceEventOverlay.swift:322`（`.prefix(3)`）／所持金は並びの最後（314–319） | 0057 年末のライブ A（センス+1・知名度+1・体力-10・所持金-5000）→チップは「センス↑・知名度↑・体力↓」で**所持金が出ない**。§102 先輩の誘い A で発想が付く回（半分）も ups=発想・メンタル／downs=体力・所持金で所持金が落ちる（選択肢の文は「5,000円」と書くのに結果に出ない）。0017C（所持金-1,500）・0014B（-800）・0022A（体力-5）も同じ（既出 inventory #6）。数字は出さない作りなので「+0」は出ない | ① 上限を4〜5枚に広げる（札の幅は目視要）② 3枚に絞るなら所持金・体力を先頭（意味が大きい）。既出 #6 に 0057A・§102A を足す |
| 2 | 低 | `ChoiceEventOverlay.swift:324`（`all.append((note, false, …))`）・323（音）／`ChoiceEventData.swift:36-44` | 0016 書けた一本 B「来週のネタ合わせが捗りそう」・0050 向き合う「二人の空気が少しほどけた」は良い知らせなのに `up:false` ＝和紙色（減りの札の見た目）。伸びが他に無い時は音も減りの `.pop`。実効果は正しい | ① note に up を持たせ、良い方（0016B・0050A）だけ濃色・`.grain` ② 今のまま（文が前向きなので読める）。見た目だけの判断 |
| 3 | 低 | `ChoiceEventOverlay.swift:50`（`isFlavor = availableEventChoices().isEmpty`）→ 78・126 | 選んだ後の支払いで残りの gate が全部落ちると `isFlavor` が真に変わる：返事の会話の薄表示（78）が全部濃くなる／絵の高さ（126）が変わる（返事を読み終えた「とじる」時に、まだ買える金があれば 262・無ければ 320）。0057 B（-1,500）など所持金ぎりぎりで起きる。効果・遷移には影響なし（288 は `chosenID == nil` で守られている） | 「選択肢なし」の判定を `text.choiceLabels.isEmpty`（静的）にする。見た目のみ |
| 4 | 低 | `ChoiceEventTable`（体力 -10〜-15 の選択肢に体力の gate なし） | 体力が低い（例 3）のに 0046 棚卸し A（体力-15）・0014A・0042A 等を押せる→体力は 0 で止まり、実際の減りは想定より小さい。チップは「体力↓」で嘘ではない。発火側の体力ガードは 0018（15+）・0042（40+）・0051（40+）だけ | 判断：① 今のまま（床0が救済になる）② 体力の足りない選択肢を消す（所持金 gate と同じ作り）。害は小さい |
| 5 | 低 | `ChoiceEventData.swift:341・363`（`"先輩と飲みに行く（5,000円）"` 直書き）／`GameConfig.swift:256`（`inviteMoney = 5_000`） | 札の金額が設定値の複製。`inviteMoney` を調整すると文と実際がずれる（今は一致） | ラベルを `config.inviteMoney` で組む（または run_checks の同期項目に足す）。今は不具合なし |
| 6 | 低 | `GameSession.swift:437-438`（tickNetaBoost）／0016B の文「来週」 | 0016 B のブーストは `netaBoostWeeks = 2`＝**設定週を含む**2週。週頭にイベントが出るので「この週＋来週」で、この週にネタ合わせ以外を選ぶと実質1週しか乗らない。文は「来週」としか言わない（既出 inventory #3 の延長） | ① 文を「ここ数週」にする ② 週送り後に付ける。数値は効果の変更＝オーナー判断 |

## §2 観点別の結論

1. **札に出る効果と実際の効果の一致**：choiceLabels に金額以外の効果は書かれない。チップは `before`／`after` の差（ChoiceEventOverlay 312–327）＝適用した結果そのもの。`applyEventChoice`（GameSession 777）は `choice.effects` を `runner.applyEventEffects` で適用し、`weekendInvite` A だけ `applyInviteGo`（効果表は空＝二重なし）。数字に出ない効果は一言の札で添えている：`growthCeiling`（0023 廃止イベント）／`netaBoost`（0016B）／`preoccupy`（0022A・GameSession 385・441 と一致）／`rift`（0050A）。`compatFreeze` は使われていない。札にあって効かない効果は見つからず。
2. **選べる条件と見た目**：gate 付き（所持金）の選択肢は**押せない見た目ではなく表示から消える**作り（footer＝`availableEventChoices()`）。「押せない選択肢が押せる見た目」も逆も無い。タップ時にも `applyEventChoice` が gate を再判定（780）。gate が無く金欠で負債になる選択肢は既出（choice_gate_audit #1・B-9：§102 A／0011 A -4,000／0014 B -800／0048 A -5,000）。
3. **結果の札の丸め・上限**：チップは矢印のみで数字なし。閾値 0.001（314–317）で「+0」は出ない。上限・下限（能力 cap・体力/知名度 0..100・相性 compatCap）で伸びが0になった時はチップ自体が出ない＝実際と一致。数字のずれは起きない。切れる経路は #1。
4. **重なり・中断復元**：`applyEventChoice` は `choiceApplied` で二度押しを止め（778）、オーバーレイ側も `chosenID` で止める（301）。適用直後の `saveNow()` は `pendingChoiceEvent: choiceApplied ? nil : …`（1346）＝**適用後に復元しても再適用されない**（失うのは返事の会話だけ）。適用前に中断すれば保留のまま復元され、発火は `pendingChoiceEvent == nil` ガード（592）で二重に立たない。週次抽選は `lastEventRollWeek` と `firedWeeklyEvents` で1週1回。同じ週に2つ重なる経路は無く（確定発火が優先・誘いは次の空き週へ持ち越し）、持ち越し中の誘いが保存されないのは既出（save_restore_audit #1）。保留を適用せず捨てる経路は `fastForwardToYearEnd`（1009）と DEBUG の soak（RootView 481）だけ。前者はオーバーレイ表示中は押せない（WeekMainView 171 の hit testing）ので実害なし。

## §3 イベントごと（問題なしも）

| 番号 | イベント | 判定 |
|---|---|---|
| 0017 | justLostRehearsal | A/B 問題なし。C は4変化で所持金チップが切れる（#1 既出） |
| 0019 | styleTalk | 問題なし（A の相性-2 は既出 inventory #8） |
| 0018 | justPassedFork | 問題なし（A の体力-15 は発火側 15+ ガード済み） |
| 0010 | preTournamentEve | 問題なし |
| 0021 | tsuukaBreak | 問題なし |
| 0020 | earlyFormality | 問題なし |
| 0011 | brokeDrinkingInvite | 問題なし（A -4,000 は gate なし＝既出 B-9 型） |
| §102 | weekendInvite | A の発想付き回で所持金チップが切れる（#1）／文の「5,000円」は一致（#5）／金欠でも押せる（既出） |
| 0013 | senpaiMeishi | 問題なし |
| 0015 | peerFoldedChair | 問題なし |
| 0014 | lastTrainReview | B の所持金-800 チップが切れる（#1 既出） |
| 0023 | regularEmployment | 廃止（抽選外）。A の growthCeiling は note 付き |
| 0012 | taniguchiShortJob | 問題なし（A +15万は clamp 無し・体力-15 は床0＝#4） |
| 0016 | wroteOneTonight | B の note が減り札の見た目（#2）・「来週」（#6） |
| 0022 | photoShootOffer | A は4変化で体力-5 が切れる（既出）。稽古ロックは同じ週に効く＝note と一致 |
| 0041〜0049 | kouhaiInvite／senpaiAllNight／stageCrewChairs／writerPostcards／doukiJointLive／baitoInventory／homecomingCall／regularFanOranges／officeTicketQuota | 問題なし（3変化以内・gate は所持金のみ・0048 A -5,000 は gate なしで既出） |
| 0051〜0057 | summerFestivalGig／doukiOnTV／theaterRenovation／classmateInAudience／partnerFever／lostNotebook／yearEndLive | 0057 A のみ所持金チップが切れる（#1）。他は問題なし |
| 0050 | riftWarning | A は note が減り札の見た目（#2）。実効果（rift-30・体力-10）は一致 |
| 0025・0027・0028・0029 | lineupTop／greenroomSilentTen／namelessReservationSlip／luckyThirdLine | 選択肢なし・効果なし（仕様どおり） |
