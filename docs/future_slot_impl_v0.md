<!-- 将来枠 実装 v0 / 2026-07-20 / 4.8（Mac CLIセッション） -->
<!-- オーナー指示「将来枠を実装して。1-b/1-c は着手前に相談」を受けた実装記録＋相談票。 -->

# 将来枠（Phase2）実装 v0

`full_buildout_plan_v0.md` の「将来枠（Phase2・当面やらない）」を、オーナー指示で解凍。
golden 影響で **①実装済（golden-inert）／②要オーナー判断（UXフォーク）／③着手前相談（golden全再測）** に仕分けた。

## §0 要点3行

1. **0016 翌週バフ・0023 成長天井減算・0022 稽古ロック＝実装完了**（各1コミット・0012 相性凍結と同型の golden-inert・gen_golden 再生成でバイト一致・swift test 72件green・iOS BUILD SUCCEEDED＋目視）。
2. **0022 週奪い＝乙（稽古ロック）で確定・実装済**（オーナー2026-07-20 確定）。撮影を受けた週は稽古5枚がグレー＋「撮影で埋まる」＝稽古枠だけ奪う（バイト/休むは可）。
3. **1-b＝試遊後に判断／1-c＝やらない**（オーナー2026-07-20 確定）。golden 全再測の代償ゆえ据え置き。詳細 §3。

## §1 実装済（golden-inert・commit/push済）

「0012 相性凍結」で確立した **inert フィールド型**の複製。新フィールドは既定0/nil＝ゲートは恒等no-op、
gen_golden はイベント非発火＝フィールドは golden で常に既定＝**期待値バイト一致**（規律A step3-4 実測）。

### 0016 書けた一本B「翌週バフ」（commit ccb4d93）
- `GameState.netaBoostWeeks`（既定0）＋`EventEffect.netaBoostNextWeek(Int)`＋`WeekRunner.applyNetaRevise` 乗算ゲート＋`tickNetaBoost`（GameSession 週送り）。
- `GameConfig.netaBoostMult=1.6` / `netaBoostWeeks=2`【仮】。B に `.netaBoostNextWeek(config.netaBoostWeeks)` 追加。
- golden 非経路の根拠: `applyNetaRevise` は gen_golden がネタ個体を持たない＝**呼ばれない**＋イベント非発火で `netaBoostWeeks` 常に0＝乗算×1.0。

### 0023 正社員A「成長天井減算」（commit be9bcc6）
- `EventEffect.growthCeiling(Double)`＝`growthBudget` を増減（負で縮む・nil no-op・下限0）。A に `.growthCeiling(-config.regularJobCeilingCost)` 追加。
- `GameConfig.regularJobCeilingCost=1.5`【仮】（year1 budget≈6.0 の約1/4）。
- 定職＝芸に注げる時間が減る＝その年の器が縮む機会費用。以後の能力上昇が残予算で頭打ちになる実挙動をテストで固定。

## §2 実装済: 0022 週奪い機会費用（乙・オーナー確定 2026-07-20）

「撮られる仕事」を受けると、その週は撮影で拘束され**稽古1週を失う**（旧・体力-15 近似は撤去）。
検討した3案（甲 新WeekAction／乙 稽古ロック／丙 現状維持）から**乙を採用**（golden risk 最小・新WeekAction不要・0012/0016と同型で保守一貫）。

### 実装（0012 と同型の inert フィールド）
- `GameState.preoccupiedWeeks`（既定0）＋`EventEffect.preoccupyNextWeek(Int)`＋`WeekRunner.tickPreoccupied`（GameSession 週送り）。
- 0022A: `華+2/知名度+1/所持金+1万/体力-5`＋`.preoccupyNextWeek(config.photoShootPreoccupyWeeks=1)`。旧 `体力-15` は撮影疲れの `-5` に。
- **enforcement は UI層**（`GameSession.choose` の train→rest remap＋`WeekMainView` の稽古カード自動グレー＋「撮影で埋まる」）＝`WeekRunner.resolveAction`（golden経路）には一切触れない＝gen_golden はイベント非発火＝`preoccupiedWeeks` 常に0＝稽古ロックは一度も効かない。
- 目視: `MZ_UI=cards`（compat 10・高所持金で週頭確定イベント帯を外す）で稽古5枚グレー＋「撮影で埋まる」を確認。撮影を受けた週だけ・バイト/休むは可（稽古枠だけ奪う）。

## §3 着手前相談: ネタ 1-b／1-c（golden全再測）

§1/§2 と決定的に違う点＝**perform の合否スコア or 乱数消費順に触る＝gen_golden の3年バイトが全部変わる**。
inert フィールドの逃げが効かない＝Python正典→GameCore→gen_golden 再生成→**全下流バランスの再アンカー**まで一括で要る。

### 1-b 型×審査員相性をスコアに
- 中身: `netaScoreBonus` に「その大会の審査員傾向×ネタの型」の相性項を足す。
- コスト: **golden全再測**＋endgame/dynasty 全ラインの再アンカー（審査員傾向が入ると通過境界が動く＝勝ち上がり分布が変わる）。
- 規律A手順（Python鏡像→GameEngine→gen_golden→swift test）は同じだが、**リスクは 1-a の比でない**（1-a は「選択ネタが無い区間は補正0」で golden 経路を保てたが、審査員相性は大会ごとに常時効く＝golden キャリアにも効く）。
- 推奨: **試遊で「型を選ぶ楽しさ」が物足りない時だけ**着手（決点5「当面乗せない」を維持）。

### 1-c buzz に客層依存＝新規乱数
- 中身: buzz 算出に客層（会場・時間帯）依存のランダム項を足す。
- コスト: **golden全再生成＋乱数消費順の再設計**（perform に新しい draw が1本増える＝runYear/WeekRunner/gen_golden の消費順を全て再スレッド）。将来枠で**最も高リスク**。
- 推奨: **入れない**（決点6）。buzz は Phase 0 の決定論（実力×完成度従属）表示指標のまま。客層感は演出/テキストで出す（規律B-5＝体感は数値の前に演出で解く）。

### オーナー確定（2026-07-20）
1. **0022 = 乙（稽古ロック）**＝実装済（§2）。
2. **1-b = 試遊後に判断**＝当面着手しない（golden 全再測の代償ゆえ）。試遊で「型を選ぶ楽しさ」が物足りない時に再検討。
3. **1-c = やらない**＝据え置き。buzz は Phase 0 決定論の表示指標のまま。客層感は演出/テキストで（規律B-5）。

数値は全て【仮】。0016/0023/0022 の倍率・コストは sim 較正で確定する（規律B-4）。
