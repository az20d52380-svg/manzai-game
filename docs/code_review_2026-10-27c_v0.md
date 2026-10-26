# コード点検 10/27c（昼の点検 27b の後の変更）v0

対象：`git diff 05807f0..HEAD -- ManzaiGame/Sources GameCore/Sources`（13ファイル・+50/-46）。台詞の文言の良し悪しは見ていない。
確認：`cd GameCore && swift test` → **Executed 423 tests, with 0 failures**。アプリ側のテストは回していない（読んだだけ）。

## まとめ
- 件数：高 0／中 0／低 3（どれも直さなくても動く・見た目と読み上げの小さな話）。
- 27b #5（S6b「タップで進む」の余白がコメントに入っていた件）は直っている＝`.padding(.bottom, Theme.Sp.s24)` が効く位置に戻った。DEBUG の `OfferSpec(income: 120_000)` も円の単位（jobs は 96_000 など）と合っていて正しい。
- 文言の完全一致テストの見落としは無し：変えた文言（とり政→鳥つむぎ・「満タン・回復は余る」・「次や、次」・「図鑑」・コンビ形の注記・各独白）を GameCore/Tests と ManzaiGame/Tests で grep したが、完全一致で持っている所は無い。ソースを文字で読むテスト（FirstPersonLiteralTests・SaveDataConventionTests）は一人称の禁止語と SaveData の非Optional を見るだけで、今回の差分では赤くならない（実際に 423 件通過）。ChoiceEventPairing1027Tests はボタン名のキーの集合を見るだけで文言は見ない。

## 表
| # | ファイル:行 | 何が | 直し方の案 | 重さ |
|---|---|---|---|---|
| 1 | ManzaiGame/Sources/WeekMainView.swift:927-929（practiceExpPanel） | 追加した「経験点の\n持ち分」の Text に読み上げ用の指定が無い。VoiceOver は改行で切れて「経験点の」「持ち分」と読むか、後ろの5列と別項目になる（推測：実機未確認）。フォントは mzScaled の上限 1.35倍までなので `fixedSize()` で横幅が足りなくなる恐れは小さい（12→最大約16pt・4文字で約64pt） | `.accessibilityLabel("経験点の持ち分")` を足す（見た目は変えない） | 低 |
| 2 | ManzaiGame/Sources/IntroFlow.swift:385-393（S1TitleView の図鑑ボタン） | ラベルが「図鑑」→「エンディング図鑑」（8字）になり、`minWidth: 52` のまま `lineLimit` 指定なし。1.35倍でも約140ptで右上の設定ボタン（40pt）とは重ならないが、小さい端末（SE幅）＋大きい文字では折り返して縦に伸びる恐れ（推測）。`.accessibilityLabel` が表示文字と同じになり冗長（害は無い） | `.lineLimit(1).minimumScaleFactor(0.8)` を足すか、折り返しを許す前提で目視 1 枚。冗長な accessibilityLabel は消してよい | 低 |
| 3 | ManzaiGame/Sources/ComboKindPickerView.swift:23 | 注記「このコンビでいるあいだは変えられない」。comboKind は GameSession の init（:222-225）とセーブ復元（:251）でしか代入されず、途中で変える道は無いので事実とは合っている。ただし将来コンビ形を変える機能（再結成など）を足すとこの文が嘘になる | 足す時にこの1行も直す、とコメントを残す程度 | 低 |

## 見たが問題なしのもの
- WeekMainView:1060 の `lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)`：同ファイル:1012 と同じ書き方で、札の高さは固定されておらず（VStack の自然高）切れない。`desc` 側は `row ? 1 : 2` のままで別の話。
- WeekMainView:647 のタグ「体力は満タン」：条件 `stamina >= 99.5` は変更なし。文字が短くなっただけ。
- SettingsView：`linkRow` に `inApp` を足した変更は、既定引数 `external: true` のままの他の呼び出しに影響なし（`external: false, inApp: true` を渡す2箇所だけ›が出る）。復元ボタンの下の12ptの説明は `frame(maxWidth: .infinity, alignment: .leading)` で折り返す。
- QualifierNoticeView：13pt・不透明度0.8に変更。12pt未満ではなく規約内。
- ChoiceEventData：台詞だけの変更（？・店名・B案の台詞）。キーや選択肢 id は不変＝ペアリングのテストに影響なし。
- DialogueData／FanReportData／JudgeTalk：差し替えは文字列だけで、`{題}{中}{締め}` などの差し込み記号と〈名〉〈大会〉〈弱点〉は残っている（差分で確認）。
