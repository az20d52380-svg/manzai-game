# R4 リサーチ：ジュース／手触り（visual overhaul v1・2026-10-08）

> 状態：完成（§0〜§5）。コード・git は未変更。
> 前提：`docs/fun_uiux_overhaul_v0.md` §3 の他社23本比較・P1〜P8は重複調査しない。ここは「押した瞬間の反応」と「溜めと解放」に絞る。

## §0 既存資産の棚卸し（Juice.swift／週の獲得バースト）

読んだ範囲：`Juice.swift` 全文・`Theme.swift` 全文・`WeekMainView.swift` 週実行〜バースト〜行動カード・`TournamentResultView.swift` 判の演出・`ChoiceEventOverlay.swift` 全文・`IntroFlow.swift`・`YearResultView.swift` 冒頭・`SoundManager.swift`。以下は grep で数えた現状（2026-10-08・ビルド `dc68c26` 時点）。

### 0-1 既にある部品（再発明しない）

| 部品 | 中身 | 現在の使用場所 |
|---|---|---|
| `PressableStyle` | 押下 scale 0.95＋明度−10%・0.08s easeOut／復帰 spring(0.25, 0.6)・押下の瞬間に `SE.cursor`・`enabled:false` で沈まない | 週メイン・ネタ帳・名付け・決勝の次へ等（11ファイル） |
| `ShakeEffect` | 押せない時の ±3pt×2往復・0.15s ＋ `SE.deny`（振動なし） | 週メインの行動カードのみ |
| `.punch(on:peak:)` | 値が変わった瞬間 scale 1→peak→1（spring 0.22/0.45 → 140ms 後に 0.30/0.65） | 週の実力/相性数字(1.35)・所持金(1.18)・決勝の合計(1.16)と票数(1.3) |
| `ParticleBurst` | Canvas＋TimelineView(60fps)。spark(life0.9s・26粒)／confetti(life1.7s・44粒)。終了後は TimelineView 破棄。決定論ハッシュで RNG 非消費 | 週の獲得(26粒)・大会通過(44粒)・決勝(1箇所) |
| `SpeedLinesBurst` | 24本・0.32s・alpha最大0.5の集中線 | 週の獲得のみ |
| `.screenFlash` | 0.32s で白→透明（strength 0.30〜0.45） | 大会通過・決勝の押印 |
| `.screenShake` | 0.38s 減衰揺れ（intensity 7〜10pt） | 大会結果の判（勝敗とも）・決勝 |
| `Haptics` 3段 | tick=light／confirm=medium／rare=heavy（`UIImpactFeedbackGenerator`）。**閲覧操作は無振動**が規則 | 週実行(tick)・大会判(confirm/rare)・名付け・年次判・決勝 |
| `contentTransition(.numericText())` | 数字の桁送り | 週の2本バー・所持金・目標バナー・決勝・割り振り |
| `Theme.Motion` | press0.08／quick0.18／std0.25／emph0.40／hold0.60 と `emphSpring(0.4, 0.75)` | 全体 |
| `SE` 24種 | tap/cursor/deny/pop/grain/kira/money/drumroll/tada/taiko/taiko2/fanfare/applause*/cheer*/laugh… | 週・大会・決勝 |

### 0-2 週の二拍実行（現在の「溜めと解放」の手本＝本作の最良の見本）
- 押下 → 引き抜き 0.12s（カードが 1.06 倍に膨らんで消える）→ Beat1 発話 0.7s（**画面タップで即スキップ＝早送り**）→ `Haptics.tick`＋週送り → Beat2：獲得チップ最大3枚が下から stagger 0.07s 刻み・emphSpring で立ち、**同時に**集中線 0.32s＋火花26粒（チップ色）＋`SE.grain`/`pop`（収支が動けば `SE.money` も）→ 1.2s 見せて退場 0.25s。
- つまり「押す→溜め0.12〜0.82s→解放1.2s」。入力遮断は Beat1/Beat2 のみで、Beat1 はスキップ可。**この構造が既に正解**で、問題は他の画面に無いことと、伸び0の週は解放が空になること（README の W1〜W3「舞台に立つ」実力10→10）。

### 0-3 週メイン以外の「手触りの欠落」（grep の事実）
- **選択肢イベント（`ChoiceEventOverlay`）**：選択肢ボタンは `.buttonStyle(.plain)`＝**押しても沈まず音もしない**。1行ずつ送るタップ（`advance()`）に SE・ハプティクス・行の出現アニメ（`withAnimation` なし）が無い。選択結果の効果チップ・数字ジャンプ・音が無い（README 05_event_choice_live_w03_result／close）。Sound は画面を開いた時の `SE.event` 1回のみ。
- **イントロ（`IntroFlow`）**：タップで 0.18s クロスフェードのみ。SE なし・ハプティクスなし・文字の出現アニメなし。「タップで進む」は白 45% の極小。タイトルの「はじめる」だけ `PressableStyle`。
- **年次リザルト（`YearResultView`）**：判の出現（spring 0.35/0.55・`Haptics.confirm`）と stagger 0.15s 刻みの8ブロックはあるが、`ParticleBurst`／`screenFlash`／`screenShake` は未使用。優勝でも負けでも判の演出が同じ（色だけ違う）。数字は静止＝カウントアップ・桁送りなし。
- **大会結果（`TournamentResultView`）**：既に「波形 0.9s → ドラムロール 0.7s → 判の叩きつけ（scale 2.3→1・シェイク・通過のみフラッシュ＋紙吹雪44粒＋rare）→講評 0.4s→残り 0.6s」の溜め→解放を持つ。**ここは作法が完成している**（0.9+0.7=1.6s の溜めはスキップ不可＝§2 原理2で扱う）。
- **ハプティクス実装**：`UIImpactFeedbackGenerator(...).impactOccurred()` を毎回生成して即発火（`prepare()` なし）。`sensoryFeedback` 未使用。3段とも単発の衝撃で、**勝ちと負けで触覚の「質」を変える（成功型・失敗型の複数タップ波形）ことも、「ドドン」の2連打も、今はできていない**。
- **等級アップの演出**（`gradeCrossed`＋`SE.rankup`＋`Haptics.confirm`）は `AllocationView`（現行フローでは通らない画面）にしか無い＝週メインには昇格の瞬間が無い。
- **`PunchModifier` の peak 1.35** は小さな数字ピルには効くが、結果画面の大数字（決勝642点の金文字等）には未適用の場所がある。

### 0-4 「既存の何を全画面に広げれば効くか」の先出し結論（詳細は §2）
1. `PressableStyle`＋`SE`＋`Haptics.tick` の三点セットを **イベント選択肢・イントロ・ネタ選択・年次の「もう一度」** へ（`.plain` を全廃）。
2. 週の「二拍」（短い溜め→チップ＋音＋粒）を **イベントの選択結果** と **年次リザルト** へ。
3. `.punch`＋`numericText` を **結果画面の大数字**（年次の3数字・賞金・点数）へ。固定秒数のカウントアップは `Animatable` な数字 View＋`withAnimation` で足りる（TimelineView 不要）。
4. `screenFlash`/`screenShake` は **判の一撃だけ**に残し増やさない（既に大会結果・決勝で足りている）。
5. 新規は最小：①行単位のせり上がり出現＋`▼`（読ませる画面の共通部品）②固定秒数の数字カウント③演出設定（`Juice.swift` の4部品を一括で無効化）④`BurstChip` の共有化。いずれも View 層のみ・GameCore 不変。

## §1 観点表（作品×6観点）

凡例：【S】＝今回の調査で出典を確認（§5 の番号）／【二】＝二次情報（レビュー・フォーラム・第三者分析のみ。開発者本人の発言ではない）／【知】＝筆者の既知で今回は裏取りしていない（実機確認が要る）。
注意：開発者本人の一次発言が取れたのは少ない。Balatro の音程上昇・Mega Crit のファストモード動機・Peglin の発射演出は一次が見つからなかった（§5 末尾に空白を明記）。数値は【仮】扱いで読むこと。

### 1-A 作品別（画面の作り×手触り）

| 作品 | 明るさと色 | 書体と文字サイズ | 会話画面の部品 | 結果・勝利演出 | テンポ | 育てている実感の見せ方 |
|---|---|---|---|---|---|---|
| **Balatro** | 背景は暗い渦だが、「読むもの」（カード・数字ブロック）は高彩度で背景から切り離す。chips は青・mult は赤の二色が数字の地になる【知】。強い手ほど数字が燃える＝色が熱くなる【S4・S5】 | ピクセル系の大きな数字ブロック【知】 | ほぼ無し。説明はカードに触れた時のツールチップ【知】 | 加点を**1枚ずつ前に出して**加算→ジョーカーが左から順に作動→最後にチリンと合計が着地【S4】。炎の演出は友人の提案で採用【S5】 | 序盤は1手数秒。倍率が積まれるほど加速し音程が上がる【S4】。速度設定（0.5〜4倍）・低減モーション・画面揺れ設定を持つが、4倍でも遅いという声が出る【S6・二】 | ジョーカーの棚が育ち、同じ手でも出る数字の桁が変わる＝**画面の数字そのものが成長記録**【知】。スコアの事前表示を隠し「出す瞬間」に期待を寄せる【二：S7】 |
| **Slay the Spire** | 暗い地に高コントラストのカード。枠色で役割を分ける（攻撃/スキル/パワー）【知】 | 本文は読みやすい書体、HP・ブロックは大きめ【知】 | イベント＝絵＋短文＋選択肢ボタン。**選択肢ボタンに効果が書いてある**（HP・金の増減を押す前に読める）【知】 | 勝利→報酬を1項目ずつ（金→カード）選ばせる【知】 | ファストモードが設定にあり、デッキが膨らむほど待ち時間が不満になる【二：S8】。小さな攻撃演出は短い | デッキ・遺物が常に上部に並ぶ＝積んだものが見える。敵の次の行動が常時見える【知・前回v0 S4/S5】 |
| **Peglin** | 明るく彩度の高いピクセルアート【知】 | 大きな数字・短い文字【知】 | NPC は短い台詞のみ【知】 | 弾を撃っている間に**ダメージ数字が溜まり、着地で一括して敵へ放たれる**＝「溜め→解放」の小型版【知】 | 1発あたり数秒。ペグに当たるたびに小さな音と数字【知】 | オーブの種類が増える・1発の数字が大きくなる＝手元の道具が育つ【知】 |
| **Vampire Survivors** | 暗い舞台に鮮やかな弾と宝石。弾の密度が画面を埋める【知】 | 小さいピクセル文字（読ませる量が少ない）【知】 | ほぼ無し。レベルアップは3〜4択のカード【S9】 | 宝箱が**スロット風に開く**（1/3/5個）。作者のスロット業界経験が元【S9】 | レベルアップで一度止まり選ぶ→再開。止めて読ませる所と、止めない所を分けている【知】 | 武器が増えるほど画面が弾で埋まる＝**強さが画面密度として見える**【知】 |
| **Luck be a Landlord** | 明るい高彩度のピクセルアート・点滅色。レビューは「高エネルギー」と評す【S10・二】 | ピクセル文字・コイン数字が大きい【知】 | ほぼ無し（短い台詞）【知】 | スロット回転→シンボルが**1つずつ光ってコインがポップ**→合計。家賃日が期日【知】 | 演出時間を倍率で変える速度設定がある（利用者の言及）【二】 | 盤面のシンボルと稼ぎが増える＝毎回の合計が大きくなる【知】 |
| **ウマ娘の育成** | 明るいパステルでチャンキーな枠。育成画面は明るい【知】 | 数字・コマンド名とも大きく太い【知】 | 立ち絵＋台詞枠＋選択肢。トレーニング各コマに**上昇幅の印（＋の数）を事前表示**【S11・二】 | 育成完了で評価点とランク。レース後にライブ【知・前回v0】 | **スキップ最大速度が速すぎて、イベント文が読めないレベル**という指摘（2023年の高速化）【S12】 | ステータス表・育成評価のランク文字。毎ターン数字が増える【知】 |
| **パワプロ系サクセス／カイロソフト系** | 明るく暖色・チャンキー（本作の週メインの手本）【前回v0】 | 丸ゴ・太字【前回v0】 | 顔グラ＋名前＋白い台詞枠（本作の週メインが採用済み）【前回v0・WeekMainView.adviceBox】 | 完成・昇格の瞬間に小さなジングルと評価点【前回v0 S13/S23/S24】 | 1サイクル数秒〜5分で「毎回小さな審判」【前回v0 P7】 | 能力のランク文字・評価点の更新【前回v0】 |

### 1-B 講演・資料の要点（数値は発言者の例であり本作に転用する時は【仮】）

| 資料 | 要点 | 本作での読み |
|---|---|---|
| **Juice it or lose it**（Jonasson＆Purho・2012）【S1・二】 | 素朴なブロック崩しに、イージング・伸縮・色・パーティクル・音を**足していく**だけで「生きた」手触りになる。合言葉は「最小の入力で最大の出力」 | 週メインの Beat2 はこの作法そのもの。足りないのは**他の画面に足していないこと** |
| **The art of screenshake**（Nijman/Vlambeer・2013）【S2・二】 | 手触りは**多数の小さな調整の積み重ね**。例：撃つと音・薬莢・弾・カメラ反動6px・揺れ+4（すぐ減衰）・武器の反動・ヒット時に**10〜20ms**だけ止める・敵のノックバック・戦場に残る物（永続感） | 揺れは**衝撃の1点**にだけ強く、しかも短く減衰。本作の判・優勝の揺れ（7〜10pt・0.38s）は妥当で、増やす方向ではない |
| **Don't Juice It or Lose It**（Folmer Kelly・GDC Europe 2012）【S3】 | 飾りを足すと生き生きするが、没入や文脈を失う代償がある | 本作は「読ませる」画面が命。ジュースは**読む時間の外**に置く（§4） |
| **応答時間の3限界**（Nielsen・NN/g）【S13】 | 0.1秒＝直接操作している感覚／1秒＝思考の流れが切れない／10秒＝注意が切れる | 押下の沈み・音は0.1s以内（PressableStyle は 0.08s）。溜めは**1秒前後**まで、それ以上は進捗か見せ物が要る |
| **Peggle の優勝演出**【S14】 | 最後のオレンジペグ消去で「Ode to Joy」＋ドラムロール＋文字。**仮置きの素朴な版を試遊者が好んだため残し**、最後の球へのズームを足した | 派手さではなく「溜め→解放」の**形**が効く。仮置きで足りる |
| **勝ちに偽装した負け（LDW）研究**（Dixon ほか 2010／2013）【S15】 | 負けなのに勝ち演出（祝いの音・光）を付けると、覚醒反応が勝ちと同程度になり、勝ちを多く見積もる | **負けを祝わない**。本作の敗退は「静けさが重さ」で正しい。ただし「敗退でも画面が同じ暗さ」は別問題（§2 原理4） |

### 1-C 観点表から見える本作の差（要約・詳細は §2）
1. **効果の予告と着地の同居**：Slay the Spire・ウマ娘は「押す前に増減が読め、押した後にその通り動く」。本作の週メインは同じ作り（カードに伸びが出る→Beat2 でチップ）。**イベント選択肢だけ**がこの文法から外れている（予告なし・着地なし）。
2. **加算を1段ずつ見せる**：Balatro・Luck be a Landlord・Peglin は合計を一括で出さず、**要素を順に光らせて合計へ**。本作の年次リザルトは8ブロックを0.15s刻みで出すが、**数字そのものは動かない**。
3. **強さが画面に出る**：Balatro＝数字の桁、Vampire Survivors＝弾の密度、Peglin＝1発の数字。本作は「実力 10→10」の週があり、**成長が画面に出ない週がある**（README W1〜W3）＝ここは演出でなく見せ方（相性・ネタ・体力・器を含めた週の総括）で補う。
4. **読ませる所は止める**：Vampire Survivors は選ぶ所で止まる／ウマ娘は高速化しすぎて読めなくなった。**止める所と飛ばせる所を分ける**。


## §2 本作にそのまま効く原理 5つ

書式：各原理に ①原理 ②手本の具体 ③**既存の何を広げるか**（§0 の実コード）④本作のどの画面にどう当てるか ⑤該当スクショ ⑥SwiftUI 実現手段。出典番号は §5。数値は全て【仮】。
前提：本作の最小展開単位は「1週1タップ」。1週の演出は Beat1 なし 約1.6秒／あり 約2.3秒（`WeekMainView` の sleep 合計：0.12＋0.7＋1.2＋0.25）。48週で演出だけ 77〜110秒。**ここを伸ばさず、他の画面を週メインの水準に引き上げる**のが方針。

### 原理1　全タップに返事する（沈み＋音を全部品に・触覚は「確定」だけ）

- **原理**：押した瞬間（0.1秒以内）に画面・音のどちらかが必ず返る。同じ種類の操作は同じ返事。0.1秒を超えると「自分が動かした」感覚が薄れる【S13】。「最小の入力で最大の出力」が手触りの出発点【S1】。
- **手本の具体**：Vlambeer は1発に音・反動・揺れ・ヒット停止（10〜20ms）を重ねる【S2】。触覚は「操作の確認と意味のある出来事」に絞り、同じ出来事には同じ触覚を返す（Apple HIG の趣旨だが、HIG 本文は今回取得できず【知】）。
- **既存の何を広げるか**：`PressableStyle`（沈み0.95＋明度−10%＋`SE.cursor`・0.08s）を、**`.buttonStyle(.plain)` が残る9箇所**（`ChoiceEventOverlay` 2・`NotebookView` 2・`StageViews` 2・`FinalsPresentationView` 1・`SettingsView` 1・`NetaSelectionView` 1）へ。`Haptics.tick` は「週の実行」だけで使っているが、**イベントの選択肢確定・「閉じる」**にも付ける（実行に当たるため。「閲覧は無振動」の既決は崩さない＝文字送りタップには付けない）。
- **画面への当て方**：
  - イベント選択肢（2〜3個）：押下で沈む＋`SE.cursor`、確定で `Haptics.tick`＋`SE.tap`。
  - **文字送りのタップ**（イントロ・イベント・週頭の掛け合い・決勝の「タップで進む」）：次の行が 0.18s で下から 6pt せり上がって出る＋軽い SE 1つ（既存 `SE.cursor` の流用で足りる）。触覚なし。
  - 「タップで進む」の極小灰色文字は、`▼` が小さく上下する表示に置換（週頭の掛け合い `banterBox` が既に `▼` を使っている＝同じ文法に揃える）。
- **該当スクショ**：`05_event_choice_live_w03_after`（区切り線の下が空のまま）・`05_event_choice_live_w03_result`・`02_intro_01〜03`・`05_event_0011`。
- **SwiftUI**：
  - `.buttonStyle(PressableStyle())`（既存）。
  - 行の出現：`ForEach` の行に `.transition(.move(edge: .bottom).combined(with: .opacity))`＋`withAnimation(Theme.Motion.appearQuick)`（既存トークン）。
  - `▼`：`.phaseAnimator([0, 4]) { v, y in v.offset(y: y) } animation: { _ in .easeInOut(duration: 0.55) }`（iOS 17・`phaseAnimator` は位相を自動で循環し、位相ごとに animation を返せる【S17】）。
  - 触覚：`.sensoryFeedback(.impact(weight: .light), trigger: chosenID)`（iOS 17。`SensoryFeedback` は impact／success／warning／error／selection 等を持つ【S16】）。UIKit 系の `Haptics` を残すなら、生成器を static 保持して**発火の少し前に `prepare()`**（Apple は prepare 直後の発火では遅延が減らないと明記＝「選択肢が出た時」「ドラムロールが鳴った時」に呼ぶのが正しい）【S16】。
  - 注意：`.sensoryFeedback(.press(...))` は **iOS 26 以降**で、deploymentTarget が iOS 17 の本作では `#available` が要る＝使わず PressableStyle の `onChange(isPressed)` を続ける【S16】。

### 原理2　「溜め→解放」の二拍を、効果が出る全ての瞬間へ

- **原理**：結果は「溜め（短く・飛ばせる）→解放（全部見せ切る）」の二拍で出す。**飛ばすのは溜めであって解放ではない**。解放が空だと壊れて見える。1秒前後が思考の流れを切らない限界【S13】。
- **手本の具体**：Balatro は加点を1段ずつ前に出し、最後に合計を着地させる【S4】。Peggle は最後のペグでドラムロール→曲→文字、仮置きの素朴な形を試遊者が好んで残した（派手さより**形**）【S14】。Vampire Survivors は宝箱で一度止めて開く【S9】。Peglin は撃っている間に数字を溜め、着地で一括放出する【知】。
- **既存の何を広げるか**：`WeekMainView` の二拍（引き抜き 0.12s→Beat1 発話 0.7s・タップで飛ばせる→週送り→Beat2 チップ最大3枚＋集中線＋火花）と、`TournamentResultView` の「波形 0.9s→ドラムロール 0.7s→判の叩きつけ→講評 0.4s→次へ 0.6s」。
- **画面への当て方**：
  1. **イベントの選択結果**（最大の穴）：選んだ瞬間に 0.15s の押し→効果チップ（既存の「相性 +1」「ネタ +8」「体力 −20」の文言をそのまま再利用＝**新文言なし**）を最大3枚立ち上げ→1.0s→選択後の会話。チップの元は `applyEventChoice` の前後で `session.state` を比べるだけで取れる（View 側・乱数非消費。`lastGains` 系は `choose` でしか更新されない＝イベントでは自前で差分を取る）。
  2. **週の伸び0**：W1〜W3 の「舞台に立つ」は 実力 10→10 で、`makeBurstChips` は体力チップ1枚だけになる（`04_week_w01_tap_burst` は実力が動かず撮れていない）。コードを読むと、**体力が減っただけの週でも `chips` は空にならず（`体力 −30`・地は card2）、集中線＋オレンジの火花＋`SE.pop` が鳴る**（`particleFire += 1`・火花色は card2 地のとき gainOrange に置換）＝損だけの週が小さく祝われる【コード上の事実・実機未確認】。直し方は2段：①集中線・火花・`SE.grain/pop` は**得がある時**（実力↑・相性・ネタ・体力＋・所持金＋）だけにし、体力減のみの週はチップを静かに出す（粒・集中線なし）＝LDW を避ける【S15】。②伸びが無い週の「手応え」は、動いたもの（体力・所持金・ネタ）をチップにするか、無ければ立ち絵の一言だけを返す【要 drama-voice：既存の心の声の再利用を優先】。
  3. **Beat2 を畳めるようにする**：今は `burstHold` で退場まで約1.45秒、次のカードが押せない。Beat1 と同じく**画面タップで Beat2 の退場へ即移って入力を戻す**。ただしチップが立ち上がってから 0.5s は畳まない（最小表示時間＝解放を見せ切る）。48週を打つ人ほど効く（Balatro・Slay the Spire で高速化の要望が出る理由と同じ【S6・S8・二】）。
  4. **年次リザルト**：判（0.4秒後に spring）→ 数字3つが順に着地（原理3）→ 独白。今は8ブロックが0.15s刻みで出るだけで、数字は静止。
  5. **等級アップの瞬間**（数字が小さい本作で、増えない代わりに用意できる最大の「解放」）：`gradeCrossed`＋`SE.rankup`＋`Haptics.confirm` は `AllocationView` にしか無く、現行フローは自動注ぎでその画面を通らない（`GameSession.swift` 107行付近のコメント）＝**週メインには昇格の演出が存在しない**。Beat2 の先頭に「等級アップ」チップ（ランク文字入り・金縁）を立て、`SE.rankup`＋`Haptics.confirm`。判定は View 側で `Theme.rank(今)` と `Theme.rank(今 − lastGains.amount)` を比べるだけ（乱数非消費・GameCore 不変）。新文言は不要（既存の「センス G→F」形式で足りる／要すれば【要 drama-voice】）。
- **待ち時間の目安【仮】**：溜め 0.3〜0.8s（大会本番だけ 1.6s まで）／解放 1.0〜1.5s／入力遮断の合計 1.5s 以内（本番を除く）／段階開示は 3段まで（週＝チップ3枚、年次＝数字3つ）／大会本番の 1.6s の溜めは**タップで畳める**ようにして良い（畳んでも判の叩きつけは必ず再生）。
- **該当スクショ**：`05_event_choice_live_w03_close`（効果が出ないまま閉じる）・`05_event_narration_w05`（W4 の Beat2 が被さって見えない）・`04_week_w01_tap_burst`・`04_week_w02`・`12_year_result_lose_top`。
- **SwiftUI**：
  - 直列は既存の `.task(id:) { … Task.sleep … }`（`WeekMainView` 方式）で足りる。
  - 1本の時間軸にまとめるなら `keyframeAnimator(initialValue:trigger:)`（各プロパティを別トラックで動かせる。**途中でキーフレームを変えない・content は毎フレーム評価されるので重い処理を置かない**）【S16・S17】。位相が3つ程度（隠れ→ポップ→定着）の単純な状態遷移なら `phaseAnimator(_:trigger:)` が向く【S17】。
  - チップの stagger は既存 `Theme.Motion.emphSpring.delay(Double(i) * 0.07)`。
  - **共有化**：`BurstChip`（`WeekMainView.swift` の `private struct`）と `burstOverlay` を `Juice.swift` に昇格して `GainChipStack` にすれば、イベント・年次から同じ見た目で使える。
  - 畳む操作：Beat1 と同じ全面 `Color.clear.contentShape(Rectangle()).onTapGesture { beatTask?.cancel() }`（`WeekMainView` 106〜112行の既存パターン）。

### 原理3　数字は「溜まってから止まる」：大きい数は固定秒数の桁送り、小さい数は一発の跳ね

- **原理**：増えた数字は一瞬で切り替えず、**桁が回って止まる**。ただし回す時間は数の大きさに比例させず固定（0.5〜1.0s）。小さな整数（実力 10→11）は桁送りでなく「跳ね＋色＋バー」で効かせる。
- **手本の具体**：Balatro は合計が回りながら音が上がり、最後にチリンと着地する【S4】。Vampire Survivors は宝石の取得音と経験値バーの充満で数字より先に「増えた」を伝える【S9：Wikipedia は宝石で経験値が満ちると記すのみ。音の記述は二次】。
- **既存の何を広げるか**：`.contentTransition(.numericText())`＋`.punch(on:peak:)` は、週の実力/相性（1.35）・所持金（1.18）・決勝の合計（1.16）・票数（1.3）で既に効いている。**効いていない所**＝年次リザルトの「賞金 年計／知名度／最終所持金」（`total()` は静止の `Text`）、大会結果の「賞金 +50万」、決勝以外の点数表示。
- **画面への当て方**：年次リザルトの数字3つを、判の着地後に**左から 0.25s ずつずらして**カウントアップ（各 0.8s・合計 1.2s 以内）。終点で `.punch`＋`SE.money`（賞金）／`SE.grain`（知名度）。大会結果の賞金も同様。**小さな整数のカウントアップはしない**（原理の限界は §3）。
- **該当スクショ**：`13_year_result_champion`・`12_year_result_lose_bottom`（数字3つが静止）・`09_tourney_result_pass_a`（賞金 +50万 静止）。
- **SwiftUI**：
  - 方式A（滑らか・推奨）：`Animatable` に準拠した数字 View（`animatableData: Double` を `Text(Int(x).formatted())` に流す）＋ `withAnimation(.easeOut(duration: 0.8)) { shown = target }`。固定秒数で補間される。
  - 方式B（桁が1段ずつ回る）：`.contentTransition(.numericText(value: shown))` に、`Task` で 6〜10 ステップ×70ms の段階更新を与える。
  - 終点：`.punch`（既存）＋`Haptics.tick`（3つ同時には鳴らさない＝順に）。
  - Reduce Motion 時は即値（原理5）。

### 原理4　勝敗は「量」と「地の明暗」で言い分ける：負けは祝わず、待たせない

- **原理**：勝ち＝彩度・明度・物量（粒・光・音数）を上げ、**余韻が明るい**。負け＝物量を下げて彩度を引くが、**勝ちに偽装しない**。祝いの光・音を負けに付けると、体は勝ちと同程度に反応し、勝ちを多く見積もる【S15】。そのうえで負けでも**次の手の導線は早く・明るく**出す。
- **手本の具体**：Peggle の演出は「最後の1手」だけが桁違いに大きい（量が結果に比例）【S14】。Balatro は強い手ほど数字が燃える（炎は友人の提案で採用）【S4・S5】。LDW 研究は負けへの祝いを避ける根拠【S15】。
- **既存の何を広げるか**：`TournamentResultView` は既に「通過＝紙吹雪44粒・フラッシュ・`Haptics.rare`・会場拍手／敗退＝重い `SE.taiko2`・拍手なし・粒なし」で**量の差はできている**（これは崩さない）。足りないのは次の3点。
  1. **地の明暗が勝敗で同じ**：`08_tourney_result_fail_a` と `09_tourney_result_pass_a` は、どちらも暗い紫黒の地で、色相（朱／鈍色）しか違わない。さらにイベント・イントロも同じ暗紫＝**「暗い紫」が「ふだんの夜」と「負け」の両方の色になっていて、勝敗の言い分けに使えない**。勝ち＝フラッシュ後に地が明るい金クリームへ遷移して**残る**／負け＝地を暗く沈めず、夕暮れ系の低彩度の暖色（彩度を約0.6まで引く）に据え置く。
  2. **年次リザルトは優勝でも判の色が変わるだけ**（`13_year_result_champion`）：優勝のときだけ判の着地に `ParticleBurst(.confetti)`＋`screenFlash`＋`Haptics.rare`（既存部品の呼び出しのみ）。敗退は判のみ・揺れなし。
  3. **決勝の7人開示が毎回同じ強さ**：`advance()` は1人開くたびに `slamFire`（揺れ8pt＋フラッシュ0.30）。**1〜6人目は弱く（揺れ4pt・フラッシュ0.12）、7人目（トリ）と過半数到達だけ最大**にして階層を作る（量が重要度に比例）。
  4. **負けの後を待たせない**：敗退の「次へ」の出現を勝ちより早く（今は勝敗とも 0.4＋0.6s）。負けは 0.3s で導線を出す。
- **該当スクショ**：`08_tourney_result_fail_a/b` と `09_tourney_result_pass_a/b`（地が同じ暗さ）・`10_finals_win_07_champion`（華やかだが地は暗い）・`12_year_result_lose_top` と `13_year_result_champion`・`18_ending_s6b`・`10_finals_win_05_final3`／`06_votes`。
- **SwiftUI**：
  - 「色が引く／満ちる」：`.saturation(_:)`・`.brightness(_:)` を `withAnimation(.easeOut(duration: 0.4))` で動かす（勝ち 1.0→1.15／負け 1.0→0.6）。
  - 「余韻が明るい」：`screenFlash` の終端で `@State var glow` を立て、背景の `RadialGradient` の opacity と地色を遷移させて残す。
  - 量の階層：`screenShake(trigger:intensity:)`・`screenFlash(trigger:color:strength:)` は既に強度引数を持つ＝呼び出しで強弱を付けるだけ。
  - 触覚の質：`UIImpactFeedbackGenerator` は単発。`.sensoryFeedback(.success)`／`.error` は複数タップ型の波形で、勝ち/負けの質感差が出る見込み【知・実機確認要】。`impactOccurred(intensity:)` で強さも段階化できる【知】。

### 原理5　ジュースは「読む時間」の外に置く：予算・畳める・止められる

- **原理**：文章が出ている間は画面を動かさない。1画面に主砲は1つ。入力を止める時間は1.5秒以内で、畳める。そして**利用者が止められる**。
- **手本の具体**：Folmer Kelly は飾りが没入と文脈を損なうと指摘【S3】。Wayline は読みやすさ・疲労・音のマスキングを挙げ、重要な操作に絞って強弱を付け、無効化の選択肢を用意するよう勧める【S18・二】。ウマ娘は高速化の結果「イベント文が読めない」と書かれた【S12】。Balatro は画面揺れ・低減モーション・速度の設定を持つ【S6・二】。Xbox の指針は揺れ・点滅の無効化手段を求める【S19・二】。Vlambeer のヒット停止は 10〜20ms＝**止めるのは一瞬だけ**【S2】。
- **既存の何を広げるか**：`Juice.swift` の4部品（`ParticleBurst`／`SpeedLinesBurst`／`screenFlash`／`screenShake`）は**呼び出し側を変えず**に、4部品の内部で「演出オフ・Reduce Motion」を見て無効化できる（現状 `accessibilityReduceMotion` の参照はコード全体でゼロ。`SettingsView` は BGM/SE の2本だけ）。
- **画面への当て方**：
  - 設定に「演出（揺れ・光・粒）」のオン/オフを1つ足す。OS の「視差効果を減らす」がオンの時は既定でオフ。
  - **文章表示ルール**：文章が出てから動くものは `▼` だけ。揺れ・フラッシュ・粒は「文章の前」か「切れ目」。文字単位のタイプライター表示は採らない（行単位のせり上がりのみ）。
  - 既読の短縮：同じカードの Beat1 の一言は既に「直近4週に出していなければ」だけ（`lastBeatWeek`）＝この方針の先例。他の演出にも広げる場合は同じ作り。
  - 揺れ・フラッシュは「判・優勝・決勝の確定」の3種に限定（既存の使用箇所のまま・増やさない）。
- **上限【仮】**（決勝の「タップ駆動の開示」はユーザーのペースなので除き、代わりに強弱の階層を付ける＝原理4）：揺れ 1画面1回・10pt以内・0.4s以内／フラッシュ 1画面1回・強度0.45以内・0.35s以内（点滅は1秒に3回未満【S20・二】）／粒 同時60粒以内・2.0s以内／集中線 0.35s以内／カウントアップ 同時3つ・合計1.2s以内。いずれも現状コードの最大値（揺れ10pt・フラッシュ0.45・粒60・集中線0.32s）の内側。
- **該当スクショ**：`05_event_choice_live_w03_result`（読ませる画面）・`02_intro_02`・`10_finals_win_05_final3`・`10_finals_win_06_votes`（1枚ごとに揺れ）。
- **SwiftUI**：`@Environment(\.accessibilityReduceMotion)`（Reduce Motion の参照）＋`@AppStorage("fx_on")`（設定）を4部品の冒頭で見る。パーティクルは既存どおり `TimelineView(.animation(minimumInterval:))`＋`Canvas` を**終了後に破棄**（電池）。常時ループは `▼` の1個だけに限る。

### 2-補　SwiftUI 部品の早見（deploymentTarget iOS 17 前提）

| 目的 | 手段 | iOS | 本作での位置づけ | 注意 |
|---|---|---|---|---|
| 押下の沈み＋音 | `PressableStyle`（既存） | — | 全ボタンへ | `.plain` を残さない |
| 値が変わった瞬間の跳ね | `.punch`（既存） | — | 大数字・年次・賞金へ | 小さな整数は peak 1.35、大きい数は 1.16 |
| 桁送り | `.contentTransition(.numericText(value:))` | 17 | 年次・賞金 | 段階更新と併用 |
| 連続カウント | `Animatable` な数字 View＋`withAnimation` | — | 年次・賞金 | 固定秒数 |
| 数拍の位相（隠れ→ポップ→定着） | `phaseAnimator(_:trigger:)` | 17 | チップ・▼・判 | 位相は3つ程度 |
| 複数プロパティを別々の時間軸で | `keyframeAnimator(initialValue:trigger:)` | 17 | 判の叩きつけ等 | content は毎フレーム評価。途中変更不可 |
| 触覚（標準） | `sensoryFeedback(_:trigger:)` | 17 | 確定・押印 | `.press/.release` は iOS 26 |
| 触覚（低遅延） | `UIImpactFeedbackGenerator.prepare()` | 10 | 溜めの最中に準備 | 直前の準備は効かない・数秒で idle |
| 粒・集中線 | `Canvas`＋`TimelineView`（既存） | 15 | 既存のまま | 終了後に破棄 |
| 衝撃 | `screenShake`／`screenFlash`（既存） | — | 3種の確定瞬間のみ | 設定で無効化 |
| 彩度・明度の遷移 | `.saturation`／`.brightness`＋`withAnimation` | — | 勝敗の言い分け | 0.4s |


## §3 効かない原理と理由

本作の事実：実力は初期10・1年の上限は+6前後（成長の器・`fun_uiux_overhaul_v0.md` §2）／相性は5〜16／週に動く整数は0〜1／1週1タップで連鎖なし／％は出さない（既決）／片手縦持ち／題材は漫才（読ませる・間が命）。

| # | 他作品の手法 | 効かない理由 | 代わりに使うもの |
|---|---|---|---|
| 1 | **数値インフレの快感**（Balatro の桁が膨らむ・Vampire Survivors の弾の密度・Peglin の1発の数字）【S4・S9・知】 | 本作の数字は小さく、週に動く整数は0〜1。桁が回る爽快感は作れない。大きい数は賞金・所持金・決勝点だけ（原理3で限定） | **等級が上がる瞬間を一発の見せ場に**（§2 原理2-5：G→F の昇格＝ランク文字のバッジが跳ねる＋`SE.rankup`＋金縁。W22 の初昇格が「おっ」止まりだった＝前回v0）。バー・成長の器の満ち方 |
| 2 | **％・確率で煽る**（ウマ娘の失敗率表示【S11・二】など） | **既決で出さない**（％は冷める）。Balatro のようにスコア予告を隠して「出す瞬間」に期待を寄せる方向【S7・二】は、％を出さない既決と相性が良い | 溜め（波形・ドラムロール・審査員の顔）で緊張を作る。週カードの「実力 ↑」「相性 +1」の予告（既存）は残す |
| 3 | **連鎖・倍率の加速**（Balatro の加速とピッチ上昇【S4】・Peglin の連鎖【知】） | 本作の週は1タップ1結果で連鎖がない。長く積む演出は読む時間を奪う | 条件付き・小さく：Beat2 のチップ最大3枚を立てる時だけ、`SE.pop` を3音の上昇にする程度（優先度低） |
| 4 | **長いスロット風の開封**（Vampire Survivors の宝箱【S9】・Luck be a Landlord の回転【知】） | 射幸性の演出。LDW 研究が示すとおり、当たり外れの光と音は負けを勝ちに見せる方へ働く【S15】。本作の結果は物語で、読ませるのが主。溜めは1秒前後が限界【S13】 | 大会本番の 1.6s の溜め（既存）が上限。それ以外は 0.3〜0.8s |
| 5 | **アクションの強い揺れ・ヒット停止・集中線連打**（Vlambeer【S2】） | アクションではない。縦持ちで端末ごと揺れると親指位置がずれる。10〜20ms の凍結は SwiftUI では作りにくく効果も小さい | 既存の揺れ1発（7〜10pt・0.38s）で足りる。増やさない |
| 6 | **常時の環境ジュース**（Balatro の渦・CRT・弾幕）【S6・知】 | 暗い地を前提に成立する手。本作の課題は「明るい週メインと暗い他画面のちぐはぐ」で、暗い地に常時動くものを足すと逆行する。電池・可読性も悪化 | 既存の「光の中の塵」（`StageScene`）程度。粒はバースト後に破棄（既存） |
| 7 | **速度倍率オプション**（Balatro・Slay the Spire・ウマ娘の高速化）【S6・S8・S12】 | 本作は1週 約1.6〜2.3秒、Beat1 は直近4週に出していない時だけ、タップで飛ばせる。倍率を足すと「速すぎて読めない」（ウマ娘の指摘）の危険の方が大きい | Beat2 を**タップで畳める**ようにする（原理2）＋既読の短縮 |
| 8 | **Core Haptics の独自波形** | 工数・電池・触覚オフの利用者・端末差（iPad は触覚非対応との指摘【S21・二】）。標準の impact／success／error で足りる | 3段（tick／confirm／rare）を保つ。`prepare()` だけ入れる |
| 9 | **パチンコ・スロット語彙の演出**（光・メダル・点滅）【S14：Peggle はパチンコ由来だが採用は素朴な形】 | 題材が漫才。笑いの語彙は「客席の反応（どっ・拍手・静寂）」。点滅は光過敏の危険もある【S20・二】 | 既存 SE に cheer／applause／laugh がある。敗退の「静けさが重さ」を保つ |
| 10 | **全ステータスに数字ポップ** | 数字を減らす既決（実力・相性の2本バー）に逆行 | 変化があった項目だけチップ（既存の最大3枚） |

## §4 「読める時間を奪わない」ジュースの作法（チェックリスト）

数値は全て【仮】。右端は現状コードとの照合（○＝満たす／△＝一部／×＝満たさない・未実装）。

| # | 作法 | 数値 | 現状 |
|---|---|---|---|
| 1 | 押下の反応は 0.1s 以内（沈み＋音） | 0.1s【S13】 | △ `PressableStyle` は 0.08s だが、`.buttonStyle(.plain)` が9箇所に残る（イベント選択肢など） |
| 2 | 全ボタンが同じ返事（沈み＋`SE.cursor`） | 全部品 | × 同上 |
| 3 | 文章が出ている間、動くのは `▼` だけ | — | ○ 週頭掛け合いの `▼` は静止。他は「タップで進む」の静止文字 |
| 4 | 文字は行単位で出す（文字単位のタイプライター表示は採らない） | — | ○ 行単位 |
| 5 | 入力を止める時間は 1.5秒以内かつ畳める（本番の溜めを除く） | 1.5s | △ Beat1 は飛ばせる／**Beat2 は約1.45秒・畳めない**（`burstHold`） |
| 6 | 溜めを飛ばしても解放は必ず再生する | — | △ 大会本番の溜め 1.6s は飛ばせない |
| 7 | 揺れ・フラッシュは1画面1回・強弱で階層（決勝のタップ駆動は 1〜6 弱／7 最大） | 揺れ≤10pt・0.4s／光≤0.45・0.35s | △ 大会結果は○。決勝は毎回同じ強さ（8pt＋0.30） |
| 8 | 粒は同時60以内・2.0s以内。終了後は描画を破棄 | 60粒 | ○ 最大60粒・1.7s・自動破棄 |
| 9 | 数字のカウントは固定秒数・同時3つ以内 | 合計1.2s | × 年次リザルト・賞金は静止（未実装） |
| 10 | 勝敗の量差：勝ち＝粒・光・拍手／負け＝静けさ。負けを祝わない | — | ○ 大会結果・決勝／× 年次（優勝でも判の色だけ） |
| 11 | 負けの後は導線を早く出す | 0.3s | × 勝敗とも 0.4＋0.6s |
| 12 | 触覚は3段（tick＝実行／confirm＝確定／rare＝稀）。閲覧は無振動 | 3段 | ○ `Haptics` 3段・規則どおり |
| 13 | 触覚の `prepare()`（溜めの最中に準備） | 溜めの 0.3s 前 | × 毎回生成して即発火 |
| 14 | 見た演出は短くする（既読短縮） | — | △ 週 Beat1 の「4週に1回」のみ |
| 15 | 利用者が止められる（演出オフ・Reduce Motion） | 設定1つ | × `accessibilityReduceMotion` の参照ゼロ・設定は音量2本のみ |

## §5 出典一覧

凡例：**本文**＝ページ本文を取得／**要約**＝検索結果の要約のみ（本文未確認）／**二**＝二次情報。数値や発言は、ここに書いた範囲に限る。

- **S1 Juice it or lose it**（Jonasson＆Purho・2012）
  - GDC Europe 2012 セッション予告 https://www.gamedeveloper.com/business/gdc-europe-2012-details-the-top-sessions-for-next-week-s-show（要約）
  - 再現デモ Juicy Break https://crcdng.itch.io/juicy-break（要約・本文は404）
  - 紹介記事 https://roblog.co.uk/2024/03/juicy-games/（本文・ただし中身は薄い）／ https://rpgplayground.com/research-making-a-juicy-game/（要約）
  - 講演動画そのものは未視聴。「最小の入力で最大の出力」は要約由来。
- **S2 The art of screenshake**（Nijman/Vlambeer）
  - Nuclear Throne の1発の内訳（カメラ反動6px・揺れ+4・ヒット停止10〜20ms ほか）https://infovore.org/?p=5275（本文・Rock Paper Shotgun のインタビュー由来であり講演本編ではない）
  - 一覧 https://kenney.nl/learn/must-see-videos-for-indie-developers（要約）／ファン再現 https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects（要約・二）
- **S3 Don't Juice It or Lose It**（Folmer Kelly・GDC Europe 2012）https://gamedeveloper.com/design/video-indies-resist-the-urge-to-juice-it-or-lose-it-（本文）
- **S4 Balatro の採点演出** AV Club https://www.avclub.com/balatro-hones-the-art-of-making-numbers-go-up（本文・二：チップ→倍率の順・ジョーカーごとに音程と速度が上がる・数字が燃える）
- **S5 LocalThunk の開発年表**（炎の演出は友人の提案・2023年3月）https://localthunk.com/blog/balatro-timeline-3aarh（本文・一次。ただし演出の記述はこの1点のみ）
- **S6 Balatro の速度・低減モーション・画面揺れの設定**（二）
  - https://steamcommunity.com/app/2379780/discussions/0/4201364524144843418/（本文・利用者の声のみ、開発者の返信なし）
  - https://steamcommunity.com/app/2379780/discussions/0/4201364375109001844 ／ https://mp1st.com/news/balatro-update-1-07-shuffles-out-this-may-16 ／ https://www.familygamingdatabase.com/accessibility/Balatro（要約）
- **S7 Balatro の「事前スコアを隠す」意図**（LocalThunk の「Rube Goldberg」発言の引用を含む video essay）https://gmtk.substack.com/p/balatros-cursed-design-problem ／ https://www.buzzsprout.com/1913363/14030214/transcript（要約・二）。第三者分析 https://blakecrosley.com/guides/design/balatro は筆者の再構成が混じる（音階・ミリ秒の数値は裏取りなし＝**本書では使っていない**）。
- **S8 Slay the Spire のファストモード**（二）https://steamcommunity.com/app/646570/discussions/0/2549465882935485677 ／ https://github.com/houeland/SuperFastMode（要約。Mega Crit 本人の動機の説明は見つからず）
- **S9 Vampire Survivors**（宝箱の演出は作者のスロット業界経験が元・3〜4択のレベルアップ）https://en.wikipedia.org/wiki/Vampire_Survivors（本文）
- **S10 Luck be a Landlord**（レビューが「高エネルギー・点滅色」と評す）https://www.pocketgamer.com/luck-be-a-landlord/review（要約・二）。開発元の devlog は見つからず。
- **S11 ウマ娘のトレーニング上昇幅の印** https://altema.jp/umamusume/traininglevel（要約・二）
- **S12 ウマ娘の育成スキップ高速化（2023年9月）：イベント文が読めないレベル** https://automaton-media.com/articles/newsjp/20230904-262888/（本文）
- **S13 応答時間の3限界**（0.1s／1s／10s）Nielsen Norman Group https://www.nngroup.com/articles/response-times-3-important-limits/（本文）
- **S14 Peggle**（Extreme Fever・仮置きの素朴な版が好評で残った・最後の球へのズーム）https://en.wikipedia.org/wiki/Peggle（本文）／ https://pcgamer.com/the-making-of-peggle（本文取得できず・要約のみ）。スローモーションとの記述は二次レビュー由来で、Wikipedia はズームと記す。
- **S15 勝ちに偽装した負け（LDW）** Dixon ほか 2010 https://uwaterloo.ca/reasoning-decision-making-lab/sites/default/files/uploads/files/DixFugetal_10c.pdf（要約）／2013 の音の研究 https://sciencedaily.com/releases/2013/07/130702100348.htm（要約）／解説 https://www.psychologyofgames.com/2022/08/how-to-disguise-lousy-luck-as-an-absolute-win/（要約）
- **S16 Apple 公式ドキュメント**（本文）
  - SensoryFeedback https://developer.apple.com/documentation/swiftui/sensoryfeedback（iOS 17〜。success／warning／error／impact(weight/flexibility, intensity)／selection など）
  - `press(_:)` https://developer.apple.com/documentation/swiftui/sensoryfeedback/press(_:)（**iOS 26〜**）
  - KeyframeAnimator https://developer.apple.com/documentation/swiftui/keyframeanimator（iOS 17〜・content は毎フレーム更新）
  - `UIFeedbackGenerator.prepare()` https://developer.apple.com/documentation/uikit/uifeedbackgenerator/prepare()（直後の発火では遅延は減らない・数秒で idle に戻る）
- **S17 phaseAnimator／keyframeAnimator の使い分け** https://wwdcnotes.com/documentation/wwdc23-10157-wind-your-way-through-advanced-animations-in-swiftui/（本文・WWDC23 のノート。二）／ https://developer.apple.com/documentation/swiftui/phaseanimator（要約）
- **S18 Juice の過剰（読みやすさ・疲労・階層化）** https://www.wayline.io/blog/juice-overload-sensory-feedback-hurts-gameplay（本文・二。数値の閾値は無い）
- **S19 Xbox Accessibility Guidelines 117（揺れ・点滅の無効化）** https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/117（要約・二）
- **S20 点滅の危険（大きな面が1秒に3回を超えて点滅）** https://publish.illinois.edu/accessibility-training/?p=93（要約・二）
- **S21 SensoryFeedback の解説（iPad は触覚非対応との注記）** https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/（要約・二）

### 取れなかったもの（空白の明記）
- 講演2本の動画本編・スライド。数値は第三者の記述に依る。
- Mega Crit（ファストモードの動機）・Red Nexus（Peglin の手触り）・Trampoline Tales（Luck be a Landlord の速度設定）・Poncle（演出）の**開発者本人の一次発言**。表の【知】欄は筆者の既知で、実機での確認が要る。
- Apple HIG「Playing haptics」本文、Game Accessibility Guidelines の画面揺れ項目（404）。

### 使わなかった候補（根拠が弱い）
- 「Balatro は音階が C から G へ上がる」「±3°の傾き」「300ms の逐次発火」等の細かい数値（第三者の再構成）。
- 「パワプロアドベンチャーズは既読イベントを倍速・スキップできる」（検索要約のみで本文確認できず）。
