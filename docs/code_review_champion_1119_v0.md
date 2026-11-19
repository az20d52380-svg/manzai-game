# 優勝演出 コード点検（YoseChampionCelebrationView）2026-11-19 v0

対象: ManzaiGame/Sources/Design/YoseChampionCelebrationView.swift（1015行）。読み取りのみ・コード変更なし。
呼び出し元: FinalsPresentationView.swift:218 / TournamentResultView.swift:303 / YoseFXPreview.swift:36。
既出で除外: 字間空白見出しの読み上げ名(1366c752a)、THE HANA ボタン文言(5ba7c0282)、code_review_1116_cands.md:36 の同件。

## §1 要約
- 高 0 / 中 4 / 低 4 / 要確認 2
- 落ちる穴（範囲外・除算0・NaN）: なし。ループは固定定数、`size.height` 除算系は totalH=height+80 で 0 にならない。
- 遅延コールバック: 5本の asyncAfter はすべて `!isCompleted, !isGone` で守られ、Canvas の `.task` の sleep は画面を閉じると自動で取り消される。問題なし。
- 参照0の部品: なし（Ornament/Signboard系・Seal・3つのCanvas すべて使用）。
- 視差を減らす: アニメは Theme.Motion.r 経由、Canvas 3種は reduceMotion で pause、onAppear で即完成。良好。

## §2 指摘

1. 【中】VoiceOver：『優』『勝』が9回ずつ読まれる — YoseChampionCelebrationView.swift:564-596（ChampionKanjiSeal）
   縁取り用の Text が8枚＋本体1枚、どれも hidden でない。「優」×9、「勝」×9 と読まれる。
   直し: 縁取り8枚（ForEach 部分）に `.accessibilityHidden(true)`、ZStack 全体は `.accessibilityElement(children: .ignore)` ＋ `.accessibilityLabel(kanji)`（または「優勝」を1要素にまとめ、片方を hidden）。表示のみ。

2. 【中】VoiceOver：演出中に見えない「次へ」ボタンが操作できる — :140-152 / :446-462
   下部ブロック（相方・テロップ・ボタン）は opacity 0 と allowsHitTesting(false) だけで、アクセシビリティツリーには残る。VO のダブルタップは hit-testing を通らないため、演出途中に onFinish が走り得る（スキップの意図とは別経路）。
   直し: `.accessibilityHidden(phase < 5)` を追加。表示のみ。

3. 【中】VoiceOver：全画面タップに名前・trait がない — :175-177（onTapGesture）、:213-221（右上「スキップ ▶▶」「タップで進む ▶」）
   全画面 contentShape＋onTapGesture は VO では要素にならず、スキップ手段が右上の Text（ボタンでない）を読むだけ。「▶▶」も記号として読まれる。
   直し: 右上テキストを Button にする（or `.accessibilityAddTraits(.isButton)`＋accessibilityAction で handleScreenTap）。ラベルは「スキップ」「次へ進む」。▶記号は hidden。表示のみ。

4. 【中】文字拡大で切れる — :333 付近 `.frame(height: 256)`（看板）、:218 `.frame(height: 40)`（ヘッダー）、:455 `.frame(height: 46)`（進むボタン）
   mzScaled は最大1.35倍。看板は『優勝』92pt→約124pt＋大会名ラベルの折り返しで内容が256ptを超え、clipShape で下端が切れる。ヘッダー40ptは「スキップ ▶▶」に lineLimit/縮小がなく折り返しで切れる。進むボタンは proceedLabel が長いと2行で46ptに収まらない。
   直し: 固定高さを `minHeight` に、ヘッダー・ボタン文言に `.lineLimit(1).minimumScaleFactor(0.7)`、看板は内側を `ViewThatFits` か Seal 92pt を縮小許容に。表示のみ（要目視）。

5. 【低】onFinish の二重発火ガードが部品内にない — :536-546 / :446
   完成後の連打で onFinish が2回呼ばれ得る。現在の呼び出し元：TournamentResultView 側は acknowledgeResult が pendingResult で守られ無害。FinalsPresentationView 側は showEnding=true の2回代入で実害は小さいが、フェード中(0.3秒)に再タップ可能。
   直し: `@State private var didFinish` を足し、handleScreenTap/Button の両方で一度だけ通す。表示のみ。

6. 【低】mcComment の `lineLimit(2)` — :431
   大きい文字で3行以上になる MC コメントが末尾切れ（VO は全文を読む）。直し: 行数を3に、または `.minimumScaleFactor(0.85)`。

7. 【低】「CHAMPION DUO」(:272付近)・「LIVE 生放送」・大会名ラベルの装飾が読まれる
   英語見出しが日本語 VO で不自然、直下にコンビ名がある。直し: `CHAMPION DUO` と四角の装飾に accessibilityHidden。コンビ名側に「優勝コンビ」を前置ラベル。

8. 【低】isGone が onAppear で false に戻らない — :178-181
   現状は overlay で毎回作り直されるため無害だが、同一インスタンスが再表示されると演出の音・触覚が全部抑止される。直し: onAppear 先頭で `isGone = false`。

9. 【要確認】視差を減らす時に音・触覚が一切出ない — :468-472
   reduceMotion では completeImmediately のみで championImpact/prizeGet の音・触覚がない。仕様なら問題なし（「音は鳴らす」方針なら要判断）。
10. 【要確認】`.yoseShake`（:152）が reduceMotion で止まるか — YoseEffects.swift 側の確認が必要。通常経路では shakeTrigger は reduceMotion で増えない（completeImmediately は shake しない）ので実害は出にくい。

数値・乱数・ゲームの式に触る直し: なし（判断が要る項目なし。賞金 prizeAmountYen は表示のみ）。

## §3 直した分と残り（11/19 定期の回）
- #1 #2 #3 #5 #7 #8 を表示だけで直した（YoseChampionCelebrationView.swift・+21行）。**同時に動いていた別のセッションのコミット 4c28f2374（AUTOPILOT 694 の docs）に混ざって push 済み**＝ビルド・アプリのテスト・目視は未。
- 次の回：ビルド exit=0 → アプリのテスト TEST SUCCEEDED → 優勝演出を1枚目視（読み上げは実機）→ AUTOPILOT 693 を「済」に。残り＝#4（大きい文字で看板・ヘッダー・ボタンの固定高さ＝目視しながら）・#6（講評2行）・要確認 #9 #10。
- この回は別のセッションの作業（dd2 のビルド・CalendarView/FinalistAnnounceView の未コミット変更）を見つけたため、手を離して終了。
- （11/19 夕の定期）ビルド exit=0（#1 #2 #3 #5 #7 #8 の分）。#6 済（講評を3行まで・0.85 まで縮める）。#4 の一部済（ヘッダーと「次へ」ボタンを固定高さ→最低高さに・ボタンの文字は1行で 0.7 まで縮める）。看板の 256 は目視で切れが見えたら直す。ビルド exit=0。
