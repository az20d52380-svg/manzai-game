# コード点検：NotebookView／S6bView／EndingGalleryView（11/17・読むだけ・コード不変）

対象：ManzaiGame/Sources/NotebookView.swift・S6bView.swift。EndingGalleryView は独立ファイルが無く EndingViews.swift:319〜（EndingFlowView・EndingArt とあわせて読んだ）。

## 要点3行
- 高0／中0／低1（新規）／要確認0。クラッシュ・二重実行・年数の矛盾・女コンビの男語・条件文の食い違いは見つからない。
- 新規は NotebookView の改名「確定」ボタンが読み上げで名無し（中身の画像だけ hidden で、ボタン自体に名前が無い）。
- 既出の点（タップで進む年表の読み上げ・透明ボタン・breakAtSpaces の U+2060 読み・改名途中の切替）は台帳済みなので再掲しない。

## §1 件数
高0／中0／低1／要確認0（新規のみ）。

## §2 指摘

### 1. 【低・新規】改名の確定ボタンに読み上げ名が無い
- 場所：NotebookView.swift:384-386（nameLabel 内 `Button { commitRename } label: { Image(systemName: "checkmark.square.fill")...accessibilityHidden(true) }`）
- 手順：VoiceOver で持ちネタの題名をタップ→入力欄が出る→右の確定ボタンへ。
- 結果：画像を hidden にしたため、ボタンは「ボタン」とだけ読まれ何のボタンか分からない（Return キーでの確定は可能）。「改名」札（:350）には「題名を直す」の名前があり、対になる確定側だけ抜けている。grep で docs/ の既出に該当なし（notebook_intro_ending_audit_1115 は確定ボタンの挙動のみ）。
- 直し方：ボタンに `.accessibilityLabel("題名を決める")` を足す（画像側の hidden はそのままでよい）。
- 重さの根拠：読み上げ利用者だけ・Return で代替可・進行に影響なし。

## §3 問題なしと確かめた所
- 範囲外・強制アンラップ：S6bView の `Self.venueNames[venueTier]` は venueTier が switch で 0..3 に限られる（:147-155）。`ForEach(0..<4)`の `venueNames[t]` も定数範囲。NotebookView は `[Tab.chikara,.kiroku,.neta][$0]` の添字が YoseTopTabBar の3本のみ（範囲外なら落ちるが呼び出し元は3タブ固定）。yearHistory・log は ForEach／filter／reduce のみで添字アクセス無し。
- 二重実行：S6bView の「また、幕が上がる」は `finished` ガードで onFinish は1回（:236）。年表タップの advance は同じ値への代入で無害。EndingFlowView の記録は `recorded` ガード＋replay/record で1回（EndingViews.swift:43-51）。改名は onSubmit と確定ボタンのどちらか片方（commit 後は renamingID=nil で欄が消える）、renameNeta は空文字を弾く（GameSession.swift:968-974）。
- Task.sleep：S6bView:132 の `try? await Task.sleep` は、後で `counted = true` を立てるだけ（onFinish・進行の変更なし）。画面を離れても @State の更新で害なし（unreviewed_1115 で既出判断）。他に Task.sleep は3ファイルとも無し。
- 年数の矛盾：3ファイルとも「来年」を最終年の文に使っていない。S6b の回想カード「来年も、また出よう」は大会の帰りの回想（過去の場面）で最終年の現在の話ではない。図鑑・題名の「十五年」は careerYears=15 と一致（Endings.swift:31-60 の題名・ヒント・キャプション。判定側は careerYears 参照）。年表は yearHistory の行数どおりで、15年が入りきらない時はスクロール（:178）。
- 女コンビ・一人称：台詞の話者札「俺」は Names.show が kind に応じて置換、本文は直書きの一人称なし（S6b の回想3枚は「俺」が話者札のみ）。NotebookView の「相方」は `Names.partner`。図鑑の読み返しが常に男コンビになる件は既出（code_review_endings_meta_1117_v0 §1）。
- 条件文：図鑑のヒント（Endings.swift:61-72）は judge の分岐（破産・相性・決勝有無・優勝）と食い違わない（endings_meta_1117 §A で確認済み）。#6/#8「二人は近くにいた」は相性判定、#5/#6「決勝の舞台を知って」は reachedFinal。
- 読み上げ：アイコンだけのコントロールは、NotebookView の「改名」札（題名を直す）・観戦札、S6b の透明ボタン（accessibilityHidden）・EndingGalleryView の未入手札（isButton を外す）が対応済み。図鑑の閉じるは YoseHeaderBar の closeAction（共通部品）。
- kirokuWins：hanaWins から今年分を引いてから足すので今年の HANA 優勝は二重に数えない（:181-184・code_review_1107c #6 済）。
