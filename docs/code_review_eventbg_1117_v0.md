# コード点検：EventBackgrounds / EventBackdropTable / YoseMotion / GachaRatesView（2026-11-17・読み取り専用）

対象：ManzaiGame/Sources/Design/EventBackgrounds.swift（1769行）、Design/EventBackdropTable.swift、Design/YoseMotion.swift、GachaRatesView.swift。突き合わせ先：GameCore/Sources/GameCore/ChoiceEvent.swift、Store/GachaState.swift、Store/StageOutfit.swift、ChoiceEventOverlay.swift、Tests。
既知（重複を避けた）：code_review_2026-10-19l／19m／dialogue_motion_1117／unreviewed_1115／1108d。19m の指摘のうち、看板の切れ（:1483-1484 に lineLimit）、背景の縮小（designHeight=220 で描いて scaleEffect）、同値 ForEach の ID（enumerated＋offset）、Row グロー、YoseAppear の reduceMotion は**すでに直っている**ことを確認した。
結論：落ちる・無限ループ・0除算・NaN は見つからなかった。高は0件。

## 高
なし。

## 中
1. **ガチャ割合ページの注記が初回確定と食い違う**
   - 場所：GachaRatesView.swift:67（「割合は1回ごとに独立で、前の結果や回数で変わりません（天井の交換を除く）」）／Store/GachaState.swift:106（`totalPulls == 0` なら `drawFirst`＝特別が必ず出る）。
   - 起きる場面：初回の1回は特別100%（:46 に別行で書いてある）だが、割合表の注記は「回数で変わらない」と言い切っている。表示と実際の食い違いに当たる文面。
   - 直し案：注記を「（初回の1回と天井の交換を除く）」にする。文面は docs/release/gacha_rates_page.md も同期。
   - 判断：要（文面の確定はオーナー）。
2. **イベント背景の高さアニメで、背景の木全体が毎フレーム作り直される**
   - 場所：ChoiceEventOverlay.swift:149 `.animation(Theme.Motion.appear, value: footerReady)` ＋ EventBackgrounds.swift:244-253（GeometryReader の size 変化）。
   - 起きる場面：選択肢の帯が出る時に高さが 320→196〜262 に動く間、GeometryReader の中で背景の body（ForEach・RadialGradient・blendMode 多数）が毎フレーム再評価される。古い端末で一瞬カクつく可能性（実測はしていない）。さらに `Theme.Motion.r` を通していないので「視差効果を減らす」でも動く。
   - 直し案：`.animation(Theme.Motion.r(...), value:)` にする。重ければ背景に `.drawingGroup()`（blendMode の見た目が変わらないか要確認）か、高さのアニメを止めて切替にする。まず実機で計測。
   - 判断：不要（直しは機械的）。計測してから。

## 低
1. **割合の表示関数が浮動小数の誤差に弱い（今の値では起きない）**
   - 場所：Store/GachaState.swift:36（`(p * 100).rounded(.down) / 100`）。
   - 起きる場面：今の割合（12.00／7.50／3.33／60／30／10）は誤差が出ず、GachaTests:22-24 が通る。将来、着数や段の割合を変えて 1.15 のような値になると、`1.15*100` が 114.999… で切り捨てられ「1.14%」と出る。
   - 直し案：整数（万分率）で計算してから文字列にする。または +1e-9 を足してから切り捨て。
2. **段の合計が100でない時の抽選フォールバックが黙って色替えになる**
   - 場所：GachaState.swift:119-125（`x < tierPercent` の繰り返し・最後に `pick(.iro)`）。
   - 起きる場面：tierPercent の合計が100未満になる変更で、残りが黙って色替えに寄る（表示と実際がずれる）。GachaTests:20 が合計100を見ているので、今は守られている。
   - 直し案：現状維持でよい（テストが番人）。`assert(sum == 100)` を足すなら DEBUG のみ。
3. **段の表示合計と段内の合計が 0.01% ずれる**
   - 場所：GachaRatesView.swift:45-56・67。特別は段 10.00% だが衣装別は 3.33×3＝9.99%。切り捨てで一貫しており、注記（:67「小数第3位以下は切り捨て」）に書いてある。違法ではない向き（表示≦実際）。対応不要。
4. **背景の一部が幅が極端に狭い時に負のフレームを出す**
   - 場所：EventBackgrounds.swift:1466（`w / 8 - 3`）、:1475（`groundY - 34`）。
   - 起きる場面：w が24未満の初回レイアウト（親が幅0のとき）。SwiftUI が負のフレームを0扱いにして警告を出すだけ。高さ側は :244-253 で `max(h,1)`・drawH≥220 になったので負にならない。
   - 直し案：`max(0, …)` を付ける。見た目に影響なし。
5. **高さが0〜1 の時、背景を巨大な幅で組む**
   - 場所：EventBackgrounds.swift:246-252。`h = max(geo.size.height, 1)` なので s=1/220 となり、`scene` を幅 w×220 で一度レイアウトしてから縮める。落ちないが初回だけ無駄。
   - 直し案：`geo.size.height < 1` なら Color.clear を返す。
6. **夕方の斜光だけ strength を掛けていない**
   - 場所：EventBackgrounds.swift:173-174（`LinearGradient … opacity(0.22)`）。夕の上からのグラデが strength に連動しない（夜は連動）。
   - 起きる場面：strength=0 の銭湯（nightStrength）を夕にした時だけ。銭湯は実イベントから未使用（19m §1-3）なので実害なし。
7. **YoseNumberBounce／YoseExpPing の戻しタイマーを取り消さない**
   - 場所：YoseMotion.swift:34・95。0.08 秒以内に値が連続変化すると先の戻しが後の跳ねを早く消す。既知（dialogue_motion_1117 #7）と同種。表示のみ。
8. **`YoseStampImpactModifier` の触覚は reduceMotion でも鳴る**
   - 場所：YoseMotion.swift:14-16。動きではなく触覚なので許容（19l #8 既知）。

## 要確認
1. **EventBackdropTable のイベント→背景の対応漏れはなし**
   - ChoiceEventKind は38個、表の `switch` は default なしでコンパイラが網羅を強制。ト書きの場所・時間帯との一致は ManzaiGame/Tests/EventScene1108Tests.swift:23-37 が全イベントで検査している。コメントが「推定」の3件（preTournamentEve／peerFoldedChair／greenroomSilentTen）だけ、ト書きに場所か時間の記述がなく、背景はオーナーの目視判断待ち。
   - `.train`／`.sento` に割り当てが0件の件は 19m §1-3 の既知（将来のイベント用に残すか削るかの判断待ち）。
2. **ガチャ確率表示と定数の一致は確認済み**
   - 表示は GachaCatalog（tierPercent 60/30/10・items 数 5/4/3・price1=100・price10=1000・loginGoal=7・pityGoal=40・shardGain/Cost）から生成しており、手書きの数値は GachaRatesView に無い（:21-22 の文面も定数補間）。天井・ログイン・かけら・黒紋付対象外の説明は GachaState の実装と一致。テスト（GachaRatesPage1107Tests／GachaTests:20-24）が表示を固定している。食い違いは「中 1」の初回確定の文面のみ。
3. **ダークモード・Dynamic Type**
   - 背景も GachaRatesView も固定色（YoseColor・hex）で描き、ダークで色が反転する経路が無い（`.primary`／`.secondary` 不使用）。文字は YoseFont（上限1.35倍）。背景内の飾り文字は 1483 のほか「寄　席」「出口」「受付」（:1412/:1571/:1631）が lineLimit なしだが、2〜3字で枠（96〜120pt）に余裕があり切れない。GachaRatesView の `row` は長い衣装名で折り返すだけ（`Spacer` と数値は縮まない＝非常に長い名前で数値が潰れる可能性はあるが、現状の名前の長さでは問題なし）。
4. **アニメ／負荷**
   - EventBackgrounds は TimelineView・Canvas・repeatForever・Timer を使わない静的な木（19m §4 のとおり再確認）。YoseMotion の動きは onChange 駆動で止まらない処理なし。`Theme.Motion.r` は `UIAccessibility.isReduceMotionEnabled` を見るので、YoseMotion の各部品は reduceMotion に対応（ExpPing は専用の分岐で白光りに置換）。
