# コードレビュー 11/16 夜（a64f492d3..HEAD・30ファイル）v0

## §1 要約
- 見た範囲：`git diff a64f492d3 HEAD -- ManzaiGame/Sources GameCore/Sources` の全30ファイル（GameSession・WeekMainView・GameCore は周辺の本体も確認）。
- 「落ちる・保存が壊れる・二重に数える・読めない色」に当たる確実な不具合は **見つからなかった（高0・中0）**。気になる点は低が2件・要確認が3件。
- 保存データの追加項目（inviteIdea・年初の知らせの年）はすべて Optional で旧セーブも読める。週の差分表示の付け替え（体調ダウン後の療養週を混ぜない）も、元の値の取り方と整合していた。

## §2 指摘

### 確実なもの
**1. 所持金の数え上げ中、「0」が赤字で出る瞬間がある（低）**
- 場所：ManzaiGame/Sources/RentStatement.swift:87〜90（`Text((Int(money) < 0 ? "−" : "") …)` と、すぐ下の `.foregroundStyle(money < 0 ? YoseColor.shu : …)`）
- 何が起きるか：マイナス記号の判定は整数に丸めた値（Int(money) < 0）に直したが、色の判定は元の小数のまま（money < 0）。数え上げの途中で −1 〜 0 の小数になった一瞬だけ、記号なしの「0円」が赤（借金の色）で出る。
- 再現：所持金が数円足りずに家賃を払う週など、数え上げが0をまたぐ時（一瞬・約1コマ）。
- 重さ：低（見た目だけ・一瞬）
- 直し方：色も `Int(money) < 0` で判定する。

**2. 年末の見出しの語の途中折り返し対策の関数に、極端に長い一続きの文字があると折れ位置が増える（低）**
- 場所：ManzaiGame/Sources/NotebookView.swift:157〜164（breakAtSpaces）
- 何が起きるか：9字以上のかたまり（例：長い大会名やコンビ名）は字の間の目に見えない結合記号を入れないので、そこは従来どおりどこでも折れる。大きい文字の時、長いコンビ名が入る行では「語の途中で折れない」が効かない。
- 再現：10字以上のコンビ名＋「優勝」の行を、文字を最大にして見る。
- 重さ：低（崩れではなく従来どおりの折れ方）
- 直し方：8字の上限を外すか、長いかたまりだけ別の折り方にする。必須ではない。

### 要確認（読んだだけでは確かめられない）
**3. 見えない結合記号（U+2060）を字の間に入れた文の読み上げ・フォント（低〜中）**
- 場所：NotebookView.swift:157〜164、YearResultView.swift:293
- 気になる点：8字以下のかたまりは1字ごとに結合記号を挟む。VoiceOver が「優」「勝」と別々に読むか、明朝フォントで空白や豆腐（□）が出ないかは、実機でないと分からない。ビルド・シミュレータ禁止のため未確認。
- 確かめ方：VoiceOver を入れて「きろく」画面の1行を読ませる／明朝の年末の画面で□が出ないかを目視。

**4. 週末の誘い（先輩の誘い）の発想付きの記憶が、保存の瞬間によっては落ちる（低）**
- 場所：GameSession.swift:1364（`inviteIdea: pendingChoiceEvent == .weekendInvite ? inviteIdea : nil`）と 631〜635・1408
- 気になる点：誘いが決まってから札が出る（pendingChoiceEvent が立つ）までの間に保存されると、inviteWaiting も inviteIdea も保存されない。その間の保存は、画面が出る直前の短い間だけ（シーン切替の `.inactive` 保存が今回増えたので、少し当たりやすくなった）。復元後は誘いが消えるだけで、落ちない・壊れない。
- 確かめ方：pump の631〜635行の前後で saveNow が走りうるかを確認。

**5. 結成画面（IntroFlowView）の `finished` が、同じ画面の使い回しで残らないか（低）**
- 場所：IntroFlow.swift:780〜786
- 気になる点：`@State` なので、画面が作り直されれば新しい値。タイトルへ戻って再度結成する時に IntroFlowView が作り直されず使い回されていると、2回目の結成が無反応になる。RootView 側で `started` により画面ごと作り直す作りに見えたが、全経路は追っていない。
- 確かめ方：RootView の IntroFlowView の出し入れ（if/else で作り直されているか）を確認。

## §3 見て問題なしと判断した所
- GameCore/GameConfig.swift `netaWork(for:)`：旧 applyNetaWork の分岐（書く3種＋ネタ見せ会＋フリーライブ、それ以外は何もしない）と同じ対応。引数の gain も旧 `netaPlaceGain[t]` と同じ。
- GameCore/Item.swift `injuryProbability`：旧式（閾値−体力）×1点あたり×喉ケア倍率×体が資本、の掛け合わせを同じ順で関数に抜き出しただけ。WeekRunner の呼び出し側も同じ。乱数の引く回数は変わらない。
- WeekRunner `applyNetaRetire`：2本目の選択も外す一行は、存在しない id では何もしない作りで、点数計算は変わらない。
- GameSession `choose` の「押した週の末」表示：weekDone の写しは週末処理（applyWeekEnd）の後に作られる（WeekRunner 462→477行）ので、生活費の足し戻し（livingPaid）の式と整合する。写しが取れなかった場合は元の state に戻る。
- 同 `capturingActedWeek`：pump 後に必ず false に戻る（同期処理）。他の経路の pump には影響しない。
- 同 バイト回数（jobCount）の付け替え：resolveAction の後に、「体調ダウン」の結果が付いた週を除いて数える。判定は weekDone の結果名だけなので、他の週へ波及しない。
- 同 拘束週の日程の判子「仕」：拘束中の稽古は385行で休みに差し替わるので、後ろの `.kaifuku` への上書きは起きない。
- 同 復元時の空の結果の破棄と、weekDone で結果なしの時の `runner.begin()`＋pump：acknowledgeResult と同じ進め方。再処理で二重に数えるのは空の結果という壊れたデータの時だけで、中身が空なので数える物がない。
- 同 保存項目 inviteIdea／youthNoticeYear／tiredNoticeYear：すべて Optional で旧セーブは nil→既定値。
- 同 年末の称号（t14・onStage の追加呼び出し）：年末の再入は `yearHistory.last?.year != runner.year` の中の1回だけ。優勝の週は決勝を除いて渡すので、通過の称号の二重加算はない（weekDone を経ない週なので）。
- 同 `recallNeta` の writeNewNeta 下ろし、advanceAuto の知名度の差の記録：副作用は表示用の値のみ。
- 同 デバッグ用の `debugSeedKirokuLog` の MZ_KIROKU 分岐：DEBUG の関数内のみ。
- WeekMainView：燃やし（burst）と週めくり札の「1週1回」キー（年×1000＋週）は、年が変わっても衝突しない。取り消されたら出し直さないのは意図どおり。
- 同 toast を `.task(id: toastSeq)` にしたこと：同じ文でも測り直せる。nonmutating の年初の知らせの読み書きも、毎回 session に書くだけ。
- 同 `openOverlay`：イベント待ちで一拍中なら畳んでイベントを先に出す。他は従来の tapOrQueue。
- 同 オファーの二度押し（3秒の時計に世代番号）：古い時計が新しい確認を消さない。0.4秒未満の素通りも防げている。
- 同 相性チップ `cd`：相性は週で減らない（GameEngine に減衰がない）ので、療養週が挟まっても「前後を丸めて引く」の計算は合う。
- 同 maybeShowDebtNotice の pulledID 条件追加：出なくなるのは行動中だけで、週が進んだ後の呼び出しで出る。
- CalendarView：`ViewThatFits` の2案が同じ部品（stampKeys／tournamentKeys）を使う。固定幅の判子と文字は大きい文字でも折れるだけで、ダークモードでも sumi／kinBright の既存色のまま。
- StageViews `breakAtLastDot`：「・」が無ければそのまま。1行に収まる時は1行、収まらない時だけ改行。
- StageFrame／FinalsBroadcastIntro／FinalsPresentationView：取り消し時の後始末（BGM を戻す・余計な一拍を鳴らさない）は done を立てない作りで、再表示でやり直せる。`.disabled(holdingSeventh)` は溜めが終われば解除される。大トリの文言の条件分岐も、押した時の動き（356〜357行）と合っている。
- QualifierNoticeView `rosterSeed`：表示専用の種。符号なしの足し算で、オーバーフローしない（&+／&*）。
- TournamentResultView：結果発表の文言と HANA の「次へ 進む」はラベルだけの差し替え。DEBUG 分岐の括弧は閉じている。
- YoseChampionCelebrationView：新しい引数 proceedLabel は既定値付きで、既存の呼び出しを壊さない。
- YearResultView：旧セーブでは知名度の「今年の伸び」を出さない（delta が Optional で既に受け取れる）。
- S6bView／IntroFlow／ChoiceEventOverlay／AbilityUpView／NetaStage：二度押しの1回だけ化・世代番号は、どれも状態を1つ足すだけで、他の経路に影響しない。
- ShareCard：画像が出るまで見えない同サイズの枠を置く。読み上げからは外している。
- ShopView：スクロール位置の指定は DEBUG の環境変数の時だけ bottom、本番は既定の top。
- RootView：やめる時の BGM 停止と記憶の消去は returnToTitle と同じ扱い。`.inactive` の保存は件数が増えるだけで、状態を変えない。
- GachaView `wornNow`：読み取りだけで、状態を書かない。
- Store/AdProvider：completion の二重呼び出しを防ぐ var は、1つの呼び出しごとに別。
- EventBackgrounds：同じ座標が2つ並ぶ ForEach を offset の id に直した（座標が重なると表示が潰れていた）。見た目は同じ。
- Design 配下のアクセシビリティ文言の追加：見た目に影響なし。

## §4 その後（11/16 昼 定期）
- #1 直した（色も `Int(money) < 0` で判定）。
- #5 確認済み＝問題なし：RootView:389 は `if … else { IntroFlowView … }` の分岐で、タイトルへ戻ると画面ごと作り直される＝`finished` は残らない。
- #4 確認：誘いが決まるのは週送りの後（GameSession:1408 で inviteWaiting=true）、札が出るのは次の週の頭（631〜635・同じ関数の中で同期＝その間に保存は割り込まない）。保存されないのは「週送りの後〜次の週の頭」に終了した時だけで、その時は誘い1回分が消えるだけ（落ちない・壊れない）。直すならセーブに inviteWaiting を足す（形式の追加）＝低のまま・急がない。
- #2・#3 は残す（#3 は実機の VoiceOver が要る）。
