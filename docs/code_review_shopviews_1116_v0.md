# コード点検：お店・ガチャ・予選の知らせ（2026-11-16・v0・コード変更なし）

対象：ManzaiGame/Sources の QualifierNoticeView.swift・GachaView.swift・ShopView.swift（呼び先：GameSession.buyItem／moveRoom／replayShopVisit、GameCore の Item.swift・GameEngine.canMoveRoom、Store/GachaStore・GachaState・StoreManager）。

## §1 要約
- 高0・中0・低4・要確認3。お金・券・アイテムの二重付与／二重消費、残高が負になる経路、ForEach の添字ずれ、onAppear の二重発火、`//` の後ろに消えた修飾子は、見つからなかった。
- 一番重いのは低-1（ガチャ画面を購入中に閉じると、買った分は回って衣装も入るが結果の画面が出ない）。お金の損得は出ない。
- 過去の監査（storekit_edge_audit_1108・costume_audit_1115・shop_audit_1115・softlock_audit_1115 ほか）で出尽くしている所が多く、新規は小粒。

## §2 指摘

### 低-1 購入の待ち中に画面を閉じると、結果の画面が出ない（重さ 低・確信度 中）
- 場所：GachaView.swift:156-157（`await store.purchase` の後に `results = gacha.pull(...)`）・:34（ヘッダの閉じるは `.disabled(busy)` の外）。softlock_audit_1115 は「閉じられて出られる」を意図どおりと記録済みだが、結果が出ない点は未記載。
- 起きる条件：商品が読めていない状態（オフライン起動後など）で「回す」を押す→`purchase` 内の `refresh()` を待つ間に「とじる」→お店へ戻る→その後に購入シートが立ち、購入が通る。
- 結果：券は付き、`pull` も走る（衣装・かけら・天井は進む）が、`results` を見せる画面はもう無い。課金したのに「何が出たか」を見られない。
- 直し方の案：`busy` 中は閉じるを無効にする（`YoseHeaderBar` に渡す closeAction を `busy ? nil : onClose` にするか、閉じた時に `busy` なら何もしない）。または購入後の `pull` を画面の生死に関係なく走らせ、結果は GachaStore に「直近の結果」として持たせて次に開いた時に出す。

### 低-2 予選の一覧：タップで先に進めた時に、成功音と触覚が3.2秒後に遅れて鳴る（重さ 低・確信度 高）
- 場所：QualifierNoticeView.swift:159（タップで `scanned = true`、音なし）／:240-243（自動のタイマーが 3.2秒後に `scanned = true`＋`Sound.play(.success)`＋`Haptics.rare()`）。タイマーは `scanned` が既に true でも止まらない。
- 起きる条件：通過の回で、一覧が出てすぐ画面をタップして先に進める。
- 結果：自組の名前が光った後に、時間をおいて成功音が鳴る。タップで進めた人には音が出ず、待った人にだけ出る不揃い。落選は音なしなので影響なし。
- 直し方の案：音と触覚を `scanned` の変わり目（onChange）に移す＝どちらの経路でも1回だけ鳴る。タイマー側は `guard !scanned`。

### 低-3 お店の「購入」ボタンの読み上げに品名が入らない（重さ 低・確信度 中）
- 場所：ShopView.swift:170-179（ボタンの中身は「購入」「¥3,000」の2つだけ）、:184-186（「戻す（n個）」も品名なし）。
- 起きる条件：VoiceOver のローターで「ボタン」だけを順に回す／ボタンへ直接移動する。品名の Text は隣の別要素なので、順に読む時は隣り合うが、ボタン一覧では「購入、3,000円」が9行並び区別できない。a11y_check_1026_voiceover_v0 は「ShopView は個別に読んでいない」と書いており、既出なし。
- 直し方の案：`.accessibilityLabel("\(item.rawValue)を買う、\(price(item).formatted())円")`、戻すは `"\(item.rawValue)を戻す"`。

### 低-4 かけら・天井の交換の結果が VoiceOver に伝わらない（重さ 低・確信度 中）
- 場所：GachaView.swift:64・:67（`_ = gacha.exchangeShards`／`exchangePity`、結果の知らせなし）。
- 起きる条件：VoiceOver で交換した時。札が「？」から衣装に変わり「交換できる」の字が消えるだけで、読み上げの知らせが無い（ログインの札にはある：:99）。
- 直し方の案：交換が通ったら `UIAccessibility.post(.announcement, "「◯◯」を交換しました")`。

## §要確認
- 確認-1 `run(.free)` は券の残りを確かめずに `pull(count: 1)`（GachaView.swift:152-153）。確認の窓（「無料券を1回分使って回します」）を開いたまま iCloud 合流で `freeTickets` が 0 に下がると、`pullOne` が有料の未開封券を使う（表示は「無料」）。窓を開く間に合流が来る必要があり、実機での再現は未確認。直し案：`.free` は `gacha.state.freeTickets > 0` の時だけ回す。
- 確認-2 確認窓の「提供割合を見る」（GachaView.swift:57）は、窓が閉じる動きと同じ瞬間に `fullScreenCover` を開く。iOS のバージョンによっては提示が落ちる既知の癖がある。実機・シミュレータで押して開くか未確認（コードだけでは判定不能）。落ちるなら `DispatchQueue.main.async` か窓を閉じた後に開く。
- 確認-3 予選の一覧の `.accessibilityAction(named: "次へ")`（QualifierNoticeView.swift:160）は、アクセシビリティ要素でない container に付いている。VoiceOver の操作一覧に出るか未確認。出なくても 3.2秒後に自動で先へ進むので詰まりはしない。

## §既知（重ねない）
- 無料券を持ったまま有料を買うと無料券を先に使う、「未開封のN回を回す」でも同じ＝storekit_edge_audit_1108 #15・costume_audit_1115 §2・code_review_2026-11-09 #1。
- iCloud 合流で開封回数を max／台帳は和集合＝code_review_unreviewed_1115 #1・storekit_edge_audit_1108 #17。
- 未検証（unverified）の券購入が黙って失敗する＝storekit_edge_audit_1108 #10（GachaView 側は `purchase` が false で黙って戻る）。承認待ちの案内が出ない件＝#12。返金済みの券は回収しない＝#6。
- ログインボーナスの日付前進・時差・0時またぎ＝costume_audit_1115 #4。`_set` 行の本番残り＝storekit_edge_audit_1108 #18。
- 引っ越し後の「戻す」で部屋が戻る件は修正済み（ShopView.swift:134 `visitStart?.room = ...`＝code_review_2026-10-19 §1-1）。

## §3 見て問題なしの所
- お金：`GameEngine.canBuy` が所持金・回数・持ち越しを見て、`buy` が `canBuy` を通ってから引く＝残高は負にならない。`buyItem` は同期で、連打しても2回目の `canBuy` で弾かれる。引っ越し（`moveRoom`）はお金を引かないので、「戻す」との組み合わせでお金が増減する経路も無い。
- 「戻す」：`replayItemPurchases` は店に入った時の状態から残りを順に買い直す。買い直しはお金も所持も増える側へ単調なので、途中で買えなくなる並びは作れない。引っ越しは起点の部屋を更新済み。
- 表示と実際：「あと ¥(家賃−所持金)」は `canMoveRoom` が false の時だけ（＝上げる時で所持金不足の時だけ）出るので、負の額にならない。`limitText` の「今年あと」「持っている」「のこりN回」は `canBuy` の条件と同じ項目を見ている。
- ガチャ：`pull` は `0..<count` で count は 0 以上のみ。購入の付与は取引IDの台帳で冪等（購入側と `Transaction.updates` の両方が同じ取引を処理しても二重にならない）。`busy` は同期で立つ＋`.disabled(busy)`。`pullOne` は券が無ければ nil（残高は負にならない）。交換は `canExchange…` を通ってから引く。`exchangeTarget` の窓は2回押しても2回目で弾かれる。
- ForEach：QualifierNoticeView の `ForEach(0..<max(0, msgs - 2))`＋`resultLines[i]` は msgs が増えるだけで、`i < count` の確認もある。ShopView の `0..<roomNames.count` は定数。GachaView の結果は `Array(results.enumerated())`（結果は丸ごと入れ替え）で添字ずれなし。一覧の組名（`npcNames` 50件）に重複なし、自組の名前は除外済みで `id: \.self` は衝突しない。
- onAppear：QualifierNoticeView は `task == nil` ガード、ShopView は `visitStart == nil` ガード（GachaView を閉じて戻っても1回）。`onFinish` は呼び先（TournamentResultView:280）が `qualDone = true` だけなので、連打で二重に呼ばれても害なし。
- `//` の後ろの修飾子：3ファイルとも、行の途中に `//` があって後ろに修飾子が続く行は無し（行末コメントのみ）。
- VoiceOver：ガチャの衣装札・結果札・天井・ログインの札の読み上げ名は見た目の字と一致（レア度・名前・「交換できる」「広告カット付き」）。予選の通知・一覧・吹き出しも見た目と一致。
