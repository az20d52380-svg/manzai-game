# コード点検 11/08c（アプリ側の画面11ファイル。読み取りのみ・コード変更なし）

対象：NetaSelectionView／ShopView／QualifierNoticeView／FirstStageView／GachaView／SettingsView／RadarChart／FanReportData／ShareCard／FinalistAnnounceView／StageViews。
既知の指摘（code_review_1107〜1108b・crash_audit_1108_v0）は除いた。実際のコードの行を読んで手順を追えた物だけを本文に置き、推測は末尾に分けた。

## 指摘一覧（高0／中2／低6）

| # | 重さ | 場所 | 一言 |
|---|---|---|---|
| 1 | 中 | StageViews.swift:214・221・226／GameSession.swift:352 | 東京開催・動画審査でも「夜行バス」で出たことになり、トロフィー「夜行バスの常連」が取れる |
| 2 | 中 | StoreManager.swift:50〜81 → GachaView.swift:136／SettingsView.swift:61 | 購入・復元の一言が消えず、別の画面や次の購入でも古い文が出る |
| 3 | 低 | StageViews.swift:187／Calendar.swift:79-81 | THE HANA 1回戦・2回戦・準決勝の入口に「賞金 0万」が出る |
| 4 | 低 | FirstStageView.swift:109／IntroFlow.swift:770・841／RootView.swift:361-366 | 「第1週へ」の二度押しで GameSession が2回作られる |
| 5 | 低 | NetaSelectionView.swift:66-68／GameSession.swift:882-884 | 決勝で1本目に2本目と同じネタを選ぶと、2本目が黙って外れる |
| 6 | 低 | FinalistAnnounceView.swift:54-59／QualifierNoticeView.swift:40 | 漢字・英字のコンビ名は、読み上げと一覧の並びが毎回同じ端に固定される |
| 7 | 低 | FanReportData.swift:127・322 | 無名のうちは出さない決まりの「常連」「毎回」が knownOnly から漏れている |
| 8 | 低 | GachaView.swift:96-97 | ログインボーナスの最後の1枚で札が即0枚に戻り、満杯の絵が見えない（言葉では伝える） |

---

## 中

### #1 中｜東京開催の大会・動画審査も「夜行バス」で出たと数える（トロフィー t12 の誤付与）
- 場所：StageViews.swift:226（東京開催の「出場する」／「動画を送る」が `session.decideTournament(.夜行バス)` を渡す）、GameSession.swift:352（`if travel == .夜行バス, TrophyBook.bump("bus") >= 10 { TrophyBook.award(.t12) }`）、Meta.swift:35・62（t12「夜行バスの常連」＝「夜行バスで遠征を10回する」）。
- 手順：東京開催の大会（若手限定賞・推薦制中堅賞・寒梅漫才杯・HANA1回戦…）の入口で「出場する」を押す → StageViews の `else` 枝が `.夜行バス` を渡す（コメントどおり東京は交通費0・エントリー費のみ＝実際にはバスに乗っていない）→ decideTournament が `travel == .夜行バス` だけを見て `bump("bus")` する。東京開催の大会に10回出れば、バス0回のまま t12 が取れる。また大阪で金が足りず出られなかった場合（WeekRunner.swift:204 の注記「大阪で交通費が払えない場合も不出場」）も、押した時点で数える。
- 何が起きるか：トロフィーの説明（遠征10回）と取得条件が食い違う。トロフィーは周回の点（MetaBook）に効くので、周回の始まりの強さが条件より早く上がる（周回ボーナスの出方が変わる＝バランスに間接で触れる）。
- 直し案：数える条件を「大阪の大会（spec.osaka）で、実際にバスで出た」に絞る（`case .tournamentDecision(let spec) = phase` を取って `spec.osaka` を足す）。メタの数え方だけで、GameCore・乱数・golden には触れない。ただし既に付与済みのトロフィーの扱い、およびトロフィー点の効き方は**判断が要る**（オーナー判断）。

### #2 中｜StoreManager.lastMessage が消えず、別の画面・次の購入でも古い文が残る
- 場所：Store/StoreManager.swift:15（`@Published private(set) var lastMessage`）・50・59・65・76・81（代入は失敗系と復元だけ。成功・開始・画面を閉じた時に nil へ戻す所が無い。全箇所を grep で確認済み）、GachaView.swift:136（回す札の中）、SettingsView.swift:61（購入の節）。両方 `StoreManager.shared` を読む。
- 手順A：衣装ガチャで有料購入が一度「購入できませんでした」で失敗 → もう一度押して成功し結果が出る → 回す札には成功後も「購入できませんでした」が出たまま。
- 手順B：設定で「購入を復元」→「復元できる購入はありませんでした」→ 閉じて衣装ガチャを開く → 回す札の下に、ガチャと無関係な「復元できる購入はありませんでした」が出る（アプリを終了するまで消えない）。逆に、ガチャの「購入は承認待ちです」が設定の購入の節に残る。
- 何が起きるか：成功したのに失敗の文が残る・無関係な画面に別の文が出る。審査（購入まわり）で目に付く表示。
- 直し案：`purchase`／`restore` の先頭で `lastMessage = nil`、各画面の `.onDisappear` でも nil。表示だけ。式・数値には触れない。

---

## 低

### #3 低｜THE HANA の動画審査・2回戦・準決勝の入口に「賞金 0万」が出る
- 場所：StageViews.swift:187（`LineBoard(week:, prize: Yen.man(spec.prize))`）、Calendar.swift:79-81（`HANA1回戦／2回戦／準決勝` は `prize: 0`）、Theme.swift:463（`Yen.man(0)` → "0万"）。
- 手順：女性コンビで THE HANA 1回戦（動画審査）の入口を開く。木札に「賞金 0万」が出る。賞金が出るのは決勝（250万）だけ。
- 何が起きるか：「賞金0」と読めてしまい、動画審査・HANA予選に出る意味が薄く見える（実際は知名度が入る）。
- 直し案：`prize == 0` の時は賞金の札を出さない（`prize: spec.prize > 0 ? Yen.man(spec.prize) : nil`）。表示だけ。

### #4 低｜「第1週へ」の二度押しで GameSession が2つ作られる
- 場所：FirstStageView.swift:109（`Button("第1週へ") { task?.cancel(); …; onComplete() }`・押した後の無効化なし）→ IntroFlow.swift:770・841（`finish()` → `onComplete`）→ RootView.swift:361-366（`session = GameSession(seed: .random…)` を毎回作る）。
- 手順：初舞台の最後の「第1週へ」を素早く2回タップ（画面が消えるのは 0.4 秒のフェード後）。onComplete が2回呼ばれ、乱数の違う GameSession が2つ作られて後のものに差し替わる。
- 何が起きるか：基本は無害（後の方が残る）。GameSession の init が行う周回の点・トロフィーの読み込み／保存が2度走る。二重加算は 1107 #7 で「無し」としたので、被害は小。
- 直し案：FirstStageView に `@State var done` を置き、`guard !done` で一度だけ onComplete を呼ぶ。QualifierNoticeView の `finish()`（:264）・FinalistAnnounceView の「つづける」（:90）も二度呼びうるが、呼び手はフラグを立てるだけ（TournamentResultView.swift:277-287）で無害。表示だけ。

### #5 低｜決勝で「1本目」を選び直すと、2本目が黙って外れる
- 場所：NetaSelectionView.swift:66-68（`candidates` は `excludeID` と選択中だけを除く。1本目の行は excludeID が nil）、GameSession.swift:883（`selectNeta`：`id == state.selectedNetaID2` なら 2本目を nil にする）。
- 手順：決勝の入口で2本目に A を選ぶ → 1本目の行を開く → 候補に A が並ぶ → A を選ぶ。2本目の行が「選んでいない」に戻り、本番へ進むと「2本目は選ばずに進む」（StageViews.swift:306）になる。
- 何が起きるか：2本目の選び直しを忘れたまま本番に進む可能性。ルールは守られている（同じネタ2本で減点を免れない）ので、被害は選び忘れだけ。
- 直し案：1本目の行にも `excludeID: session.selectedNeta2?.id` を渡して候補から隠す（表示だけ）。または外れた時に一言出す。

### #6 低｜漢字・英字のコンビ名は読み上げの順が端に固定される
- 場所：FinalistAnnounceView.swift:55-58（自組の読みは `combiName` のひらがな化だけ。漢字名は漢字のまま `<` 比較）、QualifierNoticeView.swift:39-40（同じ）。NPC は全50組が `yomi` 辞書に入っている（FinalsPresentationView.swift:1409-1415 と照合済み）。
- 手順：コンビ名を漢字（例：「東京ヒカリ」）にして準決勝を通過する → 読みは漢字のコードのまま比較され、ひらがなの NPC より常に後ろ＝毎年「最後の2組の溜め」で呼ばれる。英字名なら常に最初に呼ばれる。
- 何が起きるか：「五十音順＝成績の手がかりにしない」（ファイル冒頭）としているが、名前しだいで自組の呼ばれる位置が毎回同じになり、溜めの演出が名前で変わる。成績の手がかりにはならない（通過／落選で読み上げ総数は同じ10）ので害は演出の偏りだけ。
- 直し案：自組の読みを持たない限り根本は直せない＝名前入力に「読み」を足す仕様変更になるので**判断が要る**。安い代替は、漢字・英字の名前は年ごとの決定論で位置を散らす（表示だけ）。

### #7 低｜無名のうちは出さない言い回しが、knownOnly から漏れている
- 場所：FanReportData.swift:127（bandA「常連のおじさんが『今日は〈名〉だな』とつぶやいてた」）・322（bandD「言い終わりが毎回少し弱くて」）。knownOnly（:378-400）には載っていない（`去年`・`いつも`の文は全て載っている）。
- 手順：結成1年目（`isKnown` が false：year>=2 かつ fame>=15 でない）で好成績／不発を取ると、無名の初出場に「常連」「毎回」の文が出うる。
- 何が起きるか：オーナー指摘（10/15「初出場の無名に『いつも通り』」）と同じ型の取りこぼし。
- 直し案：2文を knownOnly に足すか、文を言い換える。文言だけ。

### #8 低｜ログインボーナスの最後の1枚で札が0枚に戻る
- 場所：Store/GachaState.swift:165-166（`loginStamps >= goal` で `-= goal`）、GachaView.swift:85-89（丸の数は `s.loginStamps`）・97（「無料の1回がたまりました」の一言）。
- 手順：札が goal-1 枚の日にもらうと、丸は全部空に戻り、一言だけが出る。満杯の丸の列が一度も画面に出ない。
- 何が起きるか：言葉では伝わるが、「あと1枚」の期待の絵が最後に見えない。
- 直し案：表示だけ（もらった直後は満杯を1.5秒見せる等）。優先度は最低。

---

## 確かめて問題なしだった点（手順を追って確認）
- ShopView：「戻す」は店に入った時の状態から買い直す作りで、部屋の引っ越しは金額を引かない（GameEngine.moveRoom の注記・WeekRunner.replayItemPurchases）ため、`visitStart?.room` の更新とずれない。`roomRents[i]` は既定 `[0, 50_000, 150_000]` で添字は範囲内。購入のたびに `saveNow`。
- GachaView：`run` は `busy` で二重実行を弾く（confirmationDialog 経由も）。`plan!` は `.paid1/.paid10` の枝だけ。天井ゲージは `YoseGauge` が0〜1に丸める。未開封が0なら `pull(count: 0)` で空の結果＝オーバーレイ非表示。
- SettingsView：音量の `@AppStorage` 既定は SoundManager の `object(forKey:) ?? 0.6/0.8` と一致（0を保存しても0.6に戻らない）。ドラッグの `geo.size.width` は0にならない範囲。解散は `abandoned` で以後の保存を止める。
- RadarChart：`cap` は `min(realCap, zoom>=30)` で必ず正＝0割なし。`ActionBreakdownBand` は `1...max(1, weeks)`。`categoryLog` は SaveData に入り、翌年の開始で空に戻る（GameSession.swift:1173）。15年目でも変化なし。
- FanReportData：`salt` の剰余は全て `((x % n) + n) % n` で負でも安全。空の語彙は `ordered` が `guard n > 0`。`isKnown` は `year >= 2` なので15年目でも破綻しない。性別が出る語は「彼氏」（:132・観客の話で全コンビに無害）だけ。
- ShareCard：画像の再生成は `task(id:)` にコンビ名・見出し・detail が入っている（1107b #10 の修正後）。
- QualifierNoticeView：NPC名は50組すべてユニークで `ForEach(id: \.self)` が重ならない。チャットの `msgs` の上限は通過3行・落選2行で添字に収まる。`pickOpen` は `chosen` で、`open()` は stage で二重実行を弾く。
- FinalistAnnounceView：`arr.swapAt(si, count/2 + count/4)` は count=16 で 12（範囲内）。`readOrder` が空でも for は回らない。`skipStep` は pause の終わりで必ず戻る。
- 女性コンビ（{me}/{partner1}）：対象11ファイルに「僕・俺・男」等の固定語は無い。QualifierNoticeView は `partnerName` を差している。FirstStageView の地の文は人称なし。
- 15年目まで伸ばした時の十年固定：対象ファイルの画面文言に「10年」「十年」は無い（FanReportData:115 はコメントだけ）。「今年あと◯回」「年が明けると戻ります」は年数に依らない。

## 推測（コードの行は読んだが、実際に起きるかは未確認）
- FirstStageView.swift:79・129-137：`start()` に QualifierNoticeView のような `guard task == nil` が無い。`.onAppear` が同じ表示で2度呼ばれる状況があると、古い Task が取り消されずに残り、`phase = .ready` の巻き戻しと効果音の重なりが起きうる。現在の呼び出し（IntroFlow の switch 内）では二度呼ばれる経路は見つからなかった。
- GachaView.swift:147-159：購入ダイアログの途中で画面を閉じても Task は走り続け、結果は閉じた画面の @State に入る（害なし）。購入自体は StoreManager 側で付与済みなので、開き直すと「未開封」で回せるはず。
- SettingsView.swift:56：「購入を復元」の Task は画面を閉じても完了まで走る。`restoring` は閉じた画面の @State なので害なし。

## 未確認
- 実機での表示（大きい文字での崩れ・VoiceOver）。コードだけの点検で、シミュレータは使っていない。
- StoreManager.handle／Transaction.updates の中身（1107e #10〜12 で確認済みのため再確認していない）。
