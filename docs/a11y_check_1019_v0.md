# a11y 点検 a11y_check_1019_v0（2026-10-19・読み取りのみ・コードは未変更）

**件数：全17件（高 11／中 6）。ほか §6 に中の短評3系統。** 対象＝10/17 以降に触れた画面。特に QualifierNoticeView・FinalistAnnounceView・FinalsBroadcastIntro・RentStatement・YoseYearTurnCurtain。
基準＝a11y_audit_v1 の決まり：①固定 `.system(size:)` は使わず `Font.mzScaled`（YoseFont.gothic/mincho/number 経由）②記号アイコンは `accessibilityHidden(true)` ③意味のある要素は label を付け、色だけで区別しない ④reduceMotion では TimelineView を pause／繰り返しアニメ・大きな動きを止める。
節：§1 FinalistAnnounceView／§2 QualifierNoticeView／§3 FinalsBroadcastIntro／§4 RentStatement／§5 YearTurn（問題なし寄り）／§6 その他の画面／§7 直す順の案

## §1 FinalistAnnounceView
1. **[高]** FinalistAnnounceView.swift:60-106, 208-232 — `accessibilityReduceMotion` を一度も読まない。約50秒以上（待ち4s→並び5s→読み上げ2.5s＋1.7s/組）が自動進行し、spring・移動・dim が常に動く。→ reduceMotion 時は `withAnimation` を外し、`pause` を短縮（または最初から .after へ）。
2. **[高]** 同:106, 213-230 — 自動進行で `caption`（読み上げ中の組名）が替わるだけで、VoiceOver は新しい文言へフォーカスが動かず、Announcement も無い＝利用者は読み上げ終了に気付かず置いていかれる。タップ送りも全面 `onTapGesture`（ボタン扱い無し）。→ `caption` 変化時に `AccessibilityNotification.Announcement(caption).post()`、VoiceOver 稼働時（`UIAccessibility.isVoiceOverRunning`）は `skipAll()` 相当で最初から .after に。
3. **[高]** 同:79, 126 — `Image(systemName: "building.columns")`・`"mic.fill"` に `accessibilityHidden(true)` 無し（「building columns」「mic fill」と読まれる）。かつ `.font(.system(size: 54/16))` 直書きで文字サイズに追従しない（規約違反）。→ `.accessibilityHidden(true)` と `Font.mzScaled(54)` を足す。
4. **[中]** 同:109-190 `silhouette` — 組ごとの図形は label 無し（`done` 時のみ hidden）。自組名の `selfLabel` は `.lineLimit(1).fixedSize()` で大きい文字だと隣へはみ出す。→ 図形ごと `accessibilityHidden(true)` にして caption に一本化／自組名は `.minimumScaleFactor`。
5. **[中]** 同:140-146「飛ばす」(QualifierNoticeView:60 も同形) — padding 6pt で高さ約30pt、タップ領域 44pt 未満。→ `.frame(minHeight: 44)` か `contentShape` を広げる。

## §2 QualifierNoticeView
6. **[高]** QualifierNoticeView.swift:195-237 — reduceMotion 未参照。通知の spring 登場・`move(edge:)` の吹き出し・スクロールのアニメが常に動く。さらに自動進行（1.2s→通知→3.2s後に自動スキャン→チャット 0.9〜2.6s 間隔）。→ `withAnimation` を reduceMotion で `nil` にし、待ち時間を短縮。
7. **[高]** 同:77-79 — 通知ボタン内の `Image(systemName: "megaphone.fill"/"bubble.left.fill")` が未 hidden。ボタン label が「megaphone fill、頂GP公式、いま、【結果発表】…」と記号名つきで読まれる。→ アイコンに `accessibilityHidden(true)`、ボタンに `.accessibilityLabel("通知を開く。\(本文)")`。
8. **[高]** 同:112-121 — 通過者一覧で自組の行は「色・枠・光」だけで強調（`me && scanned`）。VoiceOver・色覚で自組が分からない（audit_v1 §3 の「色だけで分けない」に反する）。→ 行に `.accessibilityLabel(me ? "\(n)、あなたたち" : n)`＋`accessibilityAddTraits(.isSelected)`。
9. **[高]** 同:139 — 一覧画面は全面 `onTapGesture`（「タップで次へ」）が唯一の送り手段で、ボタン trait 無し。自動 `scanned` は3.2秒後に走るが、VoiceOver が読み終える前に強調・「つづける」が出る。→ `accessibilityAction`／隠しボタンを足し、`scanned` 切替時に Announcement（「あなたたちは通過です」等）。
10. **[中]** 同:74 — `Text("21:04").font(.system(size: 72, weight: .thin))` 直書き固定（規約違反）。→ `Font.mzScaled(72)`。装飾なので `accessibilityHidden(true)` でも可。
11. **[中]** 同:164-181 `bubble` — 「自分／相手」の区別が左右位置と色のみ。→ `.accessibilityLabel(mine ? "自分、\(t)" : "\(partnerName)、\(t)")`。メッセージ追加時の通知も無い。

## §3 FinalsBroadcastIntro
12. **[高]** FinalsBroadcastIntro.swift:82-83, 572-573 — ボタン文言 `"スキップ ▶▶"` の記号が「黒右向き三角」と読まれる。→ `.accessibilityLabel("スキップ")` を付ける。あわせて高さ28pt（<44）。
13. **[高]** 同:301-312 `sparks`（TimelineView 20fps 常時）・317-330 `searchlights`（回転）・66/448 `blink`（repeatForever）— reduceMotion で止まらない。reduceMotion は :61 で `short`（時間短縮）にしか使われていない。→ `TimelineView(... paused: reduceMotion)`、searchlights は回転なしで固定角、blink は `if !reduceMotion` の時だけ repeatForever。
14. **[高]** 同:572-590（outro）— 約5.4秒（short でも約1.9秒）で自動 `finish()`。VoiceOver が優勝者名・講評を読む前に閉じる。同様に vtr(:336-)・title・judges・finalists の各段も自動で `advanceStage()`。:61 の `short = reduceMotion` は「速く流す」＝読み上げ利用者にはむしろ不利。→ VoiceOver 稼働中は自動遷移を止めて「次へ」ボタンのみで送る（reduceMotion は動きだけ止め、時間は短縮しない）。
15. **[中]** 同:209-210 — `mincho(13)/(10)` に `minimumScaleFactor(0.5)`。大文字サイズでは実質5pt級に潰れる。→ 下限0.7、または2行許容。

## §4 RentStatement
16. **[高]** RentStatement.swift:122-140 — 約2.2秒で自動 `onDone()`（行0.09s×n＋0.25＋0.5＋1.0）。合算ラベル（:120）の読み上げに5秒前後かかるため、読み終える前に閉じる。かつ `.accessibilityElement(children: .combine)` 自体は良いが、タップ（:63, :117）はボタン trait 無し。→ VoiceOver 稼働中は自動 `onDone` を止め、「閉じる」を `accessibilityAction`／Button で。reduceMotion 時の行表示は `step 0` だけで `withAnimation`・`numericText`・判子衝撃（YoseStampImpactModifier）は残る→ `reduceMotion ? nil : animation`。

## §5 YoseYearTurnCurtain（ほぼ準拠）
- reduceMotion は :363 で全状態を即時確定（幕・判子・揺れなし）＝規約どおり。`play.fill` は hidden。主ボタン label も文字のみ。
17. **[中]** Design/YoseYearTurnCurtain.swift:134 — 全面 `onTapGesture { triggerStart() }` は Button と重複し、VoiceOver には「何でも押すと次年度」が伝わらない上、`curtainPanel`（左右幕・:109-125）が `accessibilityHidden` 無しで空要素として残る可能性。→ 幕に `accessibilityHidden(true)`、全面タップに `.accessibilityHidden(true)`（Button に集約）。確度中。

## §6 その他（所見は短く・いずれも確度中）
- NotebookView.swift:336 — 「改名」札(`YoseTag`)が `onTapGesture` のみでボタンとして読まれない。→ `.accessibilityAddTraits(.isButton)`＋label「題名を直す」。
- WeekMainView.swift:232, 237, 587 / TournamentResultView.swift:195, 229, 554 / FinalsPresentationView.swift:194 — `Color.clear` 全面タップ（スキップ・次へ・会話送り）が無ラベルの操作要素になる／ボタン trait 無し。→ 装飾の `Color.clear` は `accessibilityHidden(true)`、送りは `accessibilityAction(named: "次へ")`。FinalsPresentationView:195 の長押し早送りにも同名 action を。
- Design/YoseChampionCelebrationView.swift — reduceMotion 対応は十分（:464, 683, 809, 915 で pause）。追加指摘なし。
- AbilityUpView/StageViews/IntroFlow/WeekMainView の SF Symbol は `Font.mzScaled` 経由で規約どおり（直書き無し）。

## §7 直す順の案
1. 自動で閉じる／進む画面（#2, #9, #14, #16）＝VoiceOver 利用者が最も置いていかれる。共通の「VoiceOver 稼働中は自動遷移しない」ヘルパーを1つ作る。
2. #12, #7, #3（記号の読み上げ）＝1行ずつで済む。
3. #8（自組の強調が色のみ）。
4. reduceMotion 一括（#1, #6, #13, #16 の animation）。
未確認：実機の VoiceOver 通し確認はしていない（静的読みのみ。確度「高」はコード上の事実、「中」は挙動推定を含む）。

## 直した所（10/19 自走・ビルド OK・実機の VoiceOver では未確認）
- 自動で進む／閉じる画面：RentStatement と FinalsBroadcastEnding は VoiceOver 中に自動で閉じない＋ダブルタップで閉じる。FinalistAnnounce（組名・段の切り替え）と QualifierNotice（一覧の結果・相方の返事）は announcement で伝える。
- 残り（ラベル・Dynamic Type・reduceMotion の個別の所見）は次の回で。
