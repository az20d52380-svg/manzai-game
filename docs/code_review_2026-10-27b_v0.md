# コード点検 2026-10-27b（今日のアプリ変更＋読み上げ候補ブランチ）

**まとめ**
1. 今日のアプリ変更（ff36663 / 552a9a3 / 9044306 / de4e6d9。範囲 136dd77..HEAD）に高・中の不具合なし。境界（所持金ちょうど2か月分）もテストで押さえてある。
2. 候補ブランチ `claude/a11y-tap-next-cand`（9ファイル）は、`accessibilityAction` が onTapGesture と同じ関数を呼ぶ形で、StageFrame・FinalsBroadcastIntro・YoseRankUpOverlay・ChoiceEventOverlay は関数内ガード（done / isDismissed / hasMore）を通る＝素通りなし。ただし関数内ガードが無い所（二度押し連打）が3つあり、中。
3. 高 0／中 3／低 5。推測は「推測」と明記。実機 VoiceOver での確認は未実施。

| # | ファイル:行 | 何が | 直し方の案 | 重さ |
|---|---|---|---|---|
| 1 | cand: TournamentResultView.swift `climaxNext`（約549）／onTapGesture・accessibilityAction（約574-575） | 最後のページで `session.acknowledgeResult()` を直に呼ぶ。ガード（`climaxIndex` を nil にする・連打弾き）が無く、読み上げの二度押しや連打で2回呼ばれ、次の画面を1つ飛ばす恐れ（推測：acknowledgeResult 側が冪等かは未確認）。同じ画面の他のタップは tapAccepted()／nextArmed で守っているのに、ここだけ無い。タップ側も同じなので今回の追加で新しく生えた穴ではないが、読み上げは連打しやすい。 | `climaxNext` 冒頭で `guard tapAccepted()`（または専用の `climaxArmed`）を通し、最後のページは呼んだ直後に `climaxIndex = nil` か完了フラグで二重呼びを止める。 | 中 |
| 2 | cand: Design/YoseChampionCelebrationView.swift:533 `handleScreenTap`（action は :173） | 完成後は `onFinish()` を毎回呼ぶ。`isCompleted` 後に二度押し/連打すると onFinish が複数回（呼び先が冪等でなければ次画面を飛ばす・推測）。 | `finished` フラグを足して2回目以降は無視。 | 中 |
| 3 | cand: Design/YoseMilestoneFX.swift:146-147 | `finished` 後の連打で `onFinish()` が複数回。`snapToFinal` は `done=true` を立てるが、onFinish 側にガードが無い。 | #2 と同じ（一度きりフラグ）。 | 中 |
| 4 | cand: IntroFlow.swift `nextCard`（約86-94） | 最後のカードで `onComplete()` が連打で複数回。カード0枚でも即 onComplete（これは良い）。 | 完了フラグで一度きりに。 | 低 |
| 5 | cand: S6bView.swift:198 | 既存の書き損じ：`Text("タップで進む")…// 12pt 未満は使わない…（TypeStep の決まり）.padding(.bottom, Theme.Sp.s24)` の `.padding` がコメントの中に入って効いていない。下の余白が付かず、画面下端に詰まる。大きい文字で他の要素と近づく恐れ。今回のブランチの差分ではないが、同じ行の隣を触っているので拾う。 | コメントを行末の外へ出して `.padding(.bottom, Theme.Sp.s24)` を効かせる（見た目が変わるので目視要）。 | 低 |
| 6 | cand: TournamentResultView.swift:201,236 | 「判」前の溜めと判のあとの全画面透明タップ（tapAccepted で守る）は `accessibilityHidden(true)`＋action なし。読み上げ利用者は演出を飛ばす手段がなく、自動で進むのを待つだけになる（飛ばしたい人には不便。誤って飛ばさない利点もある）。 | 意図なら据え置き。飛ばせるようにするなら tapAccepted() を通した action を足す（飛ばし先の関数は同じ）。 | 低 |
| 7 | cand: 全9ファイル（全画面の `accessibilityAction`） | 推測：名前なしの action を、子に Text が多い全画面コンテナに付けた時、VoiceOver がそのコンテナを1つの要素として拾うか（Text ごとに読むか）は実機で未確認。ChoiceEventOverlay は子に選択肢ボタンもあり、コンテナ側の action と子の操作が競合しないかも要確認。 | 実機 VoiceOver で「二度押しで進む」を1画面ずつ確認。必要なら `.accessibilityElement(children: .contain)` や名前付き（`accessibilityAction(named: "次へ")`）に。 | 低 |
| 8 | main: WeekHint.swift:51 | 境界：`money < livingCost*2` ＝ちょうど2か月分は予告なし（テスト testLivingForecast が 280,000 で nil を確認）。意図どおり。ただし `livingCost / 10_000` は整数除算で、万円で割り切れない生活費だと端数が落ちる（今は14万円で影響なし。既存）。 | 現状は不要。生活費を変える時に注意。 | 低 |

## 見た範囲で問題なしと判断した点
- **de4e6d9**（判子記号・＋－記号を `accessibilityHidden(true)`）：`.accessibilityHidden` を `.font` の直後、`.foregroundStyle` の前に付けているが、View 修飾の順序はどれでも効く。ボタン側に `accessibilityLabel` があるので読み上げは失われない。
- **552a9a3**：`livingInTwoWeeks` を使うのは WeekMainView:506 の1か所だけ。他の呼び元が money を渡し忘れる恐れなし。テスト2か所は money を明示済み（優先順テストも 200,000 で予告が先に出る）。
- **9044306**：用語集の「コンビ」「持ちネタ」「勝負ネタにする」は、WeekMainView:1387（フッター「コンビ」）と NotebookView:350 に実在。画面名と一致。ただしコメント・RadarChart のヘッダに旧称「ネタ帳」が残る（表示ではない）。
- **ff36663**：追加の一文は `gothic(12)`＝`mzScaled` なので大きい文字に追従し、`fixedSize(horizontal:false, vertical:true)` で縦に伸びる＝切れない。3つの合計が並ぶ HStack は変更なし。VStack を `.leading` にしたので文は左寄せ（見た目の確認は未実施）。
- 候補ブランチの各ガード照合：StageFrame（`allowsHitTesting(!done)` はタップだけを止めるが、action 先の `finish()` が `guard !done`）／FinalsBroadcastIntro（`advanceStage` が `guard !done`）／YoseRankUpOverlay（`isDismissed`）／ChoiceEventOverlay（`hasMore`・footerReady）／S6bView（`advance(.wall)` は冪等）。いずれも素通りしても二重に進まない。

## 親の確認（10/27 定期）＝中3件とも実害なし
- climaxNext：`GameSession.acknowledgeResult()` は先頭で `guard pendingResult != nil` ＝2回目は何もしない（GameSession.swift:957）。
- YoseChampionCelebrationView の onFinish：呼び手（FinalsPresentationView.swift:219）は `showChamp = false`・`endingFull = …`・`showEnding = true` の代入だけ＝2回呼んでも同じ状態。
- YoseMilestoneFX：本編の呼び手なし（DEBUG の演出5つ＝キュー88・本編接続はオーナー確認待ち）。本編へつなぐ時に onFinish の二重呼びを見る。
- 低#4（IntroFlow の最後のカードの連打）：呼び先は RootView.swift:347 の `session = GameSession(…)`＋`started = true`＝2回目は始まる前の session を作り直すだけ（1週目を見る前なので乱数の種が変わっても見えない）＝実害なし。
- 低#5 済（エンディングの「タップで進む」の余白）。
