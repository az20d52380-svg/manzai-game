# 週の記録の書く所と読む所の突き合わせ（code_review_2026-10-26e）

## 要点
- 書く所は3形（summarize の「第N週: 大会 札 [+N万] / …」・観戦「…（客席から）」・決勝優勝「頂GP 決勝 優勝 +N万」）。読む所は YearResultView（eventLines / stageRecord / loggedGPEntry / 「ほかN大会」）と NotebookView の戦績の行。
- 食い違いは3件（中1・低2）。単独の大会の行・GP/非GPの名前・優勝/通過/敗退/休/観戦・賞金の形はすべて正しく読めていた（4a764f1 と同じ型の名前の食い違いは他になし）。
- 3件とも表示だけで直した（数値・GameCore・golden は不変）。書く所の summarize で作った文字列を読む所に通すテストを5本足した（215 -> 220）。

## 食い違いの表
| 重要度 | 行の形 | 読む所 | 誤り | 画面 | 状態 |
|---|---|---|---|---|---|
| 中 | 1週に複数大会「A 通過 / B 敗退」 | NotebookView 戦績（line 全体を contains で札分類） | 優勝>観戦>通過>敗退>休 の優先で1札だけ。「優勝 / 敗退」は優勝に、「通過 / 敗退」は通過になる | 「今年の出場」が2大会でも1回、敗退が札に出ない。賞金は合算で1行に出る | 直した（parseLogLine で大会ごとに1行へ） |
| 低 | 休だけの行（体調ダウン / 療養） | eventLines の埋め草（見出しは大会結果のみ） | 大会が3つに満たない年に「第30週: 体調ダウン 休」が出来事に出る | 出来事欄に大会でない行が混ざる | 直した（休だけの行は埋め草にしない） |
| 低 | 休・観戦の行／複数大会の行 | 「ほかN大会」（log.count - 表示行数） | 休と観戦を大会に数え、1行に並ぶ複数大会を1つに数える | 「ほか1大会」と出るが隠れた大会が無い／数がずれる | 直した（hiddenStageCount） |

問題なしと確認した形：GP/非GPの表示名（GPName.display で書き、contains("GP 決勝") も表示名側）、敗者復活（「敗」を含むが「敗退」とは別語で誤判定なし）、決勝敗退、決勝優勝+N万（stageRecord で勝ち1）、観戦（stageRecord と戦績で除外）、loggedGPEntry（4a764f1 で修正済み）、賞金の正規表現（+N万）。

## 直した所
- GameSession.swift：summarize を static 化（テストから呼ぶため）、parseLogLine / LogPart を追加（札・賞金・大会名を「 / 」区切りで読む共通の読み手）。
- NotebookView.swift：logEntries を parseLogLine 経由に。
- YearResultView.swift：isRestOnly / hiddenStageCount を追加し、eventLines の埋め草と「ほかN大会」に使う。
- Tests/LogRoundTrip1026Tests.swift（5本）。
