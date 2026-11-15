# ソフトロック（操作を受け付けず先へ進めない）監査（2026-11-15・読み取りのみ）

対象：ManzaiGame/Sources 全体（DEBUG／MZ_* フックは除く）。型は①入力を止めるフラグの下ろし忘れ ②閉じられない覆い・onDone が呼ばれない経路 ③session のフェーズと画面表示の食い違い ④待ちループの上限なし。
既存の直し（StageCeremony の abandon・cancelled_sleep_audit・double_tap_audit）とは重ならない物を主に見た。
結論：普通の遊び方で詰む（高）は無し。中1件・低2件。いずれも「アプリを落として開き直せば戻る」型で、セーブは無事。

## §1 指摘（3件）

### 1. 獲得の一拍（Beat2）の最中に「日程／コンビ／設定／目標帯」を開くと、保留中の選択肢イベントが出せず、行動カードが全部無反応になりうる　【中・確信度 中】
- 場所：WeekMainView.swift:1417-1419（YoseFooterItem の3つ）・:468（目標帯の日程）／:1297 syncEventPresentation／:261-269 onChange(of: burstHold)／:920・:1006 の guard。
- 手順：行動カードを押す→週が進んでイベントが立つ（burstHold が立ったまま Beat2 が約1.5秒）→その1.5秒の間に下の「日程」「コンビ」「設定」か上の目標帯を押す（Beat2 のタップ受けは画面上半分だけ・:252-258。下の帯は覆われない・tapOrQueue も通らない）→cover（または sheet）が開く→Beat2 が終わり、0.3秒後に syncEventPresentation が showEvent=true を立てる→同じ View に fullScreenCover／sheet が2枚重なるため、イベントの cover は出ない（SettingsView.swift:120 のコメントにも「片方が開かないことがある」と既出）。
- 閉じた後の状態：showEvent=true のまま・pendingChoiceEvent も残る。根の allowsHitTesting（:171）は「!showEvent」の時だけ止める作りなので止まらず、カードは押せるが、actionCard の guard（:920・:1006）が「pendingChoiceEvent == nil」を要求して弾き、syncEventPresentation は showEvent がもう true なので何も変えない。＝行動カード・年末へが全部無反応。SwiftUI が閉じた後に遅れて出してくれればそこで解消（確信度を「中」にした理由）。
- 抜け方：日程／コンビ／設定は開ける。アプリを落として開き直すと、セーブに pendingChoiceEvent が残り（GameSession.swift:1331）、onAppear の syncEventPresentation（:263）で出るので戻る。セーブは無事。
- 最小の直し：(a) 3つの footer と目標帯のボタンを `tapOrQueue`（または `guard !burstHold`）で包む。(b) syncEventPresentation に「他の cover／sheet（showNotebook・showCalendar・showShop・showAllocation・showSettings）が開いていない」を足し、それぞれ閉じた時に syncEventPresentation を呼ぶ。(a) だけで窓はほぼ塞がる。

### 2. perform が burstHold を先に立て、choose が何もせず戻る／週が進まない経路だと、burstHold が下りない　【低・確信度 中（今は届かない）】
- 場所：WeekMainView.swift:873-877（burstGen += 1・burstHold = true の後に choose）／:292-296（下ろすのは `.task(id: session.week)` の defer だけ）／GameSession.swift:370（`guard case .freeAction = phase else { return }`）。
- 手順（理屈）：choose が早期 return する、または choose の後に session.week が変わらないと、`.task(id: session.week)` が走り直さず、defer が来ない。burstHold が立ちっぱなし＝以後の行動カードは guard（:920）で無反応、押下の予約実行も tapOrQueue（:1303-1309）が3秒待って諦める。
- 今届かない理由：週メインが出ている間は phase が必ず freeAction で、choose は成功し、WeekRunner.begin()（GameCore WeekRunner.swift:182）が week を毎回 +1 する。年末・大会は View ごと入れ替わり、@State が捨てられる。将来 choose に早期 return が増えた時の地雷。
- 抜け方：アプリを落とせば戻る（burstHold は @State でセーブに入らない）。
- 最小の直し：choose の前に `let w0 = session.week` を持ち、choose の後で `if session.week == w0 { burstHold = false }`。または burstHold を choose の後（week が変わったのを確かめてから）に立てる。

### 3. 復元したセーブの phase が weekDone で pendingResult が空だと、画面が ProgressView のまま永久に動かない　【低・確信度 中（壊れたセーブ限定）】
- 場所：GameSession.swift:331（`pendingResult = results が空なら nil`）・:277（phase は保存値を weekDone のまま使う・sameStep は weekDone を取り直さない）／RootView.swift:439-443（default: ProgressView）。
- 手順：通常の経路では weekDone はちょうど pendingResult が立つ間だけで、pendingResult は results 非空（pump の `!big.isEmpty`）なので起きない。crash_audit_1115 #1 の直しで「results が空の pendingResult は捨てる」にしたため、壊れた／空のセーブが来ると phase=weekDone・pendingResult=nil の組が生まれ、どの画面の条件にも当たらず ProgressView になる。
- 抜け方：無い。起動のたびに同じセーブを読むので、アプリを落としても戻らない（セーブが残り続ける）。データを消す以外に出口が無い。
- 最小の直し：init(restoring:) の最後で `if case .weekDone = phase, pendingResult == nil { phase = runner.begin(); pump() }`。保険として RootView の default 枝に「最初からやり直す（abandonRun）」ボタンを置く。

## §2 問題なしと確かめた主な所

### 入力を止めるフラグ（型1）
- WeekMainView の pulledID：beatTask は取り消されても sleep が即返るだけで最後まで走り、必ず `pulledID = nil`（:882）に届く。Beat1 は全画面の覆いがタップを受けるので、footer も押せない（:248）。
- burstHold／burstGen：下ろすのは defer（:296）で、取り消し・早期 return（:300・:302・:306）のどの出口でも走る。世代が食い違うのは「旧週のタスクの後始末」だけで、新しい週のタスクが同じ世代で下ろす。perform は burstHold 中は guard で入れず（:920）、tapOrQueue も burstHold が下りてから実行するので、世代が二重に進む経路は無い。
- presentRent（:1292）の `while rent != nil` は上限が無いが、RentStatementView は背景タップで onDone が呼べ（RentStatement.swift:64）、同時に出うる他の知らせ（injury／debt／hint）は rent == nil を条件にしているか、rent より上の層に出るので、閉じられない状態にならない。
- tapOrQueue の待ち（:1307）は 60 回の上限あり。toast を待つループ（:1529）も 50 回の上限あり。
- GachaView の busy：`defer { busy = false }`（:147）で下りる。.disabled(busy) は pullCard だけで、ヘッダの閉じるは生きている。StoreKit の購入が返らなくても閉じて出られる。
- SettingsView の restoring：await の後に必ず false へ戻る。購入の復元が失敗しても false になる。
- AbilityUpView の confirming：Task の末尾の finishConfirm が必ず走る（二度押しは confirmFinished で止める）。
- FinalsPresentationView の holdingSeventh：下ろすのは自前の Task の末尾。onDisappear で取り消されるのは View が消える時だけ（この View は cover／sheet を出さない）ので、消えた後に残る心配は無い。
- StageFrame.StageCeremony の done／allowsHitTesting(!done)：done の後は覆いごと消える設計。キャンセル時は abandon（既直し）。
- YoseChampionCelebrationView の `.allowsHitTesting(phase >= 5)`：画面全体の onTapGesture が別にあり、完成前でも completeImmediately で phase=5 へ飛べる。DispatchQueue のタイマーは isCompleted／isGone で止まる。詰まない。

### 覆いの閉じ方・onDone（型2）
- ChoiceEventOverlay：選択肢あり→選択→返事を送り切る→閉じる、の全経路で最後に closeButton が出る（afterDone）。選択肢なしフレーバーは1タップ閉じ。afterChoice が無い・空でも afterDone が true になる。選択で効果が変わって availableEventChoices が空になっても、chosenID が入った後は closeButton 側へ流れる。dismissChoiceEvent は choiceApplied も戻す（GameSession.swift:801）。
- FinalsBroadcastIntro／FinalsBroadcastEnding：タップで必ず進む／閉じる。自動送りが取り消されても、タップ経路は生きている。
- FinalsPresentationView：ボタンとタップが ceremonyDone に依存するが、StageCeremony は取り消し時 abandon でなく finish か（既直し）、View ごと消える。showChamp は画面タップで onFinish に届く。
- TournamentResultView：開示が終わるまでの自動進行は finishReveal（タップ）で畳める。nextArmed は0.8秒後に必ず立つ。QualifierNoticeView（飛ばす／つづける）・FinalistAnnounceView（飛ばす／つづける）・StagePreludeView（本番へ）・TournamentEntryView（見送る）は常に押せるボタンがある。
- YearResultView／YoseYearTurnCurtain：タップ・ボタンで進む（hasTriggeredStart で二度押し対策済み）。startNextYear の guard が失敗しても curtain は閉じ、年末画面へ戻る。
- DisbandFarewellView・IntroFlow（回想・初舞台・名前入力）・S6bView・EndingFlowView：最後の拍の後に onComplete／onFinish へ届く。ReminiscencePlayer は cards が空でも onComplete へ進む。名前入力は空白のみだとボタンが無効だが、文字を入れれば押せる。
- Notebook／Calendar／Shop／AbilityUp／GachaRates：YoseHeaderBar の closeAction（または「戻る」）が常にある。ネタ帳の下位一覧は戻るボタンあり（WeekMainView.swift:657）。

### フェーズと表示の食い違い（型3）
- RootView.content の分岐：freeAction／tournamentDecision／gpRound／gpRevival／gpFinal は専用画面、weekDone は pendingResult が立つ間だけ、yearDone は pump が必ず finished か winFinale を立てる。残る default（ProgressView）に落ちるのは上の指摘3だけ。
- endingID が nil のまま showEnding になる経路：retireAfterWin は優勝年末だけで、EndingID.judge は champion なら非 nil。careerOver で onNextYear が nil の時の onEnding／onRestart の振り分けも欠けなし。
- pendingChoiceEvent が残ったまま覆いが出ない：根の allowsHitTesting が止まるのは「!showEvent かつ pulledID == nil」の時で、その時は burstHold が下りれば onChange(of: burstHold)、イベントが立てば onChange(of: pendingChoiceEvent)、View 作り直しなら onAppear の syncEventPresentation が必ず出す。指摘1だけが例外（他の覆いが開いている間に showEvent が立つ）。
- fastForwardToYearEnd（steps < 200）・年末の watchingFinal・finishWatchingFinal：すべて出口あり。stuck 判定の `default: return` で止まる時も、週メイン側の状態は壊れない。

### 待ちのループ（型4）
- `while` の一覧を全て確認：Task.isCancelled を見るもの（FinalsPresentationView の自動送り・voteTailTask）・上限付き（tapOrQueue 60回・toast 50回・FinalsPresentationView:1250 の idx<700 ほか数値計算）・描画用（Canvas／Path の座標ループ）。上限も取り消しも無い待ちは presentRent だけで、上に書いた通り rent の onDone で必ず抜ける。
