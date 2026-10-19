# コード点検 2026-10-19i（エンディングまわり・8回目）

読み取り専用。対象：EndingFlowView / EndingViews / Endings（判定・EndingBook）/ S6bView / GameSession の endingID・careerOver・saveNow・returnToTitle / RootView の出口。
件数：2件（確度 高 0・中 2）。既出（-19・b〜h）は除いた。

## §1 確度 高
なし。

## §2 確度 中

1. **GameSession.swift:1120〜1122 `saveNow`（＋ Endings.swift:EndingBook.record は EndingViews.swift:51 の onAppear でだけ呼ぶ）** — 区切りの年末でセーブが先に消え、エンディングを見る前に落ちると、周も図鑑の記録も失われる
   - 手順：10年満了／夜逃げ／解散／優勝（`acknowledgeWin` 後）で `finished && careerOver` になる → その場で `saveNow()` がセーブを削除 → 年末リザルト（YearResultView）で「エンディングへ」を押す前にアプリを終了（OS による破棄を含む）→ 再起動するとセーブ無しでタイトル。そのエンディングは図鑑に載らない（記録は EndingFlowView の onAppear＝エンディングに入った時点で初めて書かれる）。
   - 直し案：セーブの削除を `returnToTitle()`（エンディング出口）側へ移すか、`finished && careerOver` になった時点で `EndingBook.record` を先に書く（その場合 EndingFlowView の onAppear 記録は外す＝二重記録に注意）。
   - 確度：中（セーブ削除は意図的な設計コメントあり。記録漏れ・無言でのキャリア喪失という結果だけが実害）

2. **NetaStage.swift:13 `static var lastSeen`（check は :43〜48）** — 前の周のネタの段が次の周に残り、札が誤って光る／光らない
   - 手順：1周目で neta.id=5 を「仕上がった(3)」まで育てる → エンディング→「もう一度」→ 新しい周でも同じ id のネタを作る（id は周ごとに振り直される）→ `lastSeen[5]` に前の周の 3 が残っているため、新しい周で段が上がっても `idx > prev` にならず光らない。逆に前の周の値が低いと、新しい周で最初に見た時点で上がった扱いで光る。`GameSession()` の init（Names.set など）は lastSeen を触らない。表示のみで勝敗・乱数には影響しない。
   - 直し案：`returnToTitle()` と `onChange(of: session.abandoned)` で `NetaStage.lastSeen = [:]`（または GameSession の init で消す）。
   - 確度：中

## §3 見たが問題なかった所

- 判定：`EndingID.judge` は bankrupt→dissolved→champion→(careerYears 未満は nil)→決勝回数×相性の順。GameCore 側で夜逃げ・解散の年は `champion:false` で作られる（WeekRunner:399/404）ので、優勝と夜逃げ／解散の同時成立（取り違え）は起きない。`careerOver`（`GameSession.swift:976`）と `judge` の「区切り」の条件は一致。10年満了の年に優勝すれば #7/#8 が優先され、仕様どおり。
- 決勝回数：`yearHistory` にはその年の分が `pump` の `.yearDone` で先に積まれ（`last?.year != runner.year` で二重積みなし）、`endingID` はその後に評価される＝仕様の「その年の分を含めて数える」どおり。客席で観た決勝は数えない（仕様 `reachedFinal` どおり）。
- 図鑑の二重記録：`EndingFlowView` の `recorded` で onAppear の再入を防止。RootView の分岐（`session.finished`→`showEnding`）は流れの途中で構造が変わらず、View が作り直されない。読み返し（`replay=true`）と DEBUG 直行（`record=false`）は記録しない。#7（`championRetire`）は S6b の後に一枚絵を通らず `onFinish()` するが、記録は入口で済んでいるので漏れない。
- 配列の範囲外・強制アンラップ：`ReminiscencePlayer` の `cards[0]` は呼び側（EndingFlowView の `cards.isEmpty` 除外・S6b の固定3枚）で空にならない。`Self.venueNames[venueTier]` は 0〜3 に収まる。S6b の年表 `ForEach(id: \.year)` は年が一意。
- 新周回：`returnToTitle()` は BGM 停止・`showEnding=false`・`GameSession()` の作り直し（init で `Names.set(nil,nil)`）で、`yearTurn` は出口で既に nil。セーブは区切りの時点で削除済み（上の 1 を除き残りなし）。
- 二重タップ：場面カード最後の onComplete／S6b の `advance`／「もう一度」の `returnToTitle` が2回走っても、go(.art) の重複と GameSession の作り直しが2回になるだけで害なし。
- 閉じた後に走る Task：EndingViews・S6bView・Endings に `Task`／`asyncAfter` は無い（`withAnimation(.delay)` のみ）。RootView の `soakLoop` の sleep は DEBUG 限定。
- EndingBook の保存：1要素でも読めないと全体が `[:]` になり次の record で上書きされる作りだが、現状 `EndingRecord` のスキーマは変わっておらず実害なし（将来項目を足す時は `decodeIfPresent` に）。

## 扱い（10/19 自走）
- §2 直した（returnToTitle で NetaStage.lastSeen を空に）。
- §1（年末で落ちると図鑑の記録とセーブが消える）は直し方に判断が要る：セーブを消すのをエンディングに入るまで遅らせる（復元の経路が増える）か、年末の時点で図鑑に記録する（エンディング画面の記録と二重にならない印が要る）。起きるのは区切りの年末で落ちた時だけ → AUTOPILOT キュー117。
