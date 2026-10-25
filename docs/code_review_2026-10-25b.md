# コード点検 2026-10-25b（午後の差分）

対象：`git diff d8d2063..HEAD -- ManzaiGame GameCore tools ':!*.md'`（Sources 14 ファイル＋テスト）。読むだけ・ビルド無し。

## §1 確度 高
なし

## §2 確度 中（いずれも軽微・表示まわり）
1. ManzaiGame/Sources/WeekHint.swift:43 — 撮影週（preoccupied）の1行が、生活費・体力・相方の警告より前に return する。手順：写真撮影イベントを選ぶ→その週が「今週末に生活費。所持金が足りない」週（または体力が `staminaLow` 以下）。→ 生活費不足・体力不足の警告が出ず「今週は撮影の仕事で…」だけになる（稽古は自動休養なので体力は回復するが、家賃警告は見落とす）。直し案：`money<0` と同様に `livingThisWeek` の警告を preoccupied より前に置く、または preoccupied は `netaCount==0` の代わりの位置（体力・生活費の後）に移す。確度：中（意図の可能性あり）。
2. ManzaiGame/Sources/NetaSelectionView.swift:137 ＋ NotebookView.swift:411 — 「見飽きられた（点が下がる）」(13字) に `.lineLimit(1).fixedSize()` が付いたまま。NotebookView の `netaBadges` は同じ HStack に `fixedSize` の「まだ人前でやっていない」タグが並ぶ。手順：tiredYears≥2 かつ `!isDown` のネタ（実際は大会で掛けた後なので isDown になっていれば両立しない可能性が高い）、または Dynamic Type 大で幅が足りない端末。→ 横にはみ出して切れる。直し案：`ViewThatFits` か、2行許容（fixedSize を縦のみ）。確度：中〜低（通常は両立しない組合せ）。
3. ManzaiGame/Sources/YearResultView.swift:264 — 「観戦」札の出現条件が `line.contains("客席")` という文字列一致。本文側にも「（客席から）」が残るので、札と本文が二重表示（意図どおりなら問題なし）。また HStack の末尾に置かれるため、本文が長い週は札が圧縮され「観戦」が縦に折れる可能性（`YoseTag` に `fixedSize` が無い）。直し案：札に `.fixedSize()`、判定は `eventLines` と同じ述語を共有。確度：中〜低。

## §3 見たが問題なかった所
- JudgeTalk.swift：nil 型の語彙 4→8 語。`fill` は `list[mix % count]` で個数非依存。追加台詞の置換子は {入り}{中}{一言}{締め}{題} のみで未定義なし。{題} 行は `pick` が題なしで除外。語＋「ひとつで」等の接続も不自然な連結なし。
- DialogueData.swift：台詞2件の直し（片づけ・割り勘）。直後の返答（「いいよ…」）と流れが合い、{me} 置き忘れなし。
- ChoiceEventData.swift：谷口の「あの人たち」。問題なし。
- TournamentResultView.swift ClimaxData.revivalLoss：台詞差し替え後も前後の流れ（見に行く→優勝を見た→悔しい）が通る。
- IntroFlow.swift:70：`Names.show` を speaker と text の両方に適用。`RecallScriptRow` と同じ扱いで {me}{partner1} が置換される。
- ComboKindPickerView.swift：`.accessibilityAddTraits(picked == kind ? .isSelected : [])` は Button の後ろで有効、タップ可否に影響なし。説明文の「この周のあいだは変えられない」は導入でのみ選択（IntroFlow 782 のみ）で事実と一致。
- EndingViews.swift：`accessibilityElement(children: .combine)` は Text 2つだけの VStack に付いており、ボタン（別要素）は押せる。`.accessibilityLabel("タイトルへ")` は▶の読み上げ回避で状態と矛盾なし。
- NotebookView.swift：「観戦」札の accessibilityLabel は `watchedFinal == true && !reachedFinal` の時だけ表示される札と一致。
- WeekMainView.swift lullLine：`preoccupiedWeeks>0` はヒント側と同じ条件で整合。`WeekHint.Input.preoccupied` は既定値 false で他の呼び出しに影響なし。
- GameSession.swift：コメントのみ。

## 扱い（10/25 深夜の自走）
- §2-1 直した：撮影の週でも、今週末の生活費が足りない時はその1行を先に出す（他の週の順番は変えない）。テスト1本追加（アプリ側 80 green）。あわせて2回目の `money < 0`（先頭で必ず返るので通らない行）を外した。
- §2-2・§2-3 は幅・二重表示の疑い＝目視で確かめてから直す（AUTOPILOT キューへ）。
