# 配列の添字・force unwrap 落ち監査（静的・2026-11-08・v0）

範囲：ManzaiGame/Sources 全体（ForEach 98 件・`xs[i]` 系の添字 約170 行・`.first!/.last!/[0]`）。直していない。
結論：**確実に落ちる箇所は 0 件**。7a2ae712 と同型（変わりうる配列を `0..<count` の添字で後から引く）は、現状 WeekMainView の直した1か所のみ。条件付きの注意が2件。

## 危ない（落ちうる筋書き付き）＝条件付き・低

1. TournamentResultView.swift:52 `summary.results.last!`
   筋書き：`summary.results` が空の WeekSummary がこの画面に渡ると即クラッシュ。守りは「GameSession.pump() の `!big.isEmpty` ガード」というコメント上の不変条件だけで、型・コードでは守られていない。pump() 以外の経路（DEBUG フック・セーブ復元・将来の呼び出し）で空が届けば落ちる。対策案：`guard let` でフォールバック表示（直さず記録のみ）。
2. IntroFlow.swift:48 `cards[safe: index] ?? cards[0]`
   筋書き：`cards` が空配列で渡されると cards[0] で落ちる。呼び出しは `meeting.cards`（MeetingKind 固定リテラル）なので今は空にならない＝将来 cards を設定/データ由来にした時の地雷。

## たぶん安全（理由）

- WeekMainView.swift:144 `activeOffer`：`offers.indices.contains(offerPick)` で守り済み。:872 は 7a2ae712 で `enumerated()` 渡しに修正済み（i は札の描画に渡すだけで再び offers[i] を引かない）。:858 `chooseOffer(index:)` → WeekRunner.swift:483 で `c.indices.contains(index)` ガード。:321 で週替わりに offerPick=0。
- WeekMainView.swift:609-610 `banterBox`：`lines.count - 1` は呼び出し側 :389 が `!lines.isEmpty` を確認済み。banterIndex は min で丸め。
- WeekMainView.swift:1050 `roomHeals[room]`：`room < count` を確認済み。
- ShopView.swift:97-119 `roomRents[i]`：i は static roomNames(3) の範囲。roomRents は GameConfig 既定 [0,50000,150000]（3要素）で件数一致（GameEngine 側は count ガード付き）。config を差し替えて roomRents を短くすると落ちるが、固定値。
- ShopView.swift:198 `purchases.remove(at:)`：直前の `lastIndex(of:)` の結果。
- S6bView.swift:87,151 `venueNames[t / venueTier]`：4要素固定・venueTier は 0〜3 のみ返す。
- NetaStage.swift:32,38 `names[idx]`：idx は index() が 0〜3 を返す（names 4要素）。
- NetaCatalog.swift:56 `names[i]`：剰余で正規化済み（names が空でない限り）。
- QualifierNoticeView.swift:168-169：`0..<max(0, msgs-2)` ＋ `if i < resultLines.count` で守り済み。:77 も `n - 3 < resultLines.count`。
- FinalsBroadcastIntro.swift:185,207,233 `judges[i/cur]`：judges は private let の7要素固定。cur = min(step,7)-1 で `cur >= 0` ガードあり。:379 `finalists[i]` は `0..<finalists.count`（let）。
- FinalistAnnounceView.swift:223-229 `order[i]`：`let order = readOrder` を一度だけ取ってその count でループ（ループ中に変わらない）。
- FinalsPresentationView.swift：`d.entries[shown-1]`（:472 は `shown < d.entries.count` ガード後、:263 は min、:605/607/967/969 は shown>0 確認）、`d.judges[0..<7]`（FinalsData は審査員7固定・:857 は `min(7, count)` だが下限4なので count<4 だと Range 不正になる＝7固定のため現状到達不能）、`counts[k]`（0..<3 固定）、`d.voteOrder[i]`（0..<7 固定）、`names[...]` は `names.count > k` ガード付き。`d` は `dataCache ?? makeData()` の計算プロパティで、makeData が非決定だと呼び出しごとに件数が変わる余地があるが、年・名簿から決定論（:1201）。
- FinalsPresentationView.swift:1307-1361 `duelScores/votes[...]`：0..<7・3組の固定サイズ配列。
- FinalsPresentationView.swift:675-676 `seats[rank]`：`rank < seats.count` ガード。:811 `picks[i]`：`picks.indices.contains(i)` ガード。:488 `d.judges[revealedJudges-1]`：indices.contains ガード。
- TournamentResultView.swift:413 `names[i]`（3要素・0..<3）、:464 `level(k)` は配列を引かない。
- IntroFlow.swift:69-70 `lines[i]`：`lines.indices` 由来で、同じ body 内で作った let lines を引く（描き直し間でずれない）。:113 RecallPageMark・:478-482 `Self.crowd[i]`（static let）。:658 `MeetingKind.allCases[i]` は enumerated の添字。
- Design/YoseGameParts.swift:134-173 `tabs[idx]/items[idx]`：どちらも `let` を `.indices` で回す（同一インスタンス内で不変）。`selectedIndex` は比較にしか使わない。
- ChoiceEventOverlay.swift:55-57 `chunkEnd`：`shown < items.count` ガード＋`end < items.count`。
- GameSession.swift:630 `candidates[idx]`：isEmpty ガード＋min で丸め。:125-131 `s.idx < count` で確認。:710-712 `gpRoundsPassed..<gpRounds.count`：isGPAlive（= gpStage < count、:732 と同条件）下のみ。範囲の下限>上限で落ちる形だが守られている。
- FanReportData.swift:455 `lines[lines.count-1]`：`lines.count >= 2` ガード内。
- Theme.swift:138-139 / AbilityUpView.swift:425：`lastIndex` の結果＋`i + 1 < count` ガード。
- YoseYearTurnCurtain.swift:425 `d[n-10]`：n は 10〜19 の分岐内・d は10要素。:424 `d[max(0,n)]` は n<10 分岐。
- MeetingKind.swift:27：`allCases.indices.contains(n-1)` ガード（DEBUG のみ）。
- RentStatement.swift:35-36 `lines[0]`：`!lines.isEmpty` ガード。
- Meta.swift:129 / GameSession.swift:230,1118：`count` 確認後の [0][1][2]。
- RadarChart.swift:96-116 `axes[i]`：axes を一度作って同じ Canvas 内で `i` を回す（axes.count ベース）。:59 `current[a]` は Ability をキーにした辞書/subscript（配列でない）。
- ForEach の `0..<固定数`（S6b・EndingViews・EventBackgrounds・YoseEffects など 80 件超）：リテラル範囲で中身も装飾描画のみ。`EventBackgrounds.swift:481 dots` は引数の整数で配列を引かない。:405 `hs[i]` は同ファイル内のリテラル配列（EventBackgrounds 398-405 周辺）。
- `Array(xs.enumerated())` 型の ForEach（AbilityUpView・NotebookView・ChoiceEventOverlay・TournamentResultView:222 `fanVoices.prefix(fanShown)` ほか）：要素ごと渡す形で、中で再度 `xs[i]` を引いていない（grep で `xs[i]` の再引きは検出されず）。
- `(…)[ ]` 形の組み合わせ（④ `Array(xs.prefix(n))[k]`）：該当なし。`.first!` 該当なし（`.last!` は上記1件のみ）。

## 方法メモ
grep：`ForEach\(\s*(0\.\.<|\S+\.indices|Array\()`、`\.first!|\.last!|\w\[0\]`、`[a-zA-Z_)]\[[a-z][...]\]`（添字が変数のもの171行）、`removeFirst|remove\(at|\.max\(\)!|count - 1\]`。EventBackgrounds の装飾は固定リテラルのため詳細は読まず。GameCore（Sources 外）は対象外だが WeekRunner.chooseOffer のみ確認。
