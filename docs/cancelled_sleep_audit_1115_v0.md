# 取り消された sleep の後の副作用 点検（2026-11-15・読むだけ・コード未変更）

対象：ManzaiGame/Sources 全体の `try? await (MZSpeed|Task).sleep` 115箇所（DEBUG／MZ_* 目視フック・投げっぱなし `Task {}` は除外）。
結果：**中 0件／低 6件**。363〜365 と同じ「週が替わる・消えると次の週の物を壊す」型の実害は見つからなかった。

## §1 指摘

| # | 場所 | 囲み | 取り消しの手順 | 取り消し後に余計に走る処理 | 重さ | 確信度 |
|---|---|---|---|---|---|---|
| 1 | StageFrame.swift:301/304（StageCeremony.run）→ TournamentResultView.swift:264 の onDone | `.task { await run() }`（guard は `done` だけ・`Task.isCancelled` なし） | 開演の儀（初回約1.0秒／2回目以降約0.4秒）の間に、親（結果画面）が消える。.task が取り消され、sleep が即戻る | `guard !done` を通って `finish()` → `Sound.duck(1)`・`onDone()`。結果画面では `onDone` が `ceremonyDone = true; beginReveal()`。onDisappear の `revealTask?.cancel()` は revealTask がまだ nil で空振りするため、**消えた画面の裏で開示列が新規に走る**（BGM tension・cheerMid・drumroll・太鼓・拍手。誰も cancel しない）。FinalsPresentationView:210 は `ceremonyDone = true` だけなので無害 | 低〜中（音が余計に鳴る）。実際に起きるのは儀の最中に結果画面が外から消える稀な場合（タップは儀を done にするので別） | 中 |
| 2 | YearResultView.swift:589/592（数字のカウントアップ） | `.task(id: value)` | value が変わる（または画面が消える）と取り消される。以降の sleep は即戻り、20ステップを一瞬で回し切る | 旧 value へ `shown = value` を代入（新タスクの数え上げと一瞬ぶつかる見た目だけ） | 低（見た目のみ） | 低 |
| 3 | FinalsPresentationView.swift:589（runLot の心拍の拍） | `.task(id: ceremonyDone)` | くじの最中に画面を送る／消える | sleep 直後の `Haptics.tick()` が1回余計に鳴る（次の周回は guard で止まる） | 低 | 高 |
| 4 | FinalsPresentationView.swift:279（扉の拍の頭 350ms） | `.task(id: autoKey)` | 350ms の間にタップで先の場面へ進む | `withAnimation { doorsOpen = true }` が走る（直後の Haptics は isCancelled で守ってある）。フラグのみ | 低 | 高 |
| 5 | StageViews.swift:248／AbilityUpView.swift:89（初回ヒント 450ms） | `.task` | 450ms 以内に画面を離れる | `hint = ...` を立てる（消えた View の状態のみ＝実害なし） | 低（ほぼ無害） | 高 |
| 6 | Design/YoseRankUpOverlay.swift:287–320（runSequence） | `.task`。守りは `isDismissed` だけで Task.isCancelled なし | 取り消されると sleep が即戻り、haptic（heavy・success）→ `dismissImmediately()`→ onDismiss まで一気に走る | 触覚2回＋onDismiss。**ただし使われているのは DEBUG の YoseFXPreview（MZ_FX）だけ＝製品では未使用** | 低（死んだ経路） | 高 |

付記（直すなら）：#1 は StageCeremony.run の各 sleep の後に `guard !Task.isCancelled, !done` を足す（取り消し＝finish しない）のが最小。ただし「画面が消えたのに onDone が必要」な親があるかは要確認（今の呼び元2つでは不要）。#3 #4 は `if Task.isCancelled { return }` を1行。

## §2 問題なしと確かめた主な所

- **isCancelled で守られている**：QualifierNoticeView 218/250/255（ループ頭と成功音の前）・RentStatement 129〜141（全段）・FinalistAnnounceView.pause（`Task.isCancelled` で抜ける）・FinalsBroadcastIntro run（全段 guard）と 601〜608・TournamentResultView runReveal/runFanVoices/pause・FirstStageView.wait（false を返す）・WeekMainView の 週の説明(2.2s)／gainsVisible／weekStamp／presentRent の入口／toast（do-catch）・FinalsPresentationView 282〜291／performBeat 623・YoseMilestoneFX.run（YosePassCelebration・BigSuccessCutIn とも Task.isCancelled を見る）・YoseGameParts:267／YoseYearTurnCurtain:411（do-catch で false 返し）。
- **取り消しが「スキップ」の意図**：WeekMainView:857 beatTask（Beat1 中のタップで `cancel()`＝待ちを飛ばして `session.choose` を必ず実行したい作り。取り消しで握りつぶす今の挙動が正しい）。TournamentResultView finishReveal の `revealTask.cancel()` は runReveal 側が各段で isCancelled を見て抜ける。
- **取り消しが画面を離れる時だけ・効果が見た目フラグのみ**：Design/YoseChampionCelebrationView 795/900/1008・FinalsPresentationView 1453/1488 の `frozen = true`（描画の凍結）・YearResultView/SettingsView の DEBUG 目視フック。
- **投げっぱなし Task（誰も cancel しない＝対象外）**：WeekMainView 257/264/266/324/917/1291/1391/1508/1604・FinalsPresentationView 363/382(voteTailTask は onDisappear で cancel され、ループ条件 `!Task.isCancelled` で守り済み)・TournamentResultView:260・AbilityUpView 296/297/463/467・Juice.swift 107/163/185/282・NetaStage:48・ChoiceEventOverlay 94/339・S6bView:135 など。ここは画面が消えても最後まで走るが、cancel 起因ではない（別観点：消えた後に走る副作用が要るなら別監査）。
- **DEBUG／MZ_* 内**：RootView 242/474-、WeekMainView 108-114、QualifierNoticeView 212-213、SettingsView 35/110、AbilityUpView 76/94、YearResultView 47、NetaSelectionView 57、YoseFXPreview 全部。
- QualifierNoticeView:232（チャットの msgs=1）：吹き出しは msgs>=1 で出るボタンの前提なので、pickOpen との競合は起きない。finish() で取り消された後に msgs=1 が立つだけ（見た目のみ）。
