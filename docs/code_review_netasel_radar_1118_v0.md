# コード点検：NetaSelectionView / RadarChart（2026-11-18・読み取り専用）
対象: ManzaiGame/Sources/NetaSelectionView.swift, RadarChart.swift（呼び出し側 StageViews.swift:191,330-337 / YearResultView.swift:222 / GameSession.swift:911-932 も確認）

## 要点3行
- 新規は中1・低3・要確認3。落ちる穴（添字外れ・NaN・ゼロ除算）は無い。レーダーは 0...1 に収めてあり、cap>0 と n>=3 の守りもある。
- 一番大きいのは、文字を大きくした時に「選んでいるネタ」の行（完成度＋段の札＋「変更」ボタン）が横に収まらず切れそうな点（§1）。
- 既知の指摘（尺ラベル未使用・1本目に2本目と同じを選ぶと黙って外れる・「見飽きられた」札の1行固定）はまだ残っている（§既知）。

## 節構成
§1〜§4 ネタ選択 ／ §5〜§7 レーダー ／ §8 選択状態の守り ／ §既知 ／ §問題なしと確認

## ネタ選択（NetaSelectionView）

### §1 中｜NetaSelectionView.swift:94-107（currentSummary）
- 場面: 設定で文字を最大近くまで大きくして大会入口を開く。選択済みのネタ行は `HStack` に「完成度 NN（fixedSize）」「段の札」「変更 ▼（fixedSize）」が1行で並ぶ。3つとも縮まない＋Spacer だけが伸び縮み。幅はおよそ 120+70+110+間隔20＝320pt 前後で、画面幅（393pt）から左右の余白を引いた幅と同じくらい。段の札が長い段名の時や小さい端末だと右端が切れる／札が潰れる。
- 対比: 下の候補行（candidateRow:127-131）は `dynamicTypeSize >= .xxLarge` で名前を上段に分けているが、currentSummary は `dynamicTypeSize`（:92）を宣言しただけで使っていない。
- 直し案: bigText の時は `ViewThatFits` か縦並びに切り替え、changeLabel を次の段へ落とす。
- 表示専用: はい（見た目だけ。状態・golden に触らない）。実機で最大サイズを撮って要確認。

### §2 低｜NetaSelectionView.swift:124
- 場面: 候補を選ぶと `withAnimation(Theme.Motion.appearQuick)` で閉じる。ここだけ `Theme.Motion.r(...)` を通っていないので、「視差効果を減らす」をオンにしていても開閉の動きが出る（:26 の開く側は `r` 済み）。:60 も同じだが DEBUG 限定。
- 直し案: `withAnimation(Theme.Motion.r(Theme.Motion.appearQuick))` にそろえる。
- 表示専用: はい。

### §3 低｜NetaSelectionView.swift:121,136
- 場面: `candidates`（:68-70）は選択中のネタを除いているので、`isThis` は常に false。「選択中」札と濃い背景（:142）は実行されない死にコード。害は無い（playtest_v13 §4-1 で並べない方針にした名残）。
- 直し案: 削るか、コメントで「保険」と明記。表示専用: はい。

### §4 低｜NetaSelectionView.swift:25-31, 72-81, 120-147（VoiceOver）
- 場面: 開閉ボタンの読み上げは「ネタ名、完成度、段、変更、下向き三角…」と断片の連結になる。▼▲の記号がそのまま読まれる。決勝は「決勝・1本目」「決勝・2本目」の2行があり、ボタン側に「どの枠か」が無いので、ボタンだけに移動した人は枠が分からない。候補ボタンも同様に「完成度」の数字と札が別々に読まれる。
- 直し案: 要約ボタンに `.accessibilityLabel("\(title)、\(selected?.name ?? "未選択")")` を付け、▼▲は `accessibilityHidden`。候補行は `.accessibilityElement(children: .combine)` ＋ 「名前、完成度NN、○○の段」と1文に。
- 表示専用: はい。

## レーダー（RadarChart）

### §5 要確認（低）｜RadarChart.swift:55-59（abilityAxes の縮尺）
- 場面: 縮尺 `zoom` は「今の最大値」だけで決まる。年初（base）の方が大きい能力があると（能力が下がる出来事があれば）、`ratio` が 1 で止まるため、開始の点線が外周に張り付き、読み上げの「年初は80」と図が合わない。能力が下がる経路があるかは未確認。
- 直し案: `maxVal` を current と base の両方の最大から取る。
- 表示専用: はい。

### §6 要確認（低）｜RadarChart.swift:98,145-147（ラベルの余白と Dynamic Type）
- 場面: ラベルは Canvas の中に固定の余白26ptで描く。フォントは `mzScaled`（最大1.35倍）で大きくなるが余白は固定。いまの使い方（YearResultView:222 は高さ210・幅は画面幅）では、左右ラベル（「メンタル」）は幅に余裕があり切れない計算。ただし幅が狭い場所（分割表示・小型端末の横余白が大きい画面）に置くと、左右端の「メンタル」が Canvas の外にはみ出して切れる。
- 直し案: 余白を `26 * 文字倍率` にするか、ラベルを Canvas の外の Text に出す。今は直さなくてよい。表示専用: はい。

### §7 低｜RadarChart.swift:71-77（VoiceOver）
- 場面: 読み上げは「能力の図」＋「センス 12、年初は10。発想 …」で通る（`children: .ignore` で二重読みは無い）。ただし上限（cap）や「何点中」は入らず、レーダーの強み（相対位置）は伝わらない。また読み上げは「年初」、図のコメントは「開始（4月）」、YearResultView の凡例は「年初」で呼び方がずれるのは見た目と一致。
- 直し案: 必要なら「上限NN」を足す。今のままでも読める。表示専用: はい。

## 選択状態の守り

### §8 要確認（低）｜GameSession.swift:919-932（選択の受け口）
- 場面: `selectNeta` / `selectNeta2` はコメントに「アクティブ枠内のIDのみ有効」とあるが、id が `state.netas` に在るかは確かめていない。いまは UI が `activeNetas` からしか渡さないので起きないが、保管庫のネタや消えた id が将来の入口（ネタ帳・DEBUG）から渡ると、`selectedNeta` は nil（行は「選んでいない」）なのに state には id が残る。
- 直し案: `guard id == nil || state.netas.contains { $0.id == id }` を受け口に足す。
- 表示専用: いいえ（GameSession の受け口。ただし runner/golden には触れない UI 層）。

## 既知（再掲）
- 既知｜NetaSelectionView.swift:156-157 の「見飽きられた（点が下がる）」札の `.lineLimit(1).fixedSize()`：code_review_2026-10-25b #2 で指摘済み。現在もそのまま残り、大きい文字で横にはみ出す。
- 既知｜`requiredLength`（尺）が NetaPickRow 内で未使用：code_review_nss_1116_v0 #3。
- 既知｜決勝で1本目に2本目と同じネタを選ぶと2本目が黙って外れる（GameSession:920）：code_review_1108c_screens #5。
- 既知｜ネタ1本の決勝で「選ぶ」を朱で誘う件（:73 で対応済み）・開閉状態の読み上げ（:30 で対応済み）：code_review_minor5_1117 #1 / #7。
- 既知｜レーダーの 0 未満の下限（:91 の `max(0, …)` で対応済み）・Canvas が補間されない件（RadarCanvas の Animatable で対応済み）：code_review_curtain_fan_1117 の要確認・低。

## 問題なしと確認
- 空配列・添字外れ: `candidates` は filter のみ、`axes[i]` は `n = axes.count` の範囲、`guard n >= 3` あり。`session.activeNetas.isEmpty` と `candidates.isEmpty` の文言も出し分けている（:35-38）。
- 割り算: `ratio` は `cap > 0` で守る。`abilityAxes` の cap は `min(realCap, zoom>=30)` で必ず正。NaN は JSON に載らず `polish` も 0..100 に丸め済み（minor5_1117 に既出）。
- 動き: RadarChart は `reduceMotion` と `Theme.Motion.r` の二重で守る（冗長だが害なし）。ActionBreakdownBand:177 も `reduceMotion` 対応済み。
- 1本目＝2本目の重複: `candidates` の excludeID と `GameSession.selectNeta`/`selectNeta2`/`ensureStageNetaDefault` の三重で防いでいる。
