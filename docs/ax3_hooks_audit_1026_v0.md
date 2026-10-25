# 最大文字サイズ（accessibility-extra-extra-extra-large）での目視 20画面（2026-10-26）v0
iPhone 17 のみ。コードは未変更。終了後 content_size は large に戻し済み。撮影は feedback_shots/ax3_hooks_1026/（未コミット・600px縮小）。
DEBUG 近道札（優勝/無双）は所見にしていない。以前の点検（dynamic_type_audit_1019_v0 / 1025_v0）に今回の所見と同じものは無い（新規）。
注：notebook / neta_list はそれぞれ「コンビ」の能力タブ・持ちネタタブ、weeknetas / rent / weekhint / prestage / cards は週のメイン画面に直行した（フックの行き先どおり）。

| 画面 | 結果 |
|---|---|
| settings | 崩れなし（下の権利表記ボタンは画面下端で見切れるがスクロールで届く） |
| glossary | 崩れなし |
| shop | 崩れなし（「引っ越す」「¥3,000 購入」とも押せる） |
| endingbook | 崩れなし |
| allocate | 崩れなし（下の「特技」見出しが下端ボタン帯に半分重なる＝L3） |
| calendar | **所見H1** |
| notebook（能力タブ） | 崩れなし |
| neta_list（持ちネタ） | **所見M2**（主ボタンの文字が欠ける） |
| weeknetas（週メイン・出張中） | **所見M1** |
| cards（週メイン） | 崩れなし |
| debt（バイト話） | 崩れなし |
| rent（週メイン） | L1 のみ |
| weekhint（週メイン） | L1 のみ |
| wintercup | 崩れなし（出場する／見送る とも画面内） |
| injury | 崩れなし（「わかった」押せる） |
| prelude | 崩れなし（「本番へ」押せる） |
| gpresult | L4 |
| pass（本番・客席の反応） | L2 |
| result_done | 崩れなし |
| prestage | L5 |

## 所見
### 重
- **H1 年間香盤：月の列が「1…」に切れ、10月・11月・12月の見分けがつかない**（1〜9月は読める）。推定 `ManzaiGame/Sources/CalendarView.swift:68-70`（`monthLabel` を `.frame(width: 42)` の固定幅で表示）。直し方：月ラベルに `.lineLimit(1).minimumScaleFactor(0.6)` を付ける、または幅を `minWidth: 42` ＋ `fixedSize(horizontal:)` にして大きい文字では列幅を広げる（見出し行 `:61` の「月」も同じ幅に揃える）。表示だけ。

### 中
- **M1 週メインの左上「実力」札：3桁の実力が「1…」に切れる**（大事な数字が欠ける。weeknetas で実力3桁・相性10のとき）。推定 `ManzaiGame/Sources/WeekMainView.swift:566-568`（`statBar` の数字 `minimumScaleFactor(0.7)` でも幅96の札に入らない）。直し方：大きい文字では数字の最小スケールを下げる（0.45 程度）、または札の幅を `dynamicTypeSize` が大きい時だけ広げる／「実力」ラベルと数字を縦積みにする。表示だけ。
- **M2 持ちネタ：ネタカードの「勝負ネタに…」が欠ける**（「勝負ネタにする」が「…」で切れる。押すことはできるが文言が読めない）。推定 `ManzaiGame/Sources/NotebookView.swift:439-446`（`actionChip` の `frame(width: 132)` 固定＋`lineLimit(1)`）。直し方：幅を `minWidth` にして伸ばす、または大きい文字では2行を許す（`lineLimit(2)`）。表示だけ。

### 低
- L1 週メイン：舞台の「寄席」看板が俺の頭に重なる（rent・weekhint ほか）。読めて押せる。推定 `WeekMainView.swift` の舞台シーン（看板「寄席」は縦書き表示。大きい文字では看板を小さく／位置を寄せる）。
- L2 本番（pass）：LIVE帯の「結成1年目　第1…」が切れる。推定 `TournamentResultView.swift:134`（`minimumScaleFactor(0.85)` を 0.6 に）。
- L3 能力アップ（allocate）：下の「特技」見出しが下端のボタン帯に隠れる（スクロールで見える）。
- L4 頂GP通知（gpresult）：通知カード左のメガホンのアイコンが左端で切れる／大きい文字で本文2行。推定 `QualifierNoticeView.swift:88`（アイコン枠の幅を固定せず `fixedSize`）。
- L5 週メイン（prestage）：朱札「未振分あり」が「能力アップ」の説明文（能力を伸ばす）を覆う。推定 `WeekMainView.swift:1009,1022`（`padding(.bottom, 14)` は入っているが、大きい文字では足りない）。

## 件数
20画面／高（重）1・中2・低5。押せなくなる主ボタンは無し。
