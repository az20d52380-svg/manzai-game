# コード点検 2026-10-19j（行動の札・値札・押せる条件まわり・9回目）

対象：CommandData.swift（CommandCatalog）・WeekHint.swift・StageFrame.swift・WeekMainView の札まわり（actionCard／actionCardLabel／categoryTile）・AbilityUpView の値札・借金／体を壊した知らせ。GameCore の判定（applyTraining／applyRest／resolveAction／applyWeekEnd）と突き合わせた。コードは変えていない。

**件数：4件（確度 高 3／中 1）**。既出（テレビ慣れの未表示 = 19b §2-7 など）は除く。

## §1 確度 高

1. **お金が足りない稽古の札に、緑の「体力 +N」が出る（実際は何も起きない札なのに）**
   - WeekMainView.swift:1002-1006（`after = previewAfterPour`／`stamDelta`）・GameSession.swift:386-389（`previewState` の払えない時の休養フォールバック）
   - 手順：所持金8万円未満・体力が満タンでない状態で「練習」を開く → 「エントリーライブに出る」「大喜利ライブに出る」「カラオケボックスで声出し」（費用8万）。`previewState` は払えない稽古を完全休養に差し替えるので、`stamDelta` が休養の回復量（最大+60）になり、「お金が足りない」の赤字の下に「体力 +60」の緑ピルが並ぶ。喫茶店・ファミレスの札も同じ。押しても blocked で何も起きない。
   - 直し案：`!v.affordable` の時は `stamDelta = 0`（moneyDelta は元々0）にして体力ピルも出さない。
   - 確度 高

2. **休む札の「体力 +N」が、部屋の回復上乗せ・銭湯の回数券を含まない（実際より少なく出る）**
   - WeekMainView.swift:1006（`stamDelta = rests[r].recovery` で上書き）／GameEngine.applyRest（:143-158 で `roomHeals[room]`（完全休養・気分転換）と `itemSentoRecovery`（回数券あり）を足す）
   - 手順：部屋を上げる（room>0）か銭湯の回数券を買う → 「家で寝る」は実際 60+上乗せ回復するが、札は「+60」のまま。回数券は全休みに効くのに札に出ない。
   - 直し案：`rec` に `config.roomHeals[room]`（完全休養・気分転換のみ・範囲内）と、回数券があれば `itemSentoRecovery` を足す。または満タン時だけ名目値にし、それ以外は `after.stamina - s.stamina` を使う。
   - 確度 高

3. **体調ダウンで稽古が休みに差し替わった週も「相方と話した」扱いになる（ヒントの週数が0に戻る）**
   - GameSession.swift:316-319（`weeksWithoutPartner` を行動の「選択」で判定）／WeekRunner.resolveAction:290-307（体力<50 の稽古は確率で完全休養に差し替わる）
   - 手順：体力30〜49で「相方と合わせる」を選ぶ → 体調ダウン発動（抽選）→ 実際は休養なのに `.train(.ネタ合わせ)` なので `weeksWithoutPartner = 0`。「最近、相方とゆっくり話していない。」が出るべき週に出ない。
   - 直し案：`runner.resolveAction` の後で判定する（`runner.lastTrainingDone == .ネタ合わせ` か `.rest(.相方と過ごす)` が実行された時だけ0に戻す）。
   - 確度 高

## §2 確度 中

4. **借金の知らせの文言（100万・50万・80万・あと50万・あと20万）が GameConfig.bankruptLine と別管理の直書き**
   - WeekMainView.swift:1404-1406／GameSession.swift:1080（`debtTier` の −50万・−80万）／GameConfig.swift:197（`bankruptLine = -1_000_000`）
   - いまは一致している（−100万「未満」で夜逃げ＝「越える」の言い方も合う）。`bankruptLine` を調整すると、知らせの数字（あと◯万）だけが古いまま残る。
   - 直し案：`(-bankruptLine)/10_000` と段の閾値から文言を組み立てる。
   - 確度 中（今は表示と実際が一致・設定を動かした時だけずれる）

## §3 見たが問題なかった所

- 札の「押せる」条件：`affordable`（`spec.cost <= 0 || money >= cost`／`restCosts`）は applyTraining（`money < cost` で拒否）・applyRest（`money < cost` で完全休養へ）と境界（ちょうど払える）まで一致。
- 体力ゲート：`stamina < staminaGate`（ちょうど20は押せる）は resolveAction の判定と同じ向き。`categoryTile` と `actionCard` の `gated` も同条件で、稽古拘束（preoccupiedWeeks>0）も choose 側の休養化と対応。
- 札の名前（`practiceLabel` と CommandCatalog）は Training の全ケースを網羅（switch が非網羅になる所なし）。配列の範囲外・強制アンラップは対象ファイルに無し（`roomHeals` は範囲確認つき）。
- WeekHint：`injuryWarn` は GameConfig から取得。livingCost は `livingCostDue`（部屋上乗せ・やりくり込み）。週の判定は applyWeekEnd と同じ `week % livingInterval`（1年48週・4週間隔で年またぎのずれなし）。
- StageFrame.swift：見た目のみ（数値・判定なし）。`UserDefaults` の seenKey 以外に本編へ影響する物なし。DEBUG の `MZ_*` 参照は対象外も含め全て `#if DEBUG` 内（AbilityUpView・EndingViews・ChoiceEventOverlay・FinalistAnnounceView・Endings・FinalsBroadcastIntro・FinalsPresentationView を確認）。
- AbilityUpView の値札／押せる判定：`costOfNextStep`（pourStep の再生）で押せる／押せないを決め、足りない粒の表示は押せない行にだけ出る。ExpDisplay.cost の「持ち分を超えない」補正で「持ち14・必要15なのに押せる」は出ない。
- 小さな注意（実害なし）：WeekHint.line の `money < 0` 判定が2か所に重複（:34 と :36 の2つ目は到達しない）。`CommandCatalog.netaWrite` は呼び手なし。

## 直した所（10/19 自走・ビルド OK・目視は未）
- §1〜§3 を直し案どおりに。§4（借金の知らせの数字の直書き）は今は一致＝設定を動かす時に一緒に直す。
