# 中断セーブ：保存されない状態による食い違いの点検（v0・11/15）

読むだけの点検（コード・テスト・シミュレータは触っていない）。対象＝GameSession（saveNow／SaveData／init(restoring:)）、GameState・WeekRunnerSnapshot（合成 Codable＝全フィールド保存）、画面の @State（WeekMainView 他）。
既知（再掲しない）：AUTOPILOT 230・231（didRecordChampion／旧セーブの10年）。結論：**落ちる・二重に数える・フェーズが食い違う類は見つからなかった。見つかったのは低が6件（うち状態の値に効くのは1件）。**

## §1 指摘

### 1. 【低・状態に効く唯一】週末の誘い（weekendInvite）の「発想+0.5」が、再開後の「行く」で付かない
- プロパティ：`inviteIdea`（GameSession.swift:108。private・SaveData に無い）。同時に `inviteWaiting`（:107）も保存されない。
- 設定箇所：pump の weekDone で `if let idea = runner.pendingInvite { inviteWaiting = true; inviteIdea = idea }`（:1373）。使用：applyEventChoice の `runner.applyInviteGo(idea: inviteIdea)`（:760）。
- 手順：先輩の誘いの札（weekendInvite）が出た週メインで、選ぶ前にアプリを閉じる→再開。pendingChoiceEvent は保存されるので札は出し直される。
- 再開後：`inviteIdea` が既定の false に戻る＝本来「発想付き」の誘い（config.inviteIdeaP の確率）でも「行く」で発想+0.5 が付かない（所持金-5,000・体力・メンタルは同じ）。落ちない・二重にならない。本来の乱数の結果と食い違うだけ。
- 重さ：低（0.5点・誘いの札で閉じた時だけ）　確信度：高
- 既出：no（inviteWaiting の「落とすと流れる」はコメントで許容済み＝:106。inviteIdea 側は未指摘）
- 最小の直し：保存に足さず**復元時に導出**できる。`GameEngine.rollInvite(seed:year:week:config:)`（GameEngine.swift:315）は seed/year/week だけの純関数。復元 init で `save.pendingChoiceEvent == .weekendInvite` なら `inviteIdea = GameEngine.rollInvite(seed: runner.inviteSeed, year: runner.year, week: runner.week - 1, config: cfg) ?? false`（誘いは週 N の締めで引かれ N+1 の頭に出る）。SaveData 不変＝旧セーブ・golden に影響なし（UI層のみ・乱数非消費）。
- 補足（inviteWaiting）：保存されないのは「別の確定イベントに譲られて次の自由週へ持ち越し中」の誘いだけ（通常は weekDone と同じ pump 内で即出る）。その週に閉じると誘いが消える。許容済みの軽い誘い。直すなら同じく導出は不可（持ち越し中かが分からない）＝保存に Optional で足す（旧セーブ nil＝なし）。やらなくてよい。

### 2. 【低】年初の知らせ2種（若手の大会は今年が最後／ネタの飽き）が、中断→再開で同じ年にもう一度出る
- プロパティ：`youthNoticeYear`・`tiredNoticeYear`（WeekMainView.swift:37-38・@State）。
- 設定箇所：maybeShowLastYouthNotice（:1518）・maybeShowTiredNotice（:1533）。条件は `session.week <= 1` かつ「出した年 != 今年」。onAppear（:273）が 0.7 秒後に毎回判定。
- 手順：年が替わった直後（第1週）に一度知らせを見る（または見ないまま）→アプリを閉じる（年の切れ目で閉じるのは自然）→再開。復元は第1週で始まり、@State が 0 に戻るので、同じ年の第1週にもう一度 toast が出る。
- 再開後：toast が2回目（谷口「若手限定の大会に出られるのは、今年が最後だ」／『◯◯』は客に見飽きられてきた…）。状態は変わらない。
- 重さ：低　確信度：高（onAppear の判定は読んだ）
- 既出：一部。docs/onappear_audit_1115_v0.md §4 は「WeekMainView の作り直し」で再表示、と書いているが、**アプリを閉じての再開（@State が必ず0に戻る）は書かれていない**＝こちらのほうが現行カレンダーでも必ず起きる。同 §4 の直し案「GameSession 側へ移す」はこの再開にも効く。
- 最小の直し：「知らせ済みの年」を GameSession のメモリ変数にするだけだと再開で消える＝保存が要る。SaveData に `noticeYear: Int?` 等を Optional で1つ足す（旧セーブ nil＝未表示＝今と同じ）。golden 無関係（UI層）。保存を増やしたくなければ、第1週の知らせを「復元直後は出さない」（`session.isRestored && week <= 1` で skip）でも足りる（見落とす側に倒れる）。

### 3. 【低】再開直後の文の選び直し：同じ場面の台詞・観客の声が閉じる前と違う文になり、使用済みの記録も1つ余分に進む
- プロパティ：`stablePicks`（GameSession.swift:115）・`fanVoiceCache`（:119）。@ObservationIgnored・SaveData に無い（usedPicks・usedFanLines・shownOnce は保存済み）。
- 手順：台詞や観客の声が出ている画面（大会結果・週メインの一言など）で閉じる→再開。
- 再開後：同じ key でも記憶が空なので `pickIndex`／`fanVoices` が新しく選び直す。usedPicks には前の番号が入っているので、**別の文**が出る（見ていた文が変わる）。さらに使用済み表に1つ余分に積まれ、プールが少し早く一巡する。`firstShow`（固定の一文）は tag を shownOnce に保存しているので影響なし（問題なし側）。
- 重さ：低（見た目の入れ替わりのみ。落ちない・数え違いなし）　確信度：中（pickIndex を読んだ。実機で文が変わる所は未確認）
- 既出：no
- 最小の直し：何もしない（許容）。直すなら stablePicks／fanVoiceCache を保存（[String:(Int,Int)] を Optional で SaveData に足す）。復元直後の1回目の描画だけの話で、費用対効果は低い。

### 4. 【低】直前の行動・大会の「差分の札」が再開で空になる（大会結果の「知名度 ↑+n」札と経験点の行・生活費の支払い画面）
- プロパティ：`lastResultFameDelta`・`lastResultExpDelta`（GameSession.swift:44-46）・`lastDeltaWeek`（:55・復元は -1）・`lastLivingPaid`・`lastMoneyDelta`・`lastAction`/`lastGains` 系・`justOroshiNeta`（:70）。復元 init のコメント（:343）どおり意図的に「復元しない」。
- 手順：大会結果画面（pendingResult）で閉じて再開／生活費を払った週の末に支払い画面が出ている間に閉じて再開。
- 再開後：結果画面の「知名度 ↑+n」札（TournamentResultView.swift:516,534）と経験点の行（:551）が出ない／支払い画面（presentRent・WeekMainView.swift:1282）は `lastDeltaWeek == week` を満たさず出ない（払った事実は所持金に反映済み＝食い違いなし）。ネタおろしの一言（justOroshiNeta）も消える。
- 重さ：低（表示の欠け・状態は正しい）　確信度：高
- 既出：no（復元しない方針はコードのコメントで明記。結果画面への影響を点検した記録は見当たらない）
- 最小の直し：許容でよい。直すなら fame/exp の差分を SaveData に Optional で2つ足す（旧セーブ nil＝今と同じ）。支払い画面は出し直さない（二度払いに見えるため）が無難。

### 5. 【低・クラッシュ時のみ】体調ダウンの知らせの「見せ済み」が、保存より先にメモリだけで落ちる
- プロパティ：`injuryNoticeWeeks`（GameSession.swift:59）。`clearInjuryNotice()`（:64）は `= 0` だけで saveNow を呼ばない（markDebtWarned・markRiftHintShown は保存する）。
- 手順：知らせの modal を閉じてから、何も行動しないままアプリが異常終了（クラッシュ・電池切れ）。通常のバックグラウンド化は scenePhase(.background) の saveNow（RootView.swift:352）が 0 を保存するので問題なし。
- 再開後：保存側が N のままなので、体調ダウンの知らせがもう一度出る。
- 重さ：低　確信度：中
- 既出：no
- 最小の直し：`clearInjuryNotice()` の末尾に `saveNow()`（markDebtWarned と同じ型）。SaveData 不変・golden 無関係。

### 6. 【低・既出】`writeNewNeta`（「新しく書く」の指定）が再開で勝負ネタの磨きに戻る
- GameSession.swift:63。`beginNewWrite()`（:870）は saveNow するが writeNewNeta 自体は保存しない（writeNetaID=nil だけ保存）。
- 既出：docs/code_review_2026-10-25.md §7(b)「害は小さい」。補足：画面（WeekMainView.swift:708）は session.writeNewNeta を読むので再開後は表示も一緒に戻る＝食い違わない。再掲のみ。

### 7. 【既出・参照のみ】キャリアの区切りの年末（優勝の勇退・夜逃げ・解散・最終年）で、エンディングを見る前にセーブが消える
- saveNow の `finished && careerOver` 削除（:307-309）。年末の画面で閉じると再開できず、エンディングの図鑑記録（EndingViews.swift:51）が入らない。
- 既出：docs/career_end_save_options_v0.md（案A・B）／AUTOPILOT キュー117。判断待ち。新しい論点なし。

## §2 問題なしと確かめた主な所
- **GameState／WeekRunnerSnapshot**：合成 Codable（GameState.swift:10・WeekRunner.swift:631）で全フィールド保存。CodingKeys で落としている物は YearOutcome（Career.swift:43・dissolved の旧互換のみ）だけ。GameCore の乱数 rng・gpAlive・pendingSpec/Offer/Auto・weekClosed・offerChoices・pendingInvite まで入っている。保留中の大会・オファーは config から取り直す（A-4）。
- **UI層の一発化フラグ**（didFire*／styleTalkDone／firedWeeklyEvents／weeklyEventFiredCount／lastEventRollWeek／uiEventRng／jobCount／lastBanterRollWeek）：全部 SaveData にあり、復元 init で書き戻している（:300-336）。1週1回ガードも保存されるので、再開後に抽選が二重に走らない。
- **choiceApplied**：選択後は保存に pendingChoiceEvent を入れない（:1319）＝再開で選び直して効果が二重にかかる事故なし。dismissChoiceEvent で保存。
- **winFinale／finished／outcome**：保存しないが復元で phase（.yearDone）と winAcknowledged から導出（:285-293）。優勝の演出中に閉じれば演出から、見終えた後なら選ぶ画面から。retiredAfterWin は選ぶと保存が消えるので持たなくてよい。
- **watchingFinal**：復元の checkSpectatorFinal（:308 の後）が同じ条件で立て直す。didWatchFinal は保存済み。
- **lastFinalMargin／yearStartState／hasYearStart**：復元で週内結果・旧セーブ互換から導出。
- **riftWarn 系**：予告を見ないまま消えた旧版の保存は未発火に戻す処理あり（:307-309）。didShowRiftHint・debtWarnTier は保存済みで、知らせを出す時点（markDebtWarned／markRiftHintShown）に保存＝再開で同じ知らせが2回出ない。
- **TrophyBook／EndingBook／MetaBook の永続（別キー）**：pump 内の onStage／onYearEnd／recordChampion は choose 等の保存と同じ呼び出しの中で完結。復元の経路は pump を走らせない（phase をそのまま置く）＝二重に数えない（didRecordChampion の件は既知・今の経路では起きない）。smallEntered／smallWon は保存済み。
- **firstShow（固定の一文）**：tag（id#key）を shownOnce に保存＝再開しても同じ答え。
- **Names／ComboKind／MeetingKind**：復元 init で Names.set／setKind を呼び直している（:267-268）。
- **画面の @State のうち状態に効く物**：yearTurn（RootView）は閉じても保存側は yearDone のまま＝再開で年末画面から。rentShownKey・burstPlayedKey・stampPlayedKey・lastBeatWeek・banterIndex・offerPick は表示の一拍だけ（二重に数える物なし）。vesselFullToastShown は onChange(of:) で動くので再開直後に出ない（出し損ねる側で二重にはならない）。OneTimeHint は別キー（UserDefaults）に保存。
- **旧セーブ**：後から足した SaveData のフィールドは全部 Optional（`?? 既定`）。version は復号に使っていない（足すフィールドは Optional のままなら問題なし）。

## 件数
指摘7（うち新規6：低6／既出1〜2）。最も重い1件＝§1-1（誘いの発想+0.5が再開で付かない・復元時に導出で直せる）。
