# 本体の直し レビュー（2026-11-15・正しさの観点）v0

範囲：`git diff 2660f1338~1..HEAD -- ManzaiGame/Sources`（13コミット・12ファイル）。コードは読んだだけ（ビルド・実機は未実施）。

## §1 指摘（3件・重いものは無し）

### 1-1　週めくりの札が出たまま残る（WeekMainView.swift:324-332）　重さ：中〜低／確信度：中
- 手順：週が明けて札（「第N週」）が出た0.7秒以内に覆い（日程・コンビ等）を開く → `.task(id: session.week)` が取り消される（札を消す行は `if !Task.isCancelled` で飛ばされる）→ 閉じて戻ると `.task` が張り直される → 新しい `stampPlayedKey` の guard で即 return → `weekStampVisible` が true のまま、次の週まで札が残る（旧コードは張り直しで出し直して消えたので自然に直っていた）。
- 起きやすさ：獲得の一拍が空の週（チップも一言も無い）だと burstHold がすぐ下りるので、0.7秒以内に開ける。普段は一拍が1.2秒以上あり tapOrQueue で待たされるので出にくい。
- 最小の直し：guard で弾く側に `weekStampVisible = false` を足す（`guard stampPlayedKey != stampKey else { weekStampVisible = false; return }`）。

### 1-2　開演の儀を abandon した後に画面が残ると黒いまま止まる可能性（StageFrame.swift:300-317）　重さ：低／確信度：低
- 手順：儀の最中に `.task` が取り消される → `abandon()` が `done = true` にして onDone を呼ばない → もしその View が破棄されず再表示されると、`.task` が張り直されても `guard !done` で何もせず、`allowsHitTesting(!done)` でタップも効かず、`veil` が 1 のまま（黒）。`ceremonyDone` が立たないので TournamentResultView:264 の beginReveal も走らない。
- 現状の呼び元（FinalsPresentationView:210・TournamentResultView:264）は phase の switch 内で、消える＝破棄なら問題ない。覆いで一時的に onDisappear だけ来る構成だと詰む。
- 最小の直し：`abandon()` で `done` を立てず、BGM を戻すだけにする（再表示で儀が最初からやり直される）。または `.task` の先頭で `done` を false に戻す。

### 1-3　設定・日程・コンビが無反応になる窓（WeekMainView.swift:1298-1301, 1422-1426, 468）　重さ：低／確信度：中
- 手順：獲得の一拍中（または引き抜き中）に選択肢イベントが控えている時にフッターの「設定」を押す → `openOverlay` は黙って何もしない。イベントが出れば覆いの下になるので実害は小さいが、設定（「この年をやめる」の唯一の入口）は以前は直接 `showSettings = true` で常に開けた。また、控えが無い一拍中は tapOrQueue で最大3秒待った後、まだ burstHold なら黙って捨てる。
- 最小の直し：設定だけは `openOverlay` を通さず従来どおり直接開く（設定は覆いの重なりで困る物ではない）。もしくは捨てる時に `burstSkip` を立てて再試行する。

## §2 確かめたこと（問題なし）
- toastSeq：`toast` を書く所は showToast（seq を増やす）と消す行（345行）だけ。同じ文の再表示でも seq が変わり待ちが測り直される。覆いで取り消された時も toast は残り、張り直しで消える。出ない／消えない経路なし。
- 若手最後の知らせの待ち（1536行）：50回×0.3秒＝上限15秒で必ず出る。別の toast に重ならない。View が消えても Task は続くが、出すのは toast だけで害なし。
- burstPlayedKey：キーを立てるのは `lastDeltaWeek == week` を通った後。覆いで取り消されて張り直しになってもスキップ側で presentRent を呼ぶので、支払いの画面は rentShownKey で1回だけ出る。大会画面を挟んで WeekMainView が作り直されると @State が初期化されるが、その場合は lastDeltaWeek の門が従来どおり効く＝悪化なし。年またぎは year*1000+week で衝突せず、年のやり直し機能も無い。
- openOverlay：`pendingChoiceEvent != nil, burstHold || pulledID != nil` の条件は意図どおり（カンマは AND・後半は OR を1条件で評価）。イベントが無ければ tapOrQueue で従来どおり開く。日程・コンビの帯とフッターは通る。
- 年初の知らせ印を session へ：新しいゲーム・周回・タイトル戻しは `GameSession()` を作り直すので 0 から始まる。WeekMainView は `started` 後の .freeAction でだけ出るので、プレースホルダ session に saveNow が走らない。saveNow は abandoned／終了後は保存を消す側に倒れ、DEBUG の MZ_SMOKE 等では何もしない。呼び元は onAppear／onChange(year) の自由週のみで、許されない段（結果待ち・年末）では呼ばれない。
- Swift の作法：`private var x: Int { get {…} nonmutating set {…} }` は struct の View で合法（setter は newValue を使わず session.year を書くが、2か所とも session.year を代入しているので意味は同じ）。@State を body の外の関数から書くのは従来どおり。`@ObservationIgnored` なので body の再評価は起きない。
- SaveData の追加3項目はすべて Optional＝旧セーブは nil で読める。inviteIdea は誘いの札が立つ時だけ保存し、復元は `?? false`。
- IntroFlow：`finished` で onComplete が1回だけ。タイトル戻しで IntroFlowView は作り直されるので @State が残らない。回想の onComplete の guard は、1回目で stage が .firstStage に変わる（@State は即時に読める）ので2回目だけを弾く。2周目以降（finish 側）も finished で止まる。進まない経路なし。
- オファー／年末への0.4秒：武装前の1回目は通常どおり武装、2回目が0.4秒以内の時だけ弾く（弾いても armed は保持＝読んでから押した本来の二度目は通る）。offerArmGen で古い3秒の時計が新しい武装を消さない。年末側の3秒は gen 無しだが、実行（二度目）で年が閉じるので影響なし。
- 復元で weekDone を進める処理：`pump()` は結果が出た週（`big` 非空）で pendingResult を必ず立ててから止まる＝正常なセーブは `.weekDone` ＋ pendingResult 非空。pendingResult が nil の `.weekDone` が保存されるのは、空の結果を捨てた時だけ。進め方は acknowledgeResult と同じ（begin→pump）。init の最後で全プロパティ設定後なので順序も問題なし。
- 相性チップ：`lastCompatGain` は state の実差（406行）なので、前後を丸めて引くのは行動カードの予告（1572行）と同じ数え方。出るべき週に出ない経路なし。0.6の伸びで整数が動かない週は出さず、動く週は出る。
- RentStatement の「−0」：`Int(money) < 0` で符号を決める。数え上げ中の (−1, 0) 区間で金額の文字色だけ赤のまま「0」が出る（`money < 0` のまま）が、見た目の瑕疵は極小（直すなら色も `Int(money) < 0` に）。
- 時計の世代番号（AbilityUpView／NetaStage）：各タップが自分の時計を持つので、最後のタップの時計が必ず光を消す。残りっぱなしの経路なし。
- AdProvider：`fired` を escape するクロージャに捕まえる局所 var は合法。呼ばれない場合の時間切れは従来どおり呼び元の責務（コメントどおり）。
- 音まわり：FinalsBroadcastIntro の onDisappear は `done` が false の時だけ duck を戻す（finish は done→duck→onDone の順で二重にならない）。FinalsPresentationView の扉・くじの取り消しガードは、取り消し後に鳴らさないだけで他の状態は変えない。RootView の abandoned で stopBGM は returnToTitle と同じ。
- ChoiceEventOverlay の `chosenID == nil` guard：1回目で chosenID が立つ前提（choose の直後に代入）。2つ目の押しだけ弾く。
