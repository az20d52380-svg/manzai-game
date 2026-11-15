# 二度押し・同時タップ監査（2026-11-15・読み取りのみ）

対象：ManzaiGame/Sources 全体。GameSession を進める呼び出しが2回走るか。週メインの行動カード（pulledID／burstHold・監査F-10）は対象外。
結論：お金が2回減る・週が2つ進む・画面が2枚積まれる、といった重い二重実行は見つからなかった。GameSession 側の guard が効いている。残るのは「確認の二度押しが素通りする」「初回の導入が1場面飛ぶ」「イベントの返事が選ばなかった方になる」の中〜低。

## §1 指摘（6件）

### 1. 導入の回想の最後のカードを二度タップ → 初舞台（FirstStageView）を飛ばしてゲーム開始　【中・確信度 高】
- IntroFlow.swift:84-90（ReminiscencePlayer の onTapGesture）→ IntroFlow.swift:839-845（onComplete）。
- 1回目の onComplete で `markIntroSeen()` を先に呼ぶため、2回目の onComplete では `first = !hasSeenIntro` が false になり、`finish()` が走る＝初回なのに初舞台（.firstStage）を通らず GameSession が作られる。3回目で finish が重なれば GameSession が2つ作られる（後勝ち・実害は小）。
- 起きること：初回プレイだけ「初めてのツッコミ」の体験が欠ける。「とばす」＋カードのタップでも起きうる。
- 直し方：onComplete 冒頭に `guard stage == .reminiscence`（または `@State done`）を置く。`let first` の判定は guard の後に。

### 2. 選択肢イベントで2つの選択肢を続けて押す → 返事の文だけ選ばなかった方になる　【中・確信度 高】
- ChoiceEventOverlay.swift:296-304 `choose(_ id:)`。
- session.applyEventChoice は `choiceApplied` で2回目を無視する（GameSession.swift:755）ので効果は最初の1つだけ。しかし View 側 `choose` には guard が無く、2回目の押下で `chosenID` が上書きされ、返事の会話（afterChoice）が2つ目の選択肢のものになる（効果チップは before==after で空）。
- 起きること：A を押したのに B の返事が表示される（効果は A）。お金・週は二重にならない。二本指の同時タップで起きうる。
- 直し方：`choose` の先頭に `guard chosenID == nil else { return }`。

### 3. 「年末へ」タイルの確認（もう一度押す）が素早い二度押しで素通り　【中・確信度 高】
- WeekMainView.swift:1600-1611（yearEndTile）。
- 1回目で yearEndArmed=true、直後の2回目で即 `fastForwardToYearEnd()`＝残りの週を全部「完全休養」で送る（取り消せない・最大数十週）。間隔の下限が無い。
- 起きること：誤タップ防止の確認が、ダブルタップだと効かない（二重実行ではなく確認の素通り）。
- 直し方：armed を立てた時刻を持ち、0.4秒未満の2回目は無視（TournamentResultView:259 の nextArmed と同じ作り）。

### 4. オファー受諾の確認（もう一度押すと受ける）も同様に素通り　【低〜中・確信度 高】
- WeekMainView.swift:916-924（actionCard の acceptOffer / offerArmed）。
- ダブルタップで確認トーストを読まずにオファーを受けられる。受けた後は perform が pulledID で守られるので二重実行はしない。
- 直し方：#3 と同じ最短間隔。

### 5. 買い物（購入ボタン）の二度押し → 上限の無い品は2個買える　【低・確信度 中】
- ShopView.swift:188-193 `buy` ／ GameCore Item.swift:45 `buy`。
- 年上限・一度だけ・お金の guard はエンジン側にあるので上限品は2個目が弾かれる。上限の無い消耗品（栄養ドリンク等）はダブルタップで2個買える。「戻す」で1個ずつ戻せ、買う意思のある操作なので実害は小さい。
- 直し方（任意）：buy に 0.3秒のデバウンス。

### 6. 決勝演出（FinalsPresentationView）の送りを二度タップ → 審査員札・コメントが1枚飛ぶ　【低・確信度 中】
- FinalsPresentationView.swift:174,196,345-。`advance()` は 7人目の溜め（holdingSeventh）以外に連打 guard が無い。session は進まないが revealJudge や commentStep が2つ進み、演出が1拍飛ぶ。
- 直し方：advance に 0.25秒程度の最短間隔（または beat ごとの再生中フラグ）。

## §2 問題なしと確かめた主な所
GameSession 側の guard（二度目が無害）
- `decideTournament`（:348 .tournamentDecision の時だけ）・`choose`（:361 .freeAction の時だけ）・`advanceAuto`（:959 .gpRound/.gpRevival/.gpFinal の時だけ）。1回目で phase は weekDone→結果待ち（pendingResult）へ移るので2回目は無視。大会週が連続する日程は無く（Calendar.swift 確認）、見送りの二度押しで次の大会を飛ばす事もない。
- `acknowledgeResult`（:972 pendingResult != nil）＝結果画面の「次へ」・通過/優勝の祝い・山場最終ページ・FinalsPresentation の出口、すべて二度目は無害。
- `acknowledgeWin`（冪等）・`finishWatchingFinal`（:1009 guard）・`retireAfterWin`（:1153 guard）・`startNextYear`（:1162 finished guard）＝年末の「続ける／勇退」「◯年目を始める」。YoseYearTurnCurtainView は hasTriggeredStart でも守られる。beginYearTurn の二度呼びは同値の上書きのみ。
- `applyEventChoice`（:755 choiceApplied）・`dismissChoiceEvent`（冪等）・`fastForwardToYearEnd`（ループ内は各 guard 経由）。
- `learnSkill`（canLearn）・`allocate`（taps を空にしてから）・AbilityUpView の finishConfirm（confirmFinished）。
- `retireNeta`／`recallNeta`（存在しない id は何もしない）・`moveRoom`（同じ部屋は無料の冪等）・`selectNeta` 系（代入のみ）。
画面側のフラグ
- 大会の入口（出場/見送り）・「本番へ」は session の phase guard で無害。
- GachaView.run（busy を同期で立てる＋.disabled(busy)）・天井/かけら交換は state 側で枠を減らす。
- IntroFlow：タイトル・コンビ形式（picked）・名前入力（decided）・FirstStageView 第1週へ（finished）。FinalsBroadcastIntro（done）・RentStatement（onDone は `rent = nil` のみ）。
- TournamentResultView の「次へ」は初回 0.8 秒の nextArmed でも守られる。climax の送りは `climaxIndex = i + 1`（i は描画時の値）で冪等。
- EndingViews の「もう一度」二度押しは returnToTitle が冪等。
- WeekMainView：tapOrQueue で溜まった複数タップは、1つ目の perform が pulledID を同期で立てるので2つ目は guard で捨てられる。
- Settings の解散は確認1段を挟み、abandonRun は冪等。

## 直しの優先
#1（導入の飛び）と #2（返事の取り違え）は各1行の guard。次に #3・#4（確認の最短間隔）。#5・#6 は任意。
