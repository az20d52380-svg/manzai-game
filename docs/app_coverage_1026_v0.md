# アプリ側の表示判定テストの未カバー（app_coverage_1026_v0）

要点
- 画面の文言・状態の選び分け（年末の判・年末独白プール・体力ゾーン・弱点能力・ネタ効果など）を純関数に切り出し、11本のテストを追加。アプリ 220 → 231 green、GameCore 412 green。
- カバー率（ManzaiGame.app 全体）16.61% → 16.81%。YearResultView 7.49% → 13.56%、WeekMainView 36.18% → 36.97%。NotebookView は View の body だけ（0%）で判定関数なし。GameSession は 77.43% のまま（残りは debug 用が中心）。
- テストが見つけた不具合：0 件（期待と違う文言は出なかった）。

## 最小の切り出し（挙動は同じ・数値/GameCore/golden は触らない）
- YearResultView: `reachStamp` / `reachSubText` / `notEntered` / `yearEndPool`（private の reach/reachSub/notEnteredGP/yearEndLine から static へ）
- WeekMainView: `staminaZone` / `vesselFull` / `weakAbilityName` / `lullText` / `netaEffectText`

## 足したテスト（Tests/Coverage1026AppTests.swift）
1. testReachStampPriorityOrder：優勝 > 夜逃げ > 解散 > 決勝 の優先順
2. testReachStampNamesTheRoundLostNotPassed：敗れた回戦名（2回戦敗退〜準決勝敗退）と通過扱いの真偽
3. testNotEnteredGPOnlyWhenNoRoundPassedAndNoEntryLogged：不出場の条件（年末の不出場の誤表示）
4. testReachSubTextPerOutcome：判の下の副文言（各結果）
5. testYearEndPoolSceneByOutcome：独白の場面名（貧乏/解散/躍進/停滞・fame 30・3回戦通過の境界）
6. testYearEndPoolFirstYearDropsLastYearLines：1年目は「去年」を含む行が出ない
7. testStaminaZoneBoundaries：20/50 の境界
8. testVesselFullNeedsBudget：器の満了（予算なし/0 は満了なし）
9. testWeakAbilityNameIgnoresFlatAndPicksLowest：差1未満は弱点なし、ちょうど差1は出す
10. testLullTextByNetaAndShoot：ネタ無し/撮影中/ネタ有りの文言
11. testNetaEffectText：ネタ作り・喫茶店・ネタ見せ・フリーライブ・休養の効き表示

## 見つけた不具合
なし。
