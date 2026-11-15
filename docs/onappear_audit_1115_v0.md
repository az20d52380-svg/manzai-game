# onAppear / .task 再実行の監査（2026-11-15・読むだけ・コード変更なし）

対象：ManzaiGame/Sources 全体の `.onAppear` と id 無し `.task`（DEBUG／MZ_* フックは除く）。
前提：このアプリには TabView / NavigationStack が無い。「同じ画面でもう一度 appear する」経路は次の2つだけ。
- (A) WeekMainView の上に出す **fullScreenCover**（ネタ帳・カレンダー・選択肢イベント・能力アップ・買い物）を閉じて戻った時。`.task` は再 appear で作り直される（`.task(id:)` も同じ）。`.sheet`（設定）は presenter の appear を起こさない。
- (B) RootView の `content` の phase 切替（週メイン⇄大会入口／結果／決勝）で WeekMainView 自体が作り直され、@State が初期値に戻る時。

注意：(A) は「fullScreenCover を閉じると presenter の onAppear が再発火する」という挙動に依存する。iOS のバージョンで差があり、私は実機・シミュレータで確かめていない（確信度に反映）。確かめる最小の方法：WeekMainView の burst タスクの先頭に DEBUG の print を1行入れて、行動→獲得の一拍→（イベント or ネタ帳を開いて閉じる）を1回やる。

## §1 指摘（3件＋低2件）

### 1. 獲得の一拍（Beat2 バースト）が cover を閉じるたびに再生される　重さ：中　確信度：中
- 場所：WeekMainView.swift:285〜315（`.task(id: session.week)`）。ゲートは 295 行の `session.lastDeltaWeek == session.week` だけ。
- 2回目が走る手順：週メインで行動（例：練習）→ 獲得チップが出る（1回目・正常）→ 続けてイベントの cover が出る、または自分でネタ帳／カレンダー／買い物／能力アップを開く → 閉じて週メインに戻る。`lastDeltaWeek` は次に `choose` するまで「今週」のままなので、ゲートは通る。
- 2回目で起きること：`makeBurstChips()` のチップがもう一度立ち上がり、火花（particleFire）と音 `Sound.play(.grain / .pop)`・収支が増えた週は `.money` が再び鳴る。1.2 秒ぶんタップも畳みに使われる。状態（GameSession・お金・経験点）は変わらない＝見た目と音だけの二重。
- 最小の直し：`rentShownKey` と同じ型で `@State private var burstPlayedKey = 0` を足し、295 行の guard の直後に `let k = session.year * 1000 + session.week; guard burstPlayedKey != k else { return }; burstPlayedKey = k`。（`burstHold` を下ろす defer と `presentRent()` は guard の前に影響しないよう、guard 位置に注意。）

### 2. 週めくりスタンプ＋音が cover を閉じるたびに再生される　重さ：低〜中　確信度：中
- 場所：WeekMainView.swift:316〜322（`.task(id: session.week)`）。`session.week > 1` なら `Sound.play(.transition)` と「第N週」札を無条件に出す。
- 手順：第2週以降で、ネタ帳／カレンダー／買い物／能力アップ／選択肢イベントを開いて閉じる。
- 起きること：週めくりの音と札が、週が変わっていないのにもう一度出る。
- 最小の直し：1 と同じ型で `@State stampWeekKey`（year*1000+week）を持ち、同じキューなら return。

### 3. この週の伸びバー（オレンジ）の再点滅　重さ：低　確信度：中
- 場所：WeekMainView.swift:277〜284。`lastGains` が残っていれば `gainsVisible = true` を 1.2 秒。
- 手順・起きること：1 と同じ。音なし・状態変化なしの見た目だけ。
- 直し：1 の `burstPlayedKey` を共有して早期 return すれば足りる（別に直さなくてもよい）。

### 4. 年初の知らせ（飽き・若手最後の年）が WeekMainView の作り直しで再度出る可能性　重さ：低　確信度：低
- 場所：WeekMainView.swift:34-35（@State の `youthNoticeYear` / `tiredNoticeYear`）と 1509〜1530。onAppear(270) の 0.7 秒後に毎回判定される。
- 手順：年初（第1週）に大会入口（tournamentDecision）が出る年だと、週メイン→大会入口→（見送り or 結果）→週メインで WeekMainView が作り直され、@State が 0 に戻る。まだ第1週のままなら、同じ年の toast がもう一度出る。第1週が大会入口にならない現行カレンダーなら起きない（カレンダー側の確認はしていない）。
- 直し：マーカーを session 側（`GameSession` に「この年は知らせ済」）へ移す。または現状でカレンダー上起きないと確認できたら放置でよい。

### 5. SettingsView（:28）／GachaView（:69）の `clearMessage()`　重さ：低　確信度：中
- 場所：SettingsView.swift:28、GachaView.swift:69（`.task { store.clearMessage(); await store.refresh() }`）。どちらも自分の中に fullScreenCover（用語集・図鑑・提供割合）を持つ。
- 手順：ガチャ画面で購入後の文言が出ている状態で「提供割合・ルール」を開いて閉じる。
- 起きること：購入結果などの文言が消え、`refresh()`（ストア問い合わせ）がもう一度走る。課金や付与の二重実行はしない（冪等）。
- 直し：`clearMessage` を初回だけにしたいなら `@State var didInit` で囲む。優先度は低い。

## §2 問題なしと確かめた主な所

WeekMainView
- :270 onAppear の `syncEventPresentation`：イベントが立っていて保留が無い時だけ `showEvent=true`。冪等。
- :270 の 0.7 秒後の `maybeShowDebtNotice`：`injuryNotice`/`debtNotice`/`riftNotice` が nil の時だけ、かつ session 側で `markDebtWarned(tier)`・`markRiftHintShown()`・`clearInjuryNotice()`＝session の「済」記録で二重に出ない。
- :270 の `maybeShowFirstHints`：`OneTimeHint.isDone(key)` と `hint == nil` で守られる（記録は HintModal を閉じた時に `markDone`）。:275 の `.task` も同じ関数＝同じ守り。
- :1275 `presentRent`：`rentShownKey`（year*1000+week）で週1回。cover 往復（A）では @State が残るので二重に出ない。(B) で作り直されても、その時は週が進んでおり `lastDeltaWeek == week` ゲートで落ちる（週が進まない経路が無いことまでは確認していない）。
- :323 `Sound.bgm(.daily)`：`playBGM` が同じ曲なら音量だけ戻して return（SoundManager.swift:136）。冪等。
- :330 `.task(id: toastSeq)`：toast の自動消去のみ。
- 週 `onChange` 系・`vesselFullToast`：onChange は appear では走らない。`vesselFullToastShown` で年1回。
- :383, 1718, 1728（FadeInOnAppear）：見た目の初期化のみ。

大会・決勝・結果まわり（内部に cover が無い＝同一画面で再 appear しない）
- FinalsPresentationView :239（beat を .lot に戻す・BGM）・:622（歓声）・:1142（ファンファーレ）：画面内に fullScreenCover/sheet が無く、phase 切替でしか作り直されない＝新規作成扱いで正しく1回。:578 の `runLot` は `lotRevealed` で守る。
- FinalistAnnounceView :109 `start()`：`task == nil` ガード。TournamentResultView :323 `beginReveal`：`revealTask == nil` ガード。FirstStageView :80・QualifierNoticeView :71：Task を保持して onDisappear で取消。
- YearResultView :79/:82（判・ファンファーレ・Haptics）：内部に cover なし＝1回。
- StageViews :194/:324 `ensureStageNetaDefault()`：未選択の時だけ最高完成度を入れる冪等処理。:245 / AbilityUpView :88 の `OneTimeHint`：`isDone` ガード、記録は閉じた時。
- StageFrame :293（開演の儀）：内部 cover なし。`seenKey` は初回印のみで消費しても画面を飛ばさない。
- EndingViews :42：`recorded` @State ガード。図鑑 `EndingBook.record` は `!replay` 限定。:328 の `seen = EndingBook.load()`：読み込みのみ。
- RentStatement :124、YoseYearTurnCurtain :139、YoseRankUpOverlay :114、YoseMilestoneFX :147/:339、YoseChampionCelebrationView :175：オーバーレイとして1回だけ出す演出で、上に別の cover が乗らない。

その他
- ShopView :53 `visitStart`：nil の時だけ代入。ガチャ cover から戻っても上書きしない。
- NetaStage :40：`lastSeen` の静的辞書で冪等（増えた時だけ光る）。
- IntroFlow :411/:642、CalendarView :41、TalkParts・StageScene・YoseComponents・YoseMotion の onAppear：アニメ起動のみ。
- RootView :90 `.task`：本番経路は DEBUG ブロックの外が実質空（フック専用）。RootView :54 は MZ_TAB の目視フック。
- GachaView のログインボーナス受け取り：onAppear/.task では受け取らず、ボタン押下（`canClaimLogin(today:)` ガード付き）。
- 経験点・お金・OneTimeHint の「付与」を onAppear/.task 内で直接している所は見つからなかった（OneTimeHint の記録は全て HintModal を閉じた時）。
