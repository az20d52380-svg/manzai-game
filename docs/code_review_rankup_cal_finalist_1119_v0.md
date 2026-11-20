# コード点検：YoseRankUpOverlay / CalendarView / FinalistAnnounceView（2026-11-19・読み取り専用）

要点3行
1. 新規 15件（中5・低10）。落ちる穴（添字外・強制アンラップ・0除算・NaN）は無し。
2. 一番重い：CalendarView が ScrollView 無しで固定高の表（43pt×12行）＋凡例を積むので、小さい画面・大きい文字で凡例が画面外に出る（#7）。同格で、FinalistAnnounce の並びが幅375pt以下で左右に切れる（#11）。
3. 直し案はすべて表示のみ（数値・乱数・golden に触れない）。

節構成：§1 指摘（#1〜#15）／§2 既出／§3 問題なしの所

## §1 指摘

文字の拡大は `YoseFont` が `mzScaled`（上限1.35倍）を通すので、以下の「大きい文字」は最大1.35倍で見積もった。

### YoseRankUpOverlay.swift

**#1【中】VoiceOver で読めない（自動で閉じる・タップ専用・見出し無し）**
- 場所：YoseRankUpOverlay.swift:70-116（body）・:124・:203・:280-330
- 起きること：約1.45秒（視差を減らす時 1.1秒）で自動で閉じる。閉じる操作は全画面の `onTapGesture`（:113）のみで `accessibilityAction` が無い。モーダルの印（`.isModal`）が無く、背面の画面も読める。見えていない「？」（:203, opacity 0 でも読まれる）と「旧」「新ランク」が断片で読まれ、「番付昇格」（:124）は見出しにならない。読み上げ中に画面が消える。
- 直し案：
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel("番付昇格。\(main.abilityName)が\(main.fromRank)から\(main.toRank)に上がった。実力\(totalPower)")
.accessibilityAddTraits(.isModal)
.accessibilityAction(named: "閉じる") { dismissImmediately() }
// 「？」は .accessibilityHidden(true)。VoiceOver 稼働中（UIAccessibility.isVoiceOverRunning）は自動クローズを長くするか止める
```
- 表示のみ：はい（自動クローズの長さは演出時間であってゲーム数値ではない）。

**#2【中】能力値の行・同時昇格チップが大きい文字で（一部は通常でも）はみ出す**
- 場所：:227-248（能力値と実力）・:254-273（同時昇格）
- 起きること：①カード内幅は約282pt。能力値と実力の行は各半分（約137pt）で、`Text(abilityName)`・旧値・矢印・新値（26pt→35pt）に `lineLimit` も縮小も無い。「メンタル」のような4文字の名前＋3桁の値で大きい文字なら折れる（名前が1文字ずつ縦に割れる）。②同時昇格は最大4個（能力5つのうち主役以外）のチップを `HStack` に並べる。1個約80pt×4＋隙間＝約350pt＞282pt で、通常の文字でも右へはみ出す・つぶれる。数字の2行割れは `monospacedDigit`＋空白無しの数字なので起きにくいが、名前側が折れて行の高さが揃わなくなる。
- 直し案：
```swift
Text(item.abilityName).lineLimit(1).minimumScaleFactor(0.7)
Text("\(item.beforeValue)").lineLimit(1).minimumScaleFactor(0.6)
// 同時昇格は ViewThatFits { HStack{…} ; VStack(alignment:.leading){…} }（またはチップ内 Text に lineLimit(1)+fixedSize）
```
- 表示のみ：はい。

**#3【低】視差を減らす設定でも後光の光条が回り続ける**
- 場所：:364-386（RankUpHalo の `TimelineView(.animation)`、:375 の `t * 0.05`）
- 起きること：`reduceMotion` を見ない。強い（Sランク）後光で光条がゆっくり回転し続け、30fpsで描画し続ける。他の演出（バースト・紙吹雪・判子）は `reduceMotion` に対応済みで、ここだけ漏れ。
- 直し案：`@Environment(\.accessibilityReduceMotion) var reduceMotion` を追加し、`let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate`。`TimelineView(.animation(minimumInterval: 1/30, paused: reduceMotion))`。
- 表示のみ：はい。

**#4【低】本番で呼ばれていない部品＋無効なコード**
- 場所：YoseRankUpOverlay 全体（呼び出しは `Design/YoseFXPreview.swift:18`＝DEBUG専用のみ）／:161（`.padding(bright ? 0 : 0)` は常に0）／:173-174（空行の修飾子跡）／:16-32（メンバーワイズと同じ中身の `init`）／:54-64（同上）
- 起きること：本番の画面からは出ない（能力ランクアップは別の画面が担当している可能性。要確認＝呼び手が無いまま残っている）。コードの整理だけの話で実害は無い。
- 直し案：本番で使わない方針なら `#if DEBUG` で囲むかファイルごと整理候補にする。無効な行は削除。
- 表示のみ：はい。

**#5【低】実力の「溜め表示」が負になりうる**
- 場所：:241-242（`totalPower - powerDelta`）
- 起きること：`powerDelta > totalPower`（呼び手の誤り）なら昇格前の実力が負で出る。落ちはしない。
- 直し案：`max(0, totalPower - powerDelta)`。
- 表示のみ：はい。

### CalendarView.swift

**#7【中】表が固定高で ScrollView が無い＝小さい画面・大きい文字で凡例が切れる**
- 場所：:24-33（VStack）・:57-87（grid：24＋43×12＝約540pt）・:146-170（legend）
- 起きること：ヘッダー約52＋余白12＋年サマリ約50＋表約543＋凡例約110＝約770pt。画面の使える高さは iPhone SE 系で約600pt・15系で約750pt。大きい文字では凡例が2行折り返し・サマリが2行になり、さらに増える。ScrollView が無いので下が画面外に出て、凡例の注記（「頂GP＝…」「塗りません」）が見えない。
- 直し案：
```swift
ScrollView { VStack(spacing: 10) { summary; grid; legend } .padding(.horizontal, …).padding(.top, 12) }
// Spacer(minLength: 0) は不要になる
```
 （ScrollView の中は `grid` の行高 43 を固定のままにしてよい）
- 表示のみ：はい。

**#8【低】使われていない状態・プロパティ**
- 場所：:14（`@State breathe`）・:41（`.onAppear { breathe = true }`）・:19（`private var weeks`）
- 起きること：`breathe` は書くだけで読まれない。冒頭コメントの「照明の呼吸」は未実装（実装するなら `reduceMotion` 対応が必要）。`weeks` は未使用（表は 12×4=48 固定。既出 2026-10-19e §3 とは別の「未使用」の話）。
- 直し案：削除。「照明の呼吸」を入れるなら `reduceMotion` で止める。
- 表示のみ：はい。

**#9【低】年サマリ・大会名が大きい文字で折れる／切れる**
- 場所：:47-48（サマリ2行目、`lineLimit` 無し）・:97-98（大会名、`minimumScaleFactor(0.7)` まで）
- 起きること：サマリは「n年目　第n週 ・ 今年の賞金 ¥…」で約25文字、1.35倍だと約400pt＞358pt で2行になる（高さが変わるだけ・数字は途中で割れにくい）。セル幅は約79pt、大会名（上限6文字程度）は1.35倍で約96pt→0.7倍でも収まらず「…」になりうる。
- 直し案：サマリは `ViewThatFits`（1行／「第n週」と「賞金」の2行）。セルの大会名は `.minimumScaleFactor(0.5)`。
- 表示のみ：はい。

**#10【低】大会週で名前が空になる場合に空行が残る**
- 場所：:179-185（`tournamentName` が `""` を返す経路）→ :97（空の `Text`）
- 起きること：`cal.tournament(inWeek:)` が nil で `gpRounds` にも当たらない大会週（実際には `isTournamentWeek` が true を返さないので通常は到達しない）。到達すると名前行が空で、VoiceOver が空の要素を1つ拾う。
- 直し案：`if !name.isEmpty { Text(name)… }`。
- 表示のみ：はい。

### FinalistAnnounceView.swift

**#11【中】並びが幅375pt以下の端末で左右に切れる**
- 場所：:150-161（lineUp）・:166-195（silhouette、`.frame(width: 38)`）
- 起きること：1段に最大8人（15人なら7と8、16人なら8と8）。幅は 38×8＋隙間8×7＝360pt。左右の余白16×2を引いた使える幅は iPhone 17／15 で約361〜370pt（ぎりぎり）、SE／mini（375pt）で343pt、SE 初代（320pt）で288pt。固定幅で縮められないので 17pt〜72pt はみ出し、両端の組が画面外に出る。自組が端に来ない配置（:50）は有るが、他組が見えなくなる。
- 直し案：
```swift
GeometryReader { g in let w = min(38, (g.size.width - 8 * 7) / 8) ... .frame(width: w) }
// または 段数を3にする（rows を3分割）／ScaleEffect で全体を縮める
```
 （`.scaleEffect` なら呼び出し側の高さも一緒に調整する）
- 表示のみ：はい。

**#12【低】司会の吹き出しが大きい文字で折れて高さが跳ねる**
- 場所：:135-143（caption の Text：`mincho(big ? 26 : 16)`、`lineLimit` 無し）
- 起きること：1.35倍で26→35pt。吹き出しの有効幅は約262pt で、「——あなたのコンビ。」（9文字＝約315pt）は2行に折れ、高さが変わるので組ごとに並び全体が上下に動く。`minimumScaleFactor(0.6)` は `lineLimit` 無しでは効かない。
- 直し案：`.lineLimit(2).minimumScaleFactor(0.6)`＋`.frame(minHeight: 64, maxHeight: 96)` か、2行ぶんの高さを常に確保。
- 表示のみ：はい。

**#13【低】速いダブルタップで2段階飛ぶ（二重進行）**
- 場所：:237（tapAdvance）・:203-210（pause）
- 起きること：`pause` は抜けるとき `skipStep = false` に戻すが、2回目のタップがその後に来ると `skipStep` が true のまま次の `pause` に入り、そこも一瞬で終わる。名前の読み上げが1組飛ぶ。ゲームの結果は変わらない（呼ばれる組は同じ）。
- 直し案：`tapAdvance` で直前のタップから0.3秒以内は無視、または `pause` 冒頭で `skipStep = false` にしてから待つ。
- 表示のみ：はい。

**#14【低】使われていない状態＋毎回の再計算**
- 場所：:17（`@State lastCallFlash` は書かれも読まれもしない）／:42-60・:60（`slots`／`readOrder` を計算プロパティにして、`silhouette` ごとに `isCalled` が `readOrder`→`slots`（シャッフル・`applyingTransform`）を再実行）
- 起きること：16人×再描画ごとに再計算（約256回の軽い処理）。実害は小さいがバッテリーの無駄。
- 直し案：`lastCallFlash` を削除。`slots`／`readOrder` は `body` 冒頭で一度だけ作って渡す（`let order = readOrder`）か `@State` にキャッシュ。
- 表示のみ：はい。

**#15【低】「つづける」の高さが約40pt（最小44ptに満たない）／VoiceOver の初回案内が無い**
- 場所：:90-93（`padding(.vertical, 11)`＋16pt の文字）・:111-112（`onChange` は初期値では呼ばれない）
- 起きること：最初の画面（`.wait`）の「準決勝の終演から、しばらく。」は VoiceOver にアナウンスされず、フォーカスが当たるまで無音（4秒後に次の段へ進む）。「つづける」は押しにくい。
- 直し案：`.frame(minHeight: 44).contentShape(Rectangle())`。`onAppear` で `UIAccessibility.post(notification: .announcement, argument: caption)`。
- 表示のみ：はい。

（#6 は欠番：点検中に既出と判明したため §2 へ移した。）

## §2 既出（同じ指摘は再掲しない）
- YoseRankUpOverlay：`try? Task.sleep` が取り消しを握りつぶす（fx4_1116 中-1・:288 ほか修正済み）／`items` 空で onDismiss が走らない（fx4_1116 #2）／二重 onDismiss は `isDismissed` で防止（fx4_1116 §3）／タップ専用画面（a11y-tap-next 候補・2026-10-27b・cands4_1109）。#1 はそれらとは別の「読み上げ・モーダル・見出し」の指摘。
- CalendarView：VoiceOver で週の内容が長押しのトーストでしか分からない・現在週の印が読まれない（misc3_1116 低-3）／`YoseToast` が読み上げられない（2026-10-19l）／トーストの消去タイマー（2026-10-19e §3 修正済み）／過ぎた大会週の塗り（1107c #8・1108 #1/#2・2026-10-19g）／週数48固定（2026-10-19e §3）。
- FinalistAnnounceView：画面が一度消えて戻ると `start()` が再開しない（1107e #5）／漢字名・英字名の読みが並びの端に固定（1108c #6）／`つづける` の二重タップ（1108c_screens #50 付近）／`skipAll` で announcement が重なる（share_settings_1117 #8 修正済み）／全画面タップだけの導線（a11y-tap-next）。

## §3 問題なしの所
- 落ちる穴は3ファイルとも無し。`swapAt(si, count/2 + count/4)` は count 15〜16 で 10〜12（範囲内）、`stride(from: count-1, through: 1)` は count≥2、`rows[r]` は 0/1 のみ、`Int(sec * 20)` は `max(1, …)`、`nx() % (i+1)` は非負。`Int64(year &* … &+ 17)` は溢れ演算子でトラップしない。`yomi` 辞書リテラルは重複キー無し（実行時トラップの心配無し）。
- Calendar：`session.categoryLog[w]` は辞書、`gpRoundNames[i]` は範囲チェック済み、`monthLabel` は row 0〜11 で 4月〜3月、`row*4+col+1` は 1〜48。0除算・NaN 無し（`Double(shownValue)` は有限）。
- RankUp：二重 `onDismiss` は `isDismissed` ガード。`reduceMotion` 時は演出を省いて 1.1秒で閉じる。バースト・紙吹雪・判子は `reduceMotion` 対応済み。フラッシュは `Theme.Motion.r` で nil になる。
- Finalist：図形は `accessibilityHidden(true)` で caption に一本化。`reduceMotion` は全 `withAnimation`／`.animation` が対応。`skipAll` は Task を取り消し、各段で `isCancelled` を確認。コンビ名は最大6文字（`Names.maxLength`）なので `selfLabel` の7文字制限で十分。
- 乱数：3ファイルとも GameCore の RNG を消費しない（Finalist の `nx()` は年から作るローカルの決定論シャッフル）。
