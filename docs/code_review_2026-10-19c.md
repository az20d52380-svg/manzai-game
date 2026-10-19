# コード点検 2026-10-19c（GameSession.swift・WeekMainView.swift の通読・2回目）

**件数：4件（確度 高 1・中 3）。** 19 と 19b に載っている物は除いた。コードは変えていない。

**節構成**：§1 確度 高／§2 確度 中／§3 見たが問題なかった所

## §1 確度 高

1. **イベントの札で選んだ後にアプリを落とすと、再起動で同じ札が選び直せて、効果が二重にかかる**
   - GameSession.swift:695-728（`applyEventChoice` は効果を適用して `saveNow()` するが `pendingChoiceEvent` を残す）／:730-733（`dismissChoiceEvent` が閉じた状態を保存）／:259（復元で `pendingChoiceEvent` をそのまま戻す）
   - 手順：イベントの札で選択肢を押す（所持金・体力・相性などの効果が `runner` に入り、`saveNow` で「効果済み＋保留あり」が保存される）→ 返事の会話を読み終えて「閉じる」を押す前にアプリを強制終了 → 再起動すると保留が復元され、同じ札が最初から出て、もう一度選べる（`applyInviteGo` の−5,000円・凍結・能力加算などが二重）。`dismissChoiceEvent` のコメントは「選択済みイベントが再表示されないように」と書いているが、選んだ直後の保存では守れていない。
   - 直し案：`applyEventChoice` で「選択済み」の印（例 `private var eventChoiceApplied = true`）を立て、`saveNow` では印がある間 `pendingChoiceEvent: nil` で保存する（`dismissChoiceEvent` と新イベント発火で印を下ろす）。SaveData に足す必要はない。
   - 確度：高（保存内容を読んで確認。起きる頻度は低いが、起きると効果が戻らない）。

## §2 確度 中

2. **「次へ」の二重呼びで、週が二つ進む（`acknowledgeResult`・`advanceAuto`・`decideTournament` に位相のガードが無い）**
   - GameSession.swift:891-896（`acknowledgeResult`：`pendingResult` が nil でも `runner.begin()` を呼ぶ。`begin()` は `week += 1`）／:884-888（`advanceAuto`）／:296-302（`decideTournament`）。呼び手は TournamentResultView.swift:165・272・556（全画面タップの `isLast`）、FinalsPresentationView.swift:423
   - 手順：結果画面の最後のページ（全画面が `onTapGesture`）を素早く2回タップ。1回目で `pendingResult = nil`＋次週へ。2回目が描画の切り替え前に届くと、もう一度 `begin()` が走り、自由週を1つ飛ばす（行動も生活費の判定もなしで週が進む）。通常は切り替えが間に合うので頻度は低い。
   - 直し案：`acknowledgeResult` の冒頭に `guard pendingResult != nil else { return }`。`advanceAuto` は `guard runner` 側の `pendingAuto` が立っている位相（`.gpRound/.gpRevival/.gpFinal`）のときだけ、`decideTournament` は `.tournamentDecision` のときだけ進める。
   - 確度：中（コードの流れは確実。実機での頻度は未確認）。

3. **旧セーブから2年目以降を再開すると、そのキャリアの間ずっと年末の「育ったもの」が出ない**
   - GameSession.swift:242（復元で `hasYearStart = false`）／:972-1004（`startNextYear` は `yearStartState = r.state` を入れるが `hasYearStart` を戻さない）／YearResultView.swift:31・199（`hasYearStart` が false の間は差分を出さない）
   - 手順：`yearStartState` を持たない旧セーブで year≥2 を復元 → その年を終えて次の年へ進む → 新しい年の `yearStartState` は正しく取れているのに `hasYearStart` が false のまま → 以後の年末のはしごとレーダーの4月線が出ない（再起動するまで）。保存し直した後に再起動すれば直る。
   - 直し案：`startNextYear` の `yearStartState = r.state` の次の行に `hasYearStart = true`。
   - 確度：中（旧セーブの経路だけで起きる）。

4. **体調ダウンの知らせ待ち（`injuryNoticeWeeks`）がセーブに入っていない**
   - GameSession.swift:51（`private(set) var injuryNoticeWeeks`）／:1163（`pump` で立てる）／SaveData（:1035-1073）に項目なし／WeekMainView.swift:1388（表示と `clearInjuryNotice`）
   - 手順：体調ダウンが起きた週の直後（獲得の一拍のあと約2秒で知らせが出る前）にアプリを終了 → 再起動すると復元では 0 に戻り、「体を壊した。その間のバイト代は入らない」の知らせが一度も出ない。療養の週は日程表に「回」で残るので気づけはするが、説明が飛ぶ。
   - 直し案：SaveData に `var injuryNoticeWeeks: Int?` を足して保存・復元する（Optional なので旧セーブも読める）。
   - 確度：中（実害は説明が一度出ないだけ）。

## §3 見たが問題なかった所

- DEBUG の漏れ：GameSession.swift の `MZ_*` 環境変数読み（195・200・511・1100）と debug 関数群（1232-1518・1530-1669）、WeekMainView.swift の `debugWeekHook`（87-119）・`MZ_RANKUP`（1287）は、すべて `#if DEBUG` で閉じている。`debug*` の呼び手も本編側にない。
- 年またぎ：`startNextYear` は `lastEventRollWeek`・`lastBanterRollWeek`・`pendingChoiceEvent`・`weekBanter`・`justPassed/Lost` を戻している。連敗数・一発化フラグ・`firedWeeklyEvents`・`weeklyEventFiredCount` はキャリア通算で持ち越す設計（コメントどおり）。連打は `guard finished, !careerOver` で止まる。
- 保留イベントのまま次へ進む経路：`choose` と各カードは `pendingChoiceEvent == nil` を見て止まり、`fastForwardToYearEnd` は保留を先に閉じてから進む（0050 の予告は未発火に戻す）。観客版決勝は `checkSpectatorFinal` が先に立つが、戻れば保留が出る。
- 範囲外：`banterBox` は `isEmpty` を先に除く。`offerPick` は `offerChoices.indices.contains` と `runner.chooseOffer` の範囲チェックで守られている。`upcomingStages` の `gpRoundsPassed..<count` は passed が count を超えない限り安全。
- Task：`perform` の `beatTask` は取り消されても `choose` を一度だけ走らせる設計で、Beat1 中は全面のタップ受けが他のカードを止める。`.task(id: session.week)` 系は `defer` で `burstHold` を必ず下ろす。`presentRent` の取り消し漏れは 19b §1-1 に既出。
- 週送りの二重実行（カード側）：`actionCard` の `run` は `pulledID == nil`・`!burstHold`・保留なしを見る。`tapOrQueue` の予約実行も `run` の中で再判定される。
