# コード点検 2026-11-18：EndingViews / YoseYearTurnCurtain（読み取り専用）

対象：ManzaiGame/Sources/EndingViews.swift（459行）・ManzaiGame/Sources/Design/YoseYearTurnCurtain.swift（471行）。既存の code_review_* で出た項目は「既知」と付けた。

## 要点3行
1. 15年化の取り残しは無し（「10年」の文言は両ファイルになく、Endings.swift の文言・一枚絵の15行／15冊も十五に揃っている）。クラッシュ級・数値の誤りも見つからず。
2. 新規は「年の幕間で成功の触覚が2回鳴る」（中）と、「年表の一枚絵が決勝に出ていない周でも見本の金縁4・8年目を出す」（中）の2件が中心。ほかは低。
3. 既知：幕間 `.task` の再入、体力100固定、Int.min、reduceMotion 時の触覚、isModal 済み。

## 指摘（重さ順）

### 1. 【中・新規・見た目/触覚のみ】年の幕間で「成功」の触覚が二重に鳴る
- Design/YoseYearTurnCurtain.swift:399（`UINotificationFeedbackGenerator().notificationOccurred(.success)`）と :241 の `YoseStampImpactModifier`（Design/YoseMotion.swift:15-17 の onChange が `stamped` が true になると同じ .success を鳴らす）。
- 場面：1.0秒で `stamped = true` にすると、:399 の直接呼びと modifier の onChange の2発が同時に出る（ぶるっと二度）。reduceMotion 経路（:373）では modifier の1発だけ。
- 直し方：:399 を消して modifier に任せる（RentStatement:107 も同じ modifier なので揃う）。または modifier 側を外す。
- 表示のみ：はい（ゲーム状態に影響しない）。

### 2. 【中・新規・見た目のみ】決勝に出ていない周でも、年表の一枚絵に「見本の金縁（4年目と8年目）」が出る
- EndingViews.swift:64（`finalYears.isEmpty ? EndingArt.sampleGoldRows : finalYears`）・:112-113。
- 場面：#5「十五年分の年表」（tenYearsClose）は「決勝の舞台を知って区切った」ので通常は決勝経験ありだが、図鑑の読み返し（session=nil・:331 付近の fullScreenCover）では yearHistory が無く常に 4・8 年目が金になる。実際に決勝へ出た年とは無関係な見本の年が、読み返しのたびに「自分の記録」のように見える。#5 以外の一枚絵は goldRows を使わないので実害は #5 の読み返しだけ。
- 直し方：読み返し時は金縁なしにする、または EndingRecord に決勝年を保存して使う（保存を増やすなら要設計）。最小は `session == nil` なら `[]`（見本は DEBUG/ギャラリーのサムネだけ）。
- 表示のみ：はい。

### 3. 【低・新規・表示のみ】図鑑の札で相方名が空だと「相方：」だけ出る
- EndingViews.swift:403（`相方：\(rec.lastPartnerName)`）。`lastPartnerName` は :55 で「空なら上書きしない」扱いがあるので空の記録は想定内。
- 場面：古い記録や名前が空のまま記録された場合、「2026/11/18　1回　相方：」で終わる。
- 直し方：空なら「相方：—」か相方の部分ごと省く。
- 表示のみ：はい。

### 4. 【低・新規・VoiceOver】一枚絵（EndingArt）が装飾なのに隠れていない／図鑑の札で読みが長い
- EndingViews.swift:66-69（一枚絵）・:380 付近 `EndingArt(id:)`（図鑑の札）。Shape だけなので読み上げは空だが、`.accessibilityHidden(true)` を明示した方が安全（将来 Text を足したときの漏れ防止）。
- 図鑑の札は `Button` の中身が複数 Text で「No.3」「入手済ラベル」「タイトル」「日付 回数 相方」の4つに別々に読まれ、ボタンの名前が長くなる。`.accessibilityElement(children: .combine)` ＋ label を「No.3 ◯◯、入手済み、N回」にまとめると聞きやすい。
- 直し方：上のとおり。見た目は変わらない。
- 表示のみ：はい。

### 5. 【低・新規・表示のみ】幕間のめくり札：前年の札が回転ではなく「0.2秒遅れで一瞬で消える」
- Design/YoseYearTurnCurtain.swift:225-227。`.animation(Theme.Motion.r(.linear(duration: 0.01).delay(...)), value: mekuriFlipped)` が、:389 の `withAnimation(spring…)` より内側で効くので、回転も不透明度も 0.01 秒（遅延 0.2 秒）で終わる。コメントは「パタン」と書くが実際は 0.78 秒の触覚・火花・揺れの0.2秒後に札が消える。
- 影響：意図が「札がめくれる」ならバネの動きが出ていない。意図が「火花と同時」なら遅延はなくてよい。見た目の好み判断のため要確認。
- 直し方：`.animation` を外して withAnimation のバネに任せる（遅延なし）。
- 表示のみ：はい。

### 6. 【低・新規】「もう一度 ▶」「とじる」の連打で onFinish が2回呼ばれる
- EndingViews.swift:97（`Button(action: onFinish)`）。呼び出し側 RootView.swift:423-425 は `returnToTitle()` を毎回呼び、`GameSession()` を2回作って1個目を捨てる（Sound.stopBGM と showEnding=false も2回）。ログ・保存への副作用は見当たらない。
- 直し方：EndingFlowView に `@State finished` を持ち、onFinish の前でガード。
- 表示のみ：ほぼ。保存を壊さないので実害は小さい。

### 7. 【低・要確認】`cards` が計算プロパティで、body のたびに別の UUID の配列を作る
- EndingViews.swift:24（`ending.cards(...)`）→ :38。`ReminiscenceCard.id` は `UUID()`（IntroFlow.swift:18）。session の別プロパティ変化で EndingFlowView の body が再評価されると、ReminiscencePlayer に毎回新しい配列が渡る。Player が `ForEach(cards)` を id で回す作りなら、場面の途中で絵が組み直される（index は @State なので位置は保たれる）。
- 実機で場面の再描画ちらつきが見えるかは未確認。session は ending 表示中ほぼ変化しないので当面は低。
- 直し方：`@State` に1回だけ作って持つ。
- 表示のみ：はい。

### 8. 【低・要確認】replay の相方名／コンビ形の差し替えは最初の onAppear だけ
- EndingViews.swift:43-55・:57-59。`recorded` ガードのため、fullScreenCover の中で一度 onDisappear（アプリの切替など）が走ると復元済みで、再 onAppear では再適用されない。図鑑の読み返しの途中でシステムの共有シートを出しても親の onDisappear は通常走らないので、当面は問題なし。
- 直し方：必要なら `replayRestore` の有無で再適用の可否を分ける。
- 表示のみ：はい（Names はグローバルなので、復元漏れは保存に影響するか別途見るとよい）。

## 既知（再掲）
- 幕間の `.task` が出入りで再入すると演出を頭から再実行する：既知（code_review_curtain_fan_1117_v0.md 表の要確認 :139-141）。
- 体力「100/100 全回復」が固定値：既知（code_review_2026-10-19l.md 付随・RootView:406 で config.initStamina を渡す形に直っている）。
- `compactYen` の Int.min：既知（実害なし）。`kanjiNumber` の負数・20以上：既知（安全）。
- reduceMotion 時も `.success` の触覚が鳴る：既知（19l 8。許容）。
- 幕間に isModal：付与済み（:138）。
- Task.sleep の取り消し検知：済み（`pause` の戻り値）。タイマー／asyncAfter／Task の取り残しは両ファイルに無し。
- EndingViews の `EndingBook.record` は onAppear の1回（`recorded` ガード）：既知（code_review_note_end_1117）。
- `withAnimation` はすべて `Theme.Motion.r` 経由（reduceMotion 対応済み）。幕間の火花は YoseBurstParticles 側で reduceMotion を見ている。

## 確認して問題なしだった所
- 「10年」「十年」の文字列は両ファイルに無し。一枚絵 #3（ノート十五冊・最後の1冊だけ薄い）・#5（年表15行 `1...15`）は 15 年と一致。#4 の12マスは月。
- `ForEach(0..<n)` は全て定数範囲（15・12・9・2・26・7・18・5・14）。縮む配列で添字アクセスなし。
- `colors[i % 4]`／`colors[idx % colors.count]` は剰余で範囲内。`kanjiNumber` は `d[n-10]`（11〜19）で範囲内。
- 年の表示：`newYear = session.year + 1`。`careerOver` のとき `onNextYear` は nil（RootView:431）なので 16年目の幕間は出ない。
- 図鑑の分数 `\(seen.count) / \(EndingID.allCases.count)` は一致。
