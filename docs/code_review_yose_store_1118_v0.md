# コード点検：寄席デザイン部品＋課金ID（2026-11-18・v0）
対象：Design/YoseComponents.swift・YoseMilestoneFX.swift・YoseTokens.swift・YoseCatalog.swift、Store/StoreIDs.swift（編集・コミットなし）
結論：落ちる所（添字外・強制アンラップ）は無し。StoreIDs と Configuration.storekit は4商品とも ID・種別（非消耗2／消耗2）・価格（1000/480/100/1000）が一致。
動きの減らす対応は Button・SpeechBox・Pass/CutIn・Confetti/Burst（YoseEffects）とも対応済み。指摘は主に VoiceOver と大きい文字。
「表示のみ」＝見た目/アクセシビリティ修飾だけで直せる（ロジック・数式に触らない）。

## 指摘一覧
### #1 【中】袋文字が VoiceOver で9回読まれる
- YoseTokens.swift:80-90 `YoseOutlinedText`、YoseMilestoneFX.swift:12-26 `YoseGoldText`
- 縁取り用の Text を8枚＋本体1枚、計9枚を ZStack に重ねており、どれにも accessibilityHidden/Label が無い。例：StageFrame.swift:341「title」、IntroFlow.swift:417 アプリ名、FinalsBroadcastIntro.swift:138「頂グランプリ」が9回読み上げられうる（呼び出し側9か所のうち修飾の有無は未確認＝要実機）。
- 直し案：縁取り8枚の ForEach に `.accessibilityHidden(true)`、ZStack 全体に `.accessibilityElement(children: .ignore).accessibilityLabel(text)`（GoldText は空白入り文字列を label に渡さない：#2）。
- 表示のみで直せる：はい

### #2 【中】「予 選 通 過」等の字間スペース入り文字列がそのまま読まれる
- YoseMilestoneFX.swift:168（YoseGoldText "予 選 通 過"）、:165（"判 定 中"）、:160 付近（飾り行は label 済み）
- スペース入りだと VoiceOver が1字ずつ区切って読む。「判 定 中」は opacity 0 でも読み上げ対象のまま残る。さらに「通過」が看板・結果カード(:192付近)・ボーナス札の3か所で重複。
- 直し案：看板を `accessibilityElement(children:.ignore)`＋label「予選通過」にまとめ、「判 定 中」は revealed 後 accessibilityHidden。結果カードの「通過」は重複なので Hidden。
- 表示のみ：はい

### #3 【中】予選通過演出は VoiceOver ではタップで進められない／出口が無い
- YoseMilestoneFX.swift:146 `.onTapGesture { if finished { onFinish() } … }`
- 全画面 ZStack の onTapGesture だけで、`.isButton` trait・label が無い。VoiceOver の二本指/ダブルタップで進めない恐れ（要実機確認）。reduceMotion 時も snapToFinal 後にタップ待ちで自動では閉じない（CutIn は1.2秒で自動終了するのと不統一）。
- 直し案：`.accessibilityAddTraits(.isButton).accessibilityLabel("予選通過。次へ進む")`＋`.accessibilityAction { … }`。「画面をタップして進む ▶」の ▶ は読ませない（:135 付近を Hidden にして label に集約）。
- 表示のみ：はい（onFinish の呼び出し先の挙動は変えない）

### #4 【中】ヘッダーの「とじる」ボタン幅64pt固定で長いラベルが切れる
- YoseComponents.swift:18（Spacer 64）・:44（`.frame(width: 64, height: 28)`）
- 実使用に closeTitle: "とばす ▶"（5字）がある。12ptでも約64ptでぎりぎり、文字拡大（上限1.35倍＝16pt）では切れる/折れる。縦28固定のため2行になると文字が切れる。
- 直し案：幅は `minWidth: 64`＋`.fixedSize()`/`lineLimit(1).minimumScaleFactor(0.7)`、左のダミー Spacer も同幅を合わせるなら closeTitle の長さに連動させるか、左右対称をやめて ZStack で中央固定にする。
- 表示のみ：はい

### #5 【中】予選通過看板の金文字が大きい文字で幅オーバー
- YoseMilestoneFX.swift:168 `YoseGoldText(size: 54, tracking: 4)`、:179 `.frame(height: 118)`
- mzScaled で54→最大73pt。「予 選 通 過」（漢字4＋空白3＋字間4）は約330〜380pt、看板の内幅は約349pt−枠。xxxLarge 以上で改行/はみ出し。lineLimit・minimumScaleFactor が無い。
- 直し案：YoseGoldText に呼び出し側から `.lineLimit(1).minimumScaleFactor(0.5)`（ZStack の内側 Text に効く）、または看板を固定高さにしない。
- 表示のみ：はい

### #6 【中】予選通過画面の縦に収まらない（スクロール無し）
- YoseMilestoneFX.swift:126-133 VStack(spacing: 26)：看板118固定＋結果カード＋講評＋ボーナス札
- 標準サイズで約700pt前後。文字拡大で講評文が増えると上下が切れて、タップ誘導文・ボーナス札が画面外に出る。講評の角印『秀』（:228 scale 1.5, offset y:-18）が講評本文の右上に被る。
- 直し案：中身を ScrollView（または ViewThatFits）に入れ、dynamicTypeSize 上限（例 .xxxLarge）を掛ける。角印は右上に余白を取る。
- 表示のみ：はい

### #7 【低】YoseSpeechBox：話者名・役割名・本文が別々に読まれる／長い名前で横幅を食う
- YoseComponents.swift:309-333
- 話者名に lineLimit が無く、長い名前（審査員名など）が縦に折れ、本文領域を圧迫。VoiceOver は「相方」「谷口」「本文」と3回に分かれる。
- 直し案：話者名に `.lineLimit(1).minimumScaleFactor(0.7)`、HStack 全体に `.accessibilityElement(children: .combine)`（読み順 roleLabel→speaker→text）。
- 表示のみ：はい

### #8 【低】ボタンの沈み量ぶんの高さが有効/無効で変わる
- YoseComponents.swift:83-86,140（`depth` は無効時0、`.padding(.bottom, depth)`）
- 押せない状態に切り替わると高さが2〜3pt縮み、並ぶ要素が揺れる。
- 直し案：padding は常に shadowCard/shadowCommand 固定にして、影描画だけ opacity で消す。
- 表示のみ：はい

### #9 【低】ボタンのバッジ（badgeText）が長いラベルと重なる
- YoseComponents.swift:123-134
- バッジは右下にオーバーレイで、ラベルが大きい文字で右端まで来ると重なる。command(68pt)でも「出張中」程度は収まるが、拡大時は要確認。
- 直し案：バッジを `.overlay(alignment: .topTrailing)` に移し、ラベル側に trailing padding を足す。
- 表示のみ：はい

### #10 【低】コントラスト
- 無効ボタン文字：disabledText(8C867B) on ginNezu(D4CFC4) 約2.3:1（無効状態は WCAG 免除だが、判別しにくい）。YoseComponents.swift:93。
- outlineShu タグ：shu on shu12%（約4.3:1・12pt bold）／outlineHai：haiSumi 約4.5:1ぎりぎり。YoseComponents.swift:228,231。
- 演出：「判 定 中」kin 35%（YoseMilestoneFX.swift:165）は過渡的な飾りで許容、予選通過ヘッダ「◆ …◆」kin 25%（点灯前）も同様。
- 直し案：disabledText をやや濃く（例 0x77716A）、shu タグの背景を 8% にするか文字を enji に。
- 表示のみ：はい

### #11 【低】ヘッダー題が見出しとして扱われない
- YoseComponents.swift:25 `Text(title)`
- `.accessibilityAddTraits(.isHeader)` が無く、ローターで見出し移動ができない。
- 直し案：title に `.accessibilityAddTraits(.isHeader)`。
- 表示のみ：はい

### #12 【低】死んだ状態・引数（使われない値）
- YoseMilestoneFX.swift:33 付近 YosePassCelebrationView：`shownPower`（:73 付近で更新するが画面に出さない）・`threshold` は参照されない（数字を出さない仕様変更の名残）。`power` もドラムロールの内部計算のみ。
- 直し案：表示しないなら state と Task.sleep ドラムロール内の withAnimation を削る（挙動は変えない）／仕様なら据え置き。
- 表示のみ：はい（ただし演出タイミング＝ゲーム内容の判断はオーナー）

### #13 【低】未使用部品
- YoseHarigamiCard（YoseComponents.swift:209-216）は YoseCatalog 以外から参照なし。YoseKifudaCard は GachaView のみ。YoseDiagonalStripes は AbilityUpView＋自身のみ。
- YoseGoldText／YoseRoundHanko／YoseCoreGlow／BigSuccessRays は MilestoneFX 内部のみ使用（外部参照なし＝正常）。
- YoseCatalogView は RootView.swift:81 の `MZ_UI=catalog`（DEBUG）から使用＝正常。
- 直し案：YoseHarigamiCard は消さず据え置きでよい（見本に載る）。気になるなら削除は低リスク。
- 表示のみ：はい

### #14 【低／要確認】YoseGauge の NaN
- YoseComponents.swift:278：`total > 0` のみ確認。value が NaN だと ratio が NaN になり `.frame(width: NaN)` の警告（落ちはしない）。
- 直し案：`value.isFinite` を条件に足す。
- 表示のみ：はい

### #15 【低／要確認】獲得倍率「1.35倍」が固定文字
- YoseMilestoneFX.swift:384 `Text("獲得 1.35倍！")`
- 実際の倍率定数（練習大成功の倍率）と食い違うと表示が嘘になる。倍率の正本を grep して参照にするか確認。数式変更ではなく表示の参照化。
- 表示のみ：はい（正本の値の確認が先）

### #16 【低】CutIn を VoiceOver が読む（一過性）
- YoseMilestoneFX.swift:299-340：allowsHitTesting(false) の帯が数百ms表示。gains 行（"種" "+6" …）が別々に読まれる。
- 直し案：演出全体を `.accessibilityHidden(true)`（呼び出し側 TournamentResultView:299 で本文テキストが別にある場合）、または1ラベル「練習大成功」だけにまとめる。
- 表示のみ：はい

## 問題なし（確認済み）
- 添字外・強制アンラップ：無し（`1...steps`・`1..<4`・ForEach(0..<15) は定数）。
- reduceMotion：ButtonStyle は沈まず色で表現（Theme.Motion.r 使用）／SpeechBox は blink 無し／PassCelebration は run() 冒頭で snapToFinal／CutIn は止め絵1.2秒で onFinish を必ず呼ぶ／Confetti・Burst は YoseEffects 側で対応。
- Task の止め忘れ：`.task` なので View 消滅で取り消し。Task.isCancelled / done の確認あり（触覚は取り消し後に鳴らない）。DispatchQueue/Timer 無し。SpeechBox の repeatForever は View 消滅で止まる。
- 装飾：YoseGauge・Canvas・光芯・集中線は accessibilityHidden 済み。判子は spoken() で読み上げ整形済み。
- StoreIDs：prefix `com.manzaigame.mvp` は project.yml:30 の PRODUCT_BUNDLE_IDENTIFIER と一致。`all` と storekit の4件が一致、agency は UI 未実装（コメントどおり）。ticketCounts の ID・消耗型扱い（StoreManager:59,95）も整合。
