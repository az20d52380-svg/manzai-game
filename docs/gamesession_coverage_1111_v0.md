# GameSession 網羅の穴埋め（11/11 定期・sonnet）

## 足したテスト（8本・ManzaiGame/Tests/GameSessionCoverage1111Tests.swift）
1. pickIndex：count 0 は 0
2. choose：自由週でない段（大会入口）では何も変えない
3. 借金の知らせ：浅い段・同じ段では戻らず、深い段へだけ進み保存される
4. markRiftHintShown：二度目は何もしない
5. retireAfterWin：優勝前は何も起きない（セーブも不変）
6. winHeadline：連覇は末尾の連続だけ数える（優勝／2連覇／3連覇）
7. ensureStageNetaDefault：持ちネタ無しは何もしない
8. costOfNextStep：粒が尽きていれば全能力で nil

## 網羅（GameSession.swift・xccov）
前 81%（1332/1651）→ 後 81%（1345/1651）。+13 行。

## 残りの未通過（行単位 約 270 行）の分類
- DEBUG フック（debug* 系・debugSelfTest・debugSelfPlay・MZ_NAMES/MZ_COMBI 等）：約 260 行（L228-231・L1472-1939）
- 防御用・到達しない：L557（costOfNextStep 60 回暴走ガードの nil）・L780（選択肢なしフレーバーの break）・L1336（セーブの encode 失敗）
- 本体の不具合：見つからず
