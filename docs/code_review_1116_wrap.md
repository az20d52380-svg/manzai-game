# コードレビュー 1116 折り返し・文言の直し4本（3df73f32a / b141e9759 / 055f3f667 / 5ba7c0282）

## §1 要約
- 高1件：055f3f667 と 3df73f32a で、行末コメントを `.foregroundStyle(...)` の前に挟んだため、同じ行の後ろの修飾子がコメントに飲まれて消えている（文字色 sumi、年末は lineSpacing(3) も）。
- 中1件：b141e9759 の「・」改行は、最大の文字サイズで2行目が折れず「…」で切れる可能性。
- 折り返し関数の端の場合（空・空白だけ・8字ちょうど・絵文字・「「」連続・改行）は落ちず、文字の消失・重複なし。5ba7c0282 は問題なし。

## §2 指摘
### 1. 【高】修飾子がコメントに飲まれて消えている
- NotebookView.swift:246（055f3f667 で混入、3df73f32a で残る）
  `Text(Self.breakAtSpaces(e.title)).font(YoseFont.gothic(14, weight: .heavy))   // ...折る.foregroundStyle(YoseColor.sumi)`
  → `.foregroundStyle(YoseColor.sumi)` が `//` 以降に入り無効。
- YearResultView.swift:293（3df73f32a）
  `...font(YoseFont.mincho(14))   // ...AUTOPILOT 571）.lineSpacing(3).foregroundStyle(YoseColor.sumi)`
  → `.lineSpacing(3)` と `.foregroundStyle(YoseColor.sumi)` が消える。次行の `.fixedSize` は別行なのでコンパイルは通る＝ビルド・テストでは気づけない。
- 起きる条件：常時。文字色が sumi(0x2B2B2B) から既定の primary（ライトなら黒・ダーク外観なら白）に変わり、年末の出来事は行間も詰まる（複数行時）。ライト固定なら色差は微小で目視でも見落とす。ダーク外観に対応している／固定していない環境（アプリ側の固定設定は plist/pbxproj で未確認）では、クリーム地に白字で読めなくなる。
- 直し案：コメントを行末ではなく別行にし、修飾子を改行して戻す。
  `Text(...).font(...)` の次の行に `.foregroundStyle(YoseColor.sumi)`（年末は `.lineSpacing(3)` も）。コメントは最後に置く。

### 2. 【中】b141e9759：最大文字サイズで2行目が切れる
- StageViews.swift:~268 ViewThatFits の2案目 `Text(breakAtLastDot(line)).lineLimit(2).minimumScaleFactor(0.85)`
- 条件：accessibility 系の最大サイズで「エントリー費 ¥2,000」の1行が幅に収まらない時。明示の `\n` で既に2行を使うため、2行目は折れず `…` で切れる（以前は自然折り返しで3行目は同様に切れるが、語の途中の折れとは別問題）。
- 直し案：2案目の lineLimit を nil（または3）にする。もしくは3案目（最後の「・」改行なし・lineLimit(3)）を足す。標準サイズは1案目に収まるので影響なし。
- 補足：サイズ別の目視は担当済みと記載されているが、最大サイズの確認は不明。

### 3. 【低】b141e9759：doc コメントの付け先
- StageViews.swift:254 `/// 出場ボタン（…）` が breakAtLastDot の直前に残り、entryButton の説明が関数に付いていない（Xcode のヘルプ表示がずれるだけ）。breakAtLastDot の下に移す。

### 4. 【低】5ba7c0282：ボタン文言「次へ 進む」
- TournamentResultView.swift:302。語の間の半角空白は折り返しの都合なら意図どおりだが、日本語としては「次へ進む」が自然。意図なら問題なし。判断はオーナー。

### 5. 【低】breakAtSpaces は 8字超のかたまりを折れる（仕様）
- NotebookView.swift:159。「「」で始まる9字以上のコンビ名（例 「〜ロケット座」）は従来どおり名前の途中で折れる。コメントに仕様として明記済みなので修正不要（記録のみ）。

## §3 問題なしと確かめた点
- breakAtSpaces（NotebookView.swift:159）：
  - 空文字・空白だけ・連続空白：split は omittingEmptySubsequences:false、空語は pieces=[""] で空のまま戻り、元の空白数が保たれる。落ちない・無限ループなし（for は有限）。
  - 8字ちょうど：`count <= 8` で結合。9字は結合せず（境界の取り違えなし）。
  - 絵文字・結合文字：`Character` 単位（拡張書記素クラスタ）で U+2060 を挟むので ZWJ 列・濁点結合は分断されない。
  - 「「」が先頭／連続：先頭は cur 空で分割せず、「「」直後の「「」「（」は `cur != "「"` で分割せず結合保持。「（「」は分割。すべて pieces を join するだけなので、U+2060 を除くと入力と完全に一致（消失・重複なし）。
  - 改行を含む文：「\n」は1つの Character で語内に残り、8字以下なら前後に U+2060 が付くだけ（改行は有効のまま）。
- VoiceOver：Text を分けていない（1つの Text に U+2060 入り文字列）ので読み上げは分断されない。U+2060 はゼロ幅で通常は読まれない（実機の確認は未）。YearResultView の観戦タグの accessibilityLabel も影響なし。
- breakAtLastDot：「・」なし・空文字・末尾が「・」でも落ちない（range nil なら原文、あれば1回だけ置換）。`残高不足で出られない` は原文のまま。
- ViewThatFits の1案目（lineLimit(1)）は標準サイズで収まれば従来と同じ1行になる。
- 5ba7c0282：proceedLabel は既定値付きで頂GP・YoseFXPreview の呼び出しは無変更（FinalsPresentationView は既定のまま）。init・プロパティの追加のみで他の呼び出しを壊さない。
