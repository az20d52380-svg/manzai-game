# GameSession 網羅の穴埋めテスト（11/09）

テスト: ManzaiGame/Tests/SessionCoverage1109Tests.swift（8本）。本体は無変更。

## 測定の結論
run_coverage.sh（GameSession.swift 80%）の 0回の行を DEBUG ブロック外で絞ると、実行行で未通過なのは
557（costOfNextStep の60段ガード後の nil）・700（StageInfo.length 既定値）・780（選択肢なしフレーバーの break＝呼ばれない設計）・1336（保存 encode 失敗のログ）の4行だけ。
残りの 0% は `#if DEBUG`（debug* 系）。他は `??` の右辺などの暗黙クロージャ（領域単位の穴）。
557・780・1336 は通常の入力では到達できない防御コードのため対象外。

## 足したテスト
1. testStageInfoDefaultLengthIsMiddle — StageInfo.length の既定が .中尺
2. testRestoreResetsRiftWarnWhenFiredButNeverSeen — 予告を見ないまま閉じたセーブは復元で未発火に戻る
3. testRestoreKeepsRiftWarnWhenChoiceMade — 予告を選んだ後のセーブは復元しても発火済み・選択が残る
4. testParseLogLineHugePrizeFallsBackToZero — 賞金の桁が Int 超過でも 0 扱いで落ちない（札は維持）
5. testParseLogLineOnlyPrizeGivesEmptyTitleAndRestMark — 賞金だけの行は題が空・札「休」・賞金5
6. testParseLogLineEmptyLine — 空行でも1件返る（休・賞金0）
7. testLoggedGPEntryFallsBackWhenRoundNamesEmpty — gpRoundNames が空なら既定名「GP1回戦」で記録を探す
8. testLoggedGPEntryFalseForEmptyLog — 記録が空なら GP 出場なし

## 見つけた不具合
なし。
