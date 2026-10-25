# コード点検 2026-10-26（d8d2063 より後の差分）

範囲：`git diff d8d2063..HEAD -- ManzaiGame/Sources GameCore/Sources`（24ファイル・約731行追加）。読むだけ。25c/d/e で対応済みの物は重ねていない。
結論：**重 0／中 0／低 2**。本番で落ちる・状態が壊れる・保存が漏れる物は見つからず。

## 見たこと（問題なし）
- **DEBUG の外に漏れた処理**：IntroFlow の MZ_KIND／MZ_UI=intro_name、RootView の MZ_STOPWEEK／MZ_YEARS、GameSession.debugRunnerState、WeekMainView の netapick は、すべて `#if DEBUG` の中。
- **男女の形（Names.kind）の経路**：新規＝形を選ぶ画面で `Names.setKind`、続きから＝`GameSession(restoring:)` が `Names.set`＋`setKind`、解散・やめる後＝`GameSession()` で男に戻し→次の周の形選択で上書き、ソークの再開＝`s.comboKind` を渡す。RootView.init で生成する session は1回だけなので、画面の再描画で形が戻ることもない。前の周の形が残る経路は無し。
- **WeekRunner の二重押し防止（L37）**：`currentPhase()` は副作用なし・RNG なし。begin→各段の `section/acted/pendingSpec/pendingAuto` の組み合わせを突き合わせ、正しい呼び順では早期 return に入らない。`weekClosed` は旧セーブで nil→false で、旧セーブの療養週（acted=false・section=.end）が freeAction と判定されても、`sameStep` が weekDone を置き換えないので害なし。GameSession 側の guard（decideTournament／choose／advanceAuto）も呼び元（Views・自走・ソーク）は常に該当の段でしか呼んでいない。
- **中断セーブの復元**：`gpStage` の丸め＋`pendingAuto=.round` を外す処理は、UI 側の phase が `.gpRound` のまま残っても `resolveAuto` が `proceed()` に落ちて週が進む。
- **L52（夜逃げ・解散週の記録）**：`yearHistory.last?.year != runner.year` の中なので再入しても二重に積まない。賞金は `isStage` だけ足す。
- **台詞プール増補**：`stageNearWeak/Plain` の〈大会〉〈弱点〉の差し込みは、Weak の全行に〈弱点〉、両方の全行に〈大会〉があり、「あと二週」「再来週」は `weeksLeft == 2` の条件と合う。年末独白の新規行は「去年」を含む行が1年目で外れる（leap）／stall は1年目に別プールで安全。
- **表示と実データ**：GP 本番前の「体力が尽きた状態で出る」は大会入口カードと同じ `stamina <= 0`。WeekHint は借金の行が先頭のまま（撮影の週でも出る）。

## 所見

### 低1　観戦の出来事ログが二重に積める（既存・今回の差分外だが「二重実行」に当たる）
- GameSession.swift:991 `finishWatchingFinal(winner:)` に `didWatchFinal` の guard が無い。
- 手順：決勝を客席から観る画面（観客版決勝）で、終了ボタンを素早く2回押す（または終了の通知が2回届く）→ 出来事ログに「優勝「◯◯」（客席から）」が2行、年末の「観戦」札と戦績の行も重なる。`saveNow` も2回走る。
- 直し案：先頭に `guard watchingFinal else { return }`（`checkSpectatorFinal` で立てた旗をそのまま使える）。表示・GameCore には触れない。

### 低2　復元した大会の入口で、config から大会が消えていると画面とエンジンがずれる（極小）
- GameSession.swift:261 `if let now = restoredRunner.restoredPhase, Self.sameStep(save.phase, now) …`。WeekRunner.swift:660 付近で保留中の大会は config から取り直す（無ければ `pendingSpec = nil`）。このとき `currentPhase()` は nil（section=.gp）で、`restoredPhase` が nil → `save.phase`（古い `.tournamentDecision(spec)`）がそのまま画面に出る。
- 手順：大会のある週で中断セーブ → アプリ更新でその週の大会が config から無くなる → 続きから再開 → 古い大会名の出場カードが出て「出る」を押しても `resolveTournament` は `pendingSpec == nil` で何も払わず先へ進む（エントリー費も出場結果も無いまま）。
- 現行の config では起きない（大会カレンダーを減らす更新をした時だけ）。直し案：`restoredPhase` が nil で `save.phase` が `.tournamentDecision` の時は `runner.begin()` ではなく、その週を「大会なしの自由週」から続けるか、`phase` を `.freeAction` 相当に引き直す。更新で大会を消す予定が無ければ対応不要。
