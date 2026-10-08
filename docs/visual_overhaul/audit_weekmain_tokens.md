# 監査 A3：週メイン／ネタ帳／カレンダー／設定／全体の色・書体トークン（visual overhaul v1）

- 作成：2026-10-08・監査班 A3（コード・git 不変更／読むだけ）
- 対象スクショ：`feedback_shots/overhaul_v1/` 00, 04_week_*, 14, 15, 16, 17
- 対象ソース：`ManzaiGame/Sources/` WeekMainView・StageScene・StageViews・CommandData・NotebookView・RadarChart・CalendarView・SettingsView・Theme・Juice・FontLoader・SoundManager・CharacterAvatars

## §0 先に結論（3行）

1. **ゲームフォント（M PLUS Rounded 1c）は1文字も描かれていない**。同梱 ttf の PostScript 名は `RoundedMplus1c-*`、コードは `MPLUSRounded1c-*` で引いている＝`Font.maru` は全量が system 丸ゴ（和文は角ゴのヒラギノ）に落ちている（§3-1・§6-1）。「丸ゴシックでチャンキー」は現状、和文では成立していない。
2. **明るいポップ系と暗い明朝系は「テーマの分岐」ではなく「ファイルごとの手塗り」**。Theme.swift は明るい系のトークンしか持たず、暗い系の地色6種・明朝の地の文30か所・金のグラデ等はすべて各ファイルの直書き（§3-3）。統一は「暗い系トークンの新設」から始めるしかない。
3. 週メインの骨格（カード4枚・2本バー・目標バナー・体力帯）は育成SLGの水準に届きかけているが、**「押した→育った」の一拍が画面に残らない**。原因は演出の弱さだけでなく、①舞台に立つ単独では実力が構造的に1も動かない（レシピの律速）、②センスを伸ばす通貨（胆力）の入手口が常設カードに1つも無い、の2点（§6-2・§6-3）。

## §1 採点表（育成SLGとしての水準・0〜5点）

基準：5＝市販の育成SLG（他社比較は `docs/fun_uiux_overhaul_v0.md` §3）と並べて遜色なし／3＝骨格は育成SLG・見せ方が未完／1＝画面の役割を果たしていない。

| 画面（スクショ） | 点 | 言い切り | 根拠（File.swift:行） |
|---|---|---|---|
| 週メイン・通常（00, 04_w01, 04_w02） | **3** | 骨格は育成SLG。だが画面の上56%が情報を持たない絵で、「舞台に立つ」「休む」のカードにはコストしか書いていない＝押す理由が見えない | 絵が残り高さを全部取る `WeekMainView.swift:72-73`／伸び表示は実力・相性・ネタの3種だけ `WeekMainView.swift:698-708` |
| 週メイン・獲得の一拍（04_w01_tap_burst, 05_event_narration_w05） | **1** | 育成SLGの心臓（押した直後の「+N」）が写らない。チップは人物の頭から約100pt離れた右上の壁（寄席ポスターの上）に出て1.2秒で消え、数字は「実力 ↑」の矢印だけ | 位置 `WeekMainView.swift:198-199`（下から262pt）／寿命 `WeekMainView.swift:143`／体力減チップは壁と同色 `WeekMainView.swift:557-559` |
| 週メイン・体力20（04_w04） | **3** | 3段の色ゲージは機能している。ただし「次の稽古で0になる」予告が無く、0到達の罰（翌週の稽古不可）がカード上で読めない | `WeekMainView.swift:627-638`／`WeekMainView.swift:456`（クランプ後の差分しか出さない） |
| 週メイン・体力ゲート（04_w05） | **2** | 「谷口：今日は休め」で意味は伝わる。だが3枚を不透明度0.6で潰すため文字のコントラストが1.8〜2.2：1まで落ち、読ませたい一言が一番読めない | `WeekMainView.swift:471`・`:486`・`:491` |
| ネタ帳「ちから」（14） | **1** | 能力画面の席なのに、数字も等級（G〜S）も無いレーダー1枚。上限120で正規化しているため1年目の実値（10→16前後）は外周の1割＝誰が遊んでも中心の点 | `NotebookView.swift:77-80`／`RadarChart.swift:53`・`:91-99` |
| ネタ帳「ネタ」（15） | **3** | 型・完成度・手応え・場数・尺・鉄板/おろし前が1枚に揃い、情報の骨格は良い。文字が9.5〜10.5pt、操作チップの高さ約23pt、3つのボタンが全部同じ朱の枠で主従が無い | `NotebookView.swift:225-266`・`:355-364` |
| ネタ帳「きろく」（未撮・コード読み） | **2** | 判ミニチュア＋明朝1行の箇条書き。称号は撤去済み（正しい判断）。「1年の歩み」を見せる画面になっていない | `NotebookView.swift:151-179` |
| 年間カレンダー（16） | **2** | 格子は読める。だが大会が名前の無い朱丸だけで、どれが本命か・済んだ大会の合否が分からない。現在週は1.5ptの縁だけ。画面の下40%が空 | `CalendarView.swift:83-87`・`:82`・`:27` |
| 設定（17） | **2** | 音量2本の最低限。育成SLGの定番（演出の速さ・スキップ・振動）が無い。BGM 既定値が画面70／実際60で食い違う | `SettingsView.swift:12`／`SoundManager.swift:69` |
| 全体の見た目の言葉（トークン） | **1** | フォント未適用（上記）・暗い系トークン0・文字サイズ23段・角丸の直書き43か所。「同じゲームの画面」と言える共通語彙が色の数個しか無い | §3 全体 |

## §2 画面ごとの欠点

### §2-1 週メイン（00／04_w01／04_w02／04_w04／04_w05／04_w01_tap_burst）

**A. 画面の配分（情報密度）**
- A-1 **上56%（約487pt）が情報を持たない絵**。`sceneZone` が `maxHeight: .infinity` で残り高さを全部取る（`WeekMainView.swift:72-73`）。壁は寄席ポスター1枚だけ（`StageScene.swift:27-30`）、人物は足元が台詞箱に隠れ（`WeekMainView.swift:177-186` が絵の左下に重なる）、何を押しても同じ立ち姿（行動ごとの姿勢・小道具が無い）。育成SLGで「主人公の絵が場面を語る」席が、毎週同じ静止画になっている。
- A-2 **同じ情報の二重表示**：大会名と残り週を上の目標バナー（`WeekMainView.swift:224-248`）と最下帯（`WeekMainView.swift:592-600`）の2か所に出している。片方を「能力の内訳」など別の情報に明け渡せる。
- A-3 **能力の内訳が本編から消えた**：週メインは実力1本に畳み（`WeekMainView.swift:261-279`）、ネタ帳のレーダーには数字が無い（§2-2）。G〜S の等級（`Theme.swift:115-152`）と等級バー（`Theme.rankProgress`）は `AllocationView.swift:338-362` でしか使われず、その画面は DEBUG フック以外から到達しない（`RootView.swift:39`）＝**等級の階段（育成SLGの昇格の快感）がリリース版では一度も見えない**。

**B. 押す理由（カードの顔）**
- B-1 **「舞台に立つ」と「休む」のカードにコストしか書いていない**（04_w01：舞台に立つ＝「体力 -30」だけ／休む＝体力満タン時は空白）。伸び表示は実力・相性・ネタの3種に限定（`WeekMainView.swift:698-708`）で、舞台に立つの知名度+1（`GameConfig.swift:191` の fame:1）も、休むのメンタル+2（`GameConfig.swift:203`）も出ない。さらに舞台に立つは単独では実力が構造的に動かない（§6-2）。
- B-2 **実力バーの意味が読めない**：塗り＝その年の器の満ち具合（`WeekMainView.swift:264`）、数字＝実力値（`:268`）。W1 は「10」なのにバーが空、という矛盾した顔で始まる（04_w01）。
- B-3 カードの高さが中身で変わる（`minHeight: 92`・`WeekMainView.swift:485`）。体力ゲートでコスト行が消えた W5 は絵が約12pt下に伸びる（04_w04 と 04_w05 の比較）。コメントの「常設4枚は位置を動かさない」（`:389`）に反して、行の高さが週ごとにずれる。

**C. 獲得の一拍（Beat2）**
- C-1 チップの位置が人物から遠い：`burstOverlay` は右下基準で下から262pt（`WeekMainView.swift:198-199`）＝画面上で y≈130〜225pt、人物の頭（y≈320pt）より約100pt上の壁で、寄席ポスター（`StageScene.swift:30` の h×0.40）と重なる。コメントの「頭上」より高すぎる。
- C-2 数字が無い：実力は常に「実力 ↑」（`WeekMainView.swift:541-544`）。％は出さない方針（既決）と「数字を出さない」は別物で、「+1」等の整数は出せる。
- C-3 体力が減った週のチップは `Theme.card2` 地＋`inkDim` 字（`WeekMainView.swift:557-559`）＝壁のクリーム（`StageScene.swift:22`）とのコントラスト1.06：1で**ほぼ見えない**。舞台に立つしか押していない W1〜W3 は、この見えないチップ1枚だけが出る週になる。
- C-4 寿命1.2秒（`WeekMainView.swift:143`）の中に、週送りスタンプ（`:148-154`・0.7秒）・集中線（`:189`）・火花（`:190-193`）・3種の音（`:141-142`・`:150`）が同時に鳴る。主役（何が何点伸びたか）が一つに決まっていない。

**D. 文字と面**
- D-1 **文字に二重影が落ちている**：カード・2本バー・台詞箱のハード影 `.shadow(radius: 0, y: 3)`（`WeekMainView.swift:278`・`:377`・`:490`）が `compositingGroup()` 無しで掛かっているため、面だけでなく**中の文字1字ずつにもベージュの影が落ちる**（スクショ拡大で「ネタを書く」「10」「5」の下に影の複製が見える）。チャンキーのつもりが「にじんだ文字」になっている。
- D-2 台詞本文だけ `.system(size: 13.5, weight: .medium)`（`WeekMainView.swift:371`）＝丸ゴでも明朝でもない3つ目の書体。効果ピル・コストピル・獲得チップも `.system`（`:507`・`:530`・`:569`・`:578`）で、カード名（`.maru`）と書体が混ざる。
- D-3 体力ゲート中のカード：地 `0xF3EFE7`＋全体の不透明度0.6（`WeekMainView.swift:486`・`:491`）→「谷口：今日は休め」（朱10.5pt）が約2.2：1、カード名が約1.8：1。
- D-4 バイトの「+¥8万」は `cMoney` 字×`cMoney` 14%地（`WeekMainView.swift:570-572`）で約1.8：1。お金の増える数字が一番薄い。
- D-5 残り3週以下の目標バナー「あと3週」は朱×暗いピル（`WeekMainView.swift:233-234`・`:243`）で約2.3：1。追い込みを知らせる字が沈む。
- D-6 名札の「俺」の青 `0x4A7BE8` が3か所に直書き（`WeekMainView.swift:368`・`StageScene.swift:62`・`CharacterAvatars.swift:120`）。人物色のトークンが無い。
- D-7 顔グラ（目がある：`CharacterAvatars.swift:49-53`）と舞台の人形（目が無い：`StageScene.swift:150-173`）で**同じ二人が別の絵**。

**E. 操作**
- E-1 最下帯のカレンダー/ネタ帳/設定アイコンは14〜15ptのシンボルに枠もパディングも無い（`WeekMainView.swift:601-612`）＝タップ領域が約20pt四方。
- E-2 押せるカードは押下時に `PressableStyle` のカーソル音（`Theme.swift:267`）＋実行音 `.tap`（`WeekMainView.swift:420`）の二重鳴り（`silent` 未指定・`:446`）。

### §2-2 ネタ帳「ちから」（14）

- 2-1 **数字も等級も無い**：`RadarChart.swift:3` は「数値は等幅で別途表示」と書くが、`NotebookView.swift:75-98` は数値を一つも出していない。育成SLGの能力画面として最低限の「名前・数値・等級」の3点が欠けている。
- 2-2 **正規化が上限120**（`RadarChart.swift:53`・`:91-99`）。1年目の実値10〜20は半径の8〜17%＝常に中心の小さな点。12_year_result_lose_top でも同じ（メンタルだけ休みのボーナスで飛び出す）。
- 2-3 軸ラベルは能力色の10pt文字（`RadarChart.swift:111`）で、白地に対し表現2.6・メンタル2.8・華2.9：1。
- 2-4 「成長の器」はリングだけで数値も目盛りも無く、空のとき（14）は**読み込み中の輪に見える**（`NotebookView.swift:114-119`）。一文は明朝13pt（`:121`）＝明るい系の画面に暗い系の書体が混入。
- 2-5 閉じるボタンは `inkFaint` の24pt（`NotebookView.swift:50`）で背景に対し約1.9：1・タップ領域約28pt。
- 2-6 画面の下25%が空。相性帯は高さ10pt（`:92`）の1本だけで、伸びた分の重ね（週メインのオレンジ）が無い＝週メインと同じ数値なのに見せ方の文法が違う。

### §2-3 ネタ帳「ネタ」（15）

- 3-1 文字が小さく薄い：型名10.5pt（`NotebookView.swift:230`）、バー見出し9.5pt（`:325`）、数値10pt `inkFaint`（`:332`・約2.0：1）、場数10.5pt `inkFaint`（`:239`）、尺チップ9.5pt（`:241`）。持ちネタは本作の「デッキ」なのに、カード名以外はほぼ注釈の大きさ。
- 3-2 操作チップは10.5pt＋上下5pt＝高さ約23pt（`NotebookView.swift:355-364`）。「選ぶ」「型を変える」「退避」が同じ朱の枠で主従が無く、退避（保管庫送り）が主操作と同じ顔。
- 3-3 **型ピッカーが色の点だけ**（20pt・`NotebookView.swift:338-353`）。本作自身の規則「色だけで区別させない」（`Theme.swift:79-80`）に反する。
- 3-4 選択中のネタは朱55%の1.5pt縁だけ（`NotebookView.swift:264-265`）＝どれを今夜かけるかが一目で分からない。
- 3-5 バーの溝が `Theme.card`（白）× カード地 `card2`（`NotebookView.swift:263`・`:328`）でほぼ見えない＝バーの「満ちていない部分」が消える。
- 3-6 保管庫の説明は明朝11.5pt `inkFaint`（`NotebookView.swift:215`・約2.0：1）。

### §2-4 ネタ帳「きろく」（未撮）

- 4-1 大会履歴は `session.log` の文字列をそのまま明朝12.5ptで並べ（`NotebookView.swift:168`）、合否は文字列に「通過」「敗退」が含まれるかで判定（`:161`）。表示が文字列設計に依存して壊れやすい。
- 4-2 判ミニチュアは `Theme.Rad.stamp` 角4の小判（`:163-167`）で大会結果画面の判（`TournamentResultView.swift:151-163`）と文法は揃っている＝ここは転用元として良い。

### §2-5 年間カレンダー（16）

- 5-1 **大会が名無し**：朱の丸（`CalendarView.swift:84`）だけで、名前・格（新人賞/GP）・賞金が無い。GP の予選と地方大会が同じ記号。
- 5-2 **済んだ大会の合否が出ない**：`isTournament` を先に判定するため（`CalendarView.swift:83-87`）、過去の大会週も未来と同じ丸のまま。
- 5-3 現在週は朱1.5ptの縁＋1.02倍の呼吸（`:82`・`:90-91`）だけで、48マスの中から探させる。
- 5-4 情報を見る手段が長押しだけ（`:93-95`）で、しかも過去週のみ。未来の大会を押しても何も起きない。
- 5-5 凡例に「仕事（オファー）」が無い（`:100`・`BandCategory.offer` は存在）。凡例は `Spacer` で画面最下部に飛ばされ（`:27-28`）、格子と離れている。
- 5-6 バイトの緑ドット8pt（`:86`）はマス地 `card2` に対し約1.8：1。

### §2-6 設定（17）

- 6-1 項目が音量2本だけ（進行中は「この年をやめる」が足される・`SettingsView.swift:38-52`）。育成SLGの定番の「演出の速さ」「イベントの既読スキップ」「振動」が無い。
- 6-2 SE スライダーは値が変わるたび `.tap` を鳴らす（`SettingsView.swift:29`）＝ドラッグ中に連打音。
- 6-3 BGM の既定値：画面は0.7（`SettingsView.swift:12`）、鳴っている音量は0.6（`SoundManager.swift:69`）。一度スライダーを触るまで表示と実音が食い違う。
- 6-4 「この年をやめる」は普通の行と同じ見た目（`SettingsView.swift:40-50`）。二度押しの文言が朱になるだけで、破壊的操作の色面が無い。

## §3 トークン棚卸しと2系統の分岐表

### §3-1 フォント：実際に何が描かれているか（確度：高）

| 項目 | 事実 | 箇所 |
|---|---|---|
| 同梱ファイル | `MPLUSRounded1c-{Medium,Bold,ExtraBold,Black}.ttf` の4本（計約14MB） | `ManzaiGame/Resources/Fonts/` |
| 登録 | ファイル名で URL を引き `CTFontManagerRegisterFontsForURL(.process)`。ここは成功している見込み | `FontLoader.swift:18-22` |
| ttf の中の名前（name テーブル実測） | family＝`Rounded Mplus 1c`／PostScript＝**`RoundedMplus1c-Medium`／`-Bold`／`-ExtraBold`／`-Black`**（旧 M+ 配布の命名。2021年以降の Google Fonts 版の `MPLUSRounded1c-*` ではない） | 4ファイルとも同じ |
| コードが引く名前 | `UIFont(name: "MPLUSRounded1c-Bold")`（可否判定）／`.custom("MPLUSRounded1c-ExtraBold" 等)` | `FontLoader.swift:27`・`Theme.swift:241-246` |
| 結果 | 可否判定が常に false → `Font.maru` は全量 **`.system(size:weight:design: .rounded)`** に落ちる | `Theme.swift:236-238` |
| 画面上の実体 | 英数字＝SF Pro Rounded／**和文＝ヒラギノ角ゴ（丸ゴではない）**。スクショ拡大で「ネタを書く」の終筆が角い | 04_week_w01 拡大 |
| 明朝 | `.system(size:design: .serif)` 30か所＝和文はヒラギノ明朝。ウェイト指定なしの13〜17pt＝細い W3 系 | §3-4 の一覧 |

- 含意1：「丸ゴでチャンキー」という週メインの設計意図（`Theme.swift:3`・`:232`）は**和文では一度も実現していない**。週メインが「ポップ」に見えている要因は色面と太い枠で、書体ではない。
- 含意2：**名前を直すと Dynamic Type が一斉に効き始める**。`Font.custom(_:size:)` は本文スタイル基準で拡大縮小する API なので、修正した瞬間に `.maru` の文字だけが端末の文字サイズ設定に追従し、`.system(size:)` の文字（アイコン含め68か所）は固定のまま残る。固定幅（実力バー枠196pt `WeekMainView.swift:275`、数字枠26/30pt `:309`・`:667`、見出し枠44pt `NotebookView.swift:325`）が溢れる。直す時は `.custom(name, fixedSize:)` で一旦固定するか、`relativeTo:` を意図して選び `.dynamicTypeSize(...)` で上限を切る（§5-1）。
- 含意3：`FontLoader.isAvailable` は `.maru` が呼ばれるたびに `UIFont(name:)` を引き直す（`Theme.swift:236`・`FontLoader.swift:26-28`）。結果を静的に保持すれば足りる。

### §3-2 Theme.swift／Juice.swift のトークン棚卸し

使用数は Theme.swift 自身を除く `ManzaiGame/Sources/*.swift` の grep 全量（2026-10-08・`dc68c26` 相当の作業ツリー）。

**色（`Theme.swift:20-63`）**

| 群 | トークン＝値 | 使用数 | 使う画面 | 所見 |
|---|---|---|---|---|
| 地 | `bg1` FFF4E6 | 0 | — | 死蔵 |
| 地 | `bg2` FFE6CF／`bgTop` FFF7EC | 8／7 | ネタ帳・カレンダー・設定・年次・名付け・割り振り | 各画面が `LinearGradient([bgTop,bg2])` を毎回手で組む（6か所） |
| 地 | `bgBottom` FFDDBE＋`bgGradient` | 0／2 | 週メイン・RootView | 3色版は週メインだけ。他画面の2色版と微妙に違う地 |
| 面 | `card` 白／`card2` FFF9F0 | 23／15 | 明るい系全般 | — |
| 線 | `line` F1E6D6 | 17 | 明るい系全般 | 白地に対し1.23：1＝枠として見えない場面がある |
| 影 | `cmdShadow` EADFCF | 11 | **週メイン・割り振りだけ** | ハード影の色。ハード影そのものはトークン化されていない（下記） |
| 文字 | `ink` 2C2740／`inkDim` 8E86A0／`inkFaint` B9B2C6 | 49／60／36 | 明るい系全般 | inkDim は白地3.46：1、inkFaint は2.05：1＝小さい文字には足りない（§5-2） |
| 強調 | `verm` E8402C／`vermD`／`gold` F6B301／`goldD` | 61／8／61／4 | **両系統** | 両系統を横断する唯一の色。統一の足場になる |
| 能力色 | `cSense` 3B8BFF 他6色 | 3〜9 | 週メイン・レーダー・決勝・顔グラ | — |
| 通貨色 | `curHirameki`〜`curTanryoku` 5色 | 直接0 | `CurrencyBadge` 経由のみ（割り振り＝DEBUG専用／ネタ帳は自動注ぎで非表示 `NotebookView.swift:108`） | **リリース版では死蔵** |
| v8 | `gainOrange`／`night`／`pillDark` 241C33・82%／`botbarDark` 2A2440／`staminaWarn`／`staminaCrit` | 5／2／4／1／1／3 | 週メイン中心 | **暗い系の色はこの2つ（pillDark・botbarDark）だけ**で、暗い画面は1つもこれを使っていない |

**関数トークン**：`abilityColor`／`abilityChar`／`currencyColor`／`currencyChar`／`rank`／`rankBounds`／`rankProgress`／`gradeColor`／`kataColor`（`Theme.swift:69-165`）。このうち **`rank`・`rankProgress`・`gradeColor` は割り振り画面だけが使用＝リリース版で未使用**（§2-1 A-3）。

**寸法・動き（`Theme.swift:170-230`）**

| 群 | トークン | 使用数 | 直書き | 所見 |
|---|---|---|---|---|
| 余白 `Sp` | s4/s8/s12/s16/s24/s32 | 2/10/16/38/18/6 | `padding(数値)` 約130か所 | **週メイン0（直書き39）・決勝0（20）・大会結果0（15）・イベント0（7）**。トークンを使うのは静かな画面だけ |
| 角丸 `Rad` | card16/btn12/stamp4／board12・sheet24 | 27/10/5／0・0 | `cornerRadius: 数値` 43か所（12,14,6,10,7,8,9,18,4,…の13種） | 決勝は15か所すべて直書き。board・sheet は死蔵 |
| 影 `e1/e2/e3` | ink系の柔らかい影 | 9/9/0 | `.shadow(` 直書き 約30か所 | **週メインの売りの「ハード影」（radius 0）はトークンが無い**：`WeekMainView.swift:278,365,377,490,534`・`AllocationView.swift` 9か所・`StageViews.swift:133` の計15か所が手書き |
| 動き `Motion` | 秒数5段＋appear/appearQuick/exit/emphSpring | 秒数トークン直接使用は std1・emph1 のみ／プリセット5/8/6/3 | `duration: 数値` 約40か所 | 週メイン13・イントロ7。決勝・大会結果・イベントはほぼ直書き |
| 触覚 `Haptics` | tick/confirm/rare | 2/7/3 | — | 文法どおり運用されている（良い） |
| 押下 `PressableStyle` | 沈み＋カーソル音 | 27 | — | **イベントの選択肢・閉じる（`ChoiceEventOverlay.swift:97`・`:112`）、大会入口の出場ボタン（`StageViews.swift:135`）、本番へ（`StageViews.swift:180`）は `.plain`＝沈まず音も無い** |
| 部品 | `AbilityBadge`／`CurrencyBadge`／`ShakeEffect` | 1／3／5 | — | 能力バッジは割り振り画面だけ＝リリース版で未使用 |

**書体**：トークンは `Font.maru(size, weight)` の1関数だけで、**文字サイズの段（type scale）が無い**。`.maru` に23種（8〜40pt）、`.system(size:)` に22種のサイズが散在し、10pt以下が44か所。

**Juice.swift**：`ParticleBurst`（週メイン・大会結果・決勝）・`SpeedLinesBurst`（週メインのみ）・`punch`（週メイン2・決勝2）・`screenFlash`／`screenShake`（大会結果・決勝）。寿命・ばね定数はすべてファイル内直書き（`Juice.swift:36`・`:121`・`:174`・`:177`・`:203`・`:238`）、集中線の既定色は ink の hex を複写（`Juice.swift:116`）。**Reduce Motion の分岐はどこにも無い**（§5-4）。

### §3-3 2系統の分岐表（どこで分かれ、誰が何を使うか）

**分岐点は「テーマ」ではなく「ファイル」**。Theme.swift に系統の切替は無く、各画面ファイルが地色から自前で塗っている。経路で見ると次のとおり分かれる。

| 経路 | 画面 | 系統 | 地の定義（File:行） |
|---|---|---|---|
| IntroFlow 内 | タイトル → 回想 | 暗 | `IntroFlow.swift:127`（黒→241C33→3A2A2A）・`:26`＋`:60`（黒＋2A2440 放射） |
| IntroFlow 内 | 名付け | **明（急転）** | `IntroFlow.swift:173`・`:227`（bgTop→bg2） |
| RootView `content` | 週メイン | 明（3色） | `WeekMainView.swift:78`・`:174`・`StageScene.swift:22` |
| 週メインの fullScreenCover | 選択肢イベント | **暗** | `WeekMainView.swift:85-96` → `ChoiceEventOverlay.swift:30`（241C33→2F2540＝pillDark と同じ hex を直書き） |
| 週メインの fullScreenCover／sheet | ネタ帳・カレンダー／設定 | 明（2色） | `NotebookView.swift:25`・`CalendarView.swift:22`・`SettingsView.swift:18` |
| RootView `phase` | 大会入口・本番前 | **第3の地：ピンク** | `StageViews.swift:121`・`:184`（FFE0D6→FFF3E4 直書き） |
| RootView `pendingResult` | 大会結果 | 暗（＋紙の講評カード） | `TournamentResultView.swift:103`（120D22→241633→1A1128）・講評 `:185-189`（FDFBF4→F6EEDC）・山場 `:215`（14121C） |
| RootView `winFinale`/`watchingFinal` | 決勝・観戦 | 暗 | `FinalsPresentationView.swift:33`（080610→140E1E→241118） |
| RootView `finished` | 年次リザルト | 明（＋明朝の地の文） | `YearResultView.swift:37`・`:164` |
| RootView `showEnding` | 勇退 | 暗（純黒） | `S6bView.swift:21` |

設計意図は「日常＝明るい／本番＝暗い」（`StageScene.swift:5`・`WeekMainView.swift:77`）だったが、**日常側の物語（回想・選択肢イベント）まで暗い側に入った**のがオーナーの「ちぐはぐ」の正体。

**要素別の対照**

| 要素 | 明るいポップ系（週メイン中心） | 暗い明朝系（イントロ・イベント・大会結果・決勝・勇退） |
|---|---|---|
| 地色 | トークン（bgGradient／bgTop→bg2）。ただし3色版・2色版・ピンクの3通り | **トークン0**。黒・2A2440・241C33→2F2540・120D22系・080610系・14121C の6通りを各ファイルに直書き |
| 面 | 白 `card`＋角16＋**太枠2.5〜3pt＋ハード影**（週メイン `:276-278`・`:486-490`）／静かな画面は白＋`e1/e2` の柔らかい影で枠なし（ネタ帳・カレンダー・設定・年次） | 白6〜10%のガラス＋金50%の1pt線（`ChoiceEventOverlay.swift:109-110`・`FinalsPresentationView.swift:331-332`・`S6bView.swift:102`） |
| 影 | ハード影（cmdShadow・radius 0）／ink 系の柔らかい影 | 金や能力色の発光（`FinalsPresentationView.swift:99`・`:172`・`:204`・`:245`）・黒の柔らかい影（`StageViews.swift:76`） |
| 見出し | `.maru` 15〜16 の詰め組み | `.maru` 11〜15＋**字間 tracking 2〜8 の割り付け**（「審 査 講 評」`TournamentResultView.swift:167`／「出 順 発 表」`FinalsPresentationView.swift:156`／「決 勝」`:100`）・金のグラデ文字（`:97`・`:170`・`:284`）・決勝ロゴのみ明朝 black（`:96`） |
| 地の文・台詞 | 台詞は `.system(13.5, .medium)`（`WeekMainView.swift:371`）＝白い吹き出し＋顔グラ＋名札 | **`.system(13〜17, design: .serif)`** を白55〜100%で（`IntroFlow.swift:35`・`ChoiceEventOverlay.swift:73`・`:75`・`TournamentResultView.swift:221`・`FinalsPresentationView.swift:391`・`S6bView.swift:105-106`）＝吹き出し無し・顔無し |
| 話者 | 52pt 顔グラ＋色カプセルの名札（`WeekMainView.swift:362-369`） | 金80%の10pt 文字だけ（`ChoiceEventOverlay.swift:72`）。決勝の審査員だけ顔グラあり |
| 人物 | 色つき人形（`StageScene.swift:60-69`）・目のある顔グラ（`CharacterAvatars.swift:30-79`） | 白10%／黒55%のカプセル（`IntroFlow.swift:63-67`・`:154-157`）。**同じ `ManzaiFigure` にシルエット指定（`headColor: nil`・`StageScene.swift:136`）があるのに使っていない** |
| 数字 | `.maru` 12〜17＋`monospacedDigit`＋`contentTransition(.numericText())`＋`punch` | `.system(24〜74, .black, design: .rounded)`（`FinalsPresentationView.swift:159`・`:199`・`:222`・`:322`）＝`.maru` を通らない別ルート |
| 主ボタン | 朱の塗り＋白字＋角12（`YearResultView.swift:216-218`）・`PressableStyle` | 金の塗り＋焦茶 `5A3A06` 字（`ChoiceEventOverlay.swift:93`・`FinalsPresentationView.swift:406`）／朱（`S6bView.swift:147`）。焦茶は直書き3か所 |
| 選択肢ボタン | （該当なし：カードが選択肢） | 白10%＋金50%枠・`.plain`（`ChoiceEventOverlay.swift:109-112`） |
| 送りの合図 | 吹き出し右下の▼8pt（`WeekMainView.swift:347-349`） | 「タップで進む」`.maru(10〜11)`・白38〜45%（`IntroFlow.swift:42`・`ChoiceEventOverlay.swift:60`・`FinalsPresentationView.swift:58-59`・`TournamentResultView.swift:225-226`・`S6bView.swift:49`・`:108`）＝同じ部品を6か所で手書き |
| 余白・角丸 | Sp・Rad を一部使用 | ほぼ直書き（決勝の角丸15か所・余白20か所） |
| ジュース | 集中線・火花・パンチ・押下沈み | 紙吹雪・フラッシュ・シェイク（ここは暗い系の方が豊か） |

**混入（系統をまたいだ書体の漏れ）**：明るい画面にも明朝が入っている＝ネタ帳7か所（`NotebookView.swift:121,142,155,168,200,215,271`）・年次リザルト3か所（`YearResultView.swift:118,121,164`）・割り振り2か所（`AllocationView.swift:291,659`）・ネタ選択1か所（`NetaSelectionView.swift:37`）・名付け1か所（`IntroFlow.swift:234`）。

### §3-4 直書きの全量

**`.system(size:…, design: .serif)`＝30か所（全量）**
- `ChoiceEventOverlay.swift:73, 75`
- `IntroFlow.swift:35, 234`
- `TournamentResultView.swift:170, 221`
- `FinalsPresentationView.swift:96, 176, 212, 274, 288, 391, 396, 400`
- `S6bView.swift:105, 106, 142`
- `YearResultView.swift:118, 121, 164`
- `NotebookView.swift:121, 142, 155, 168, 200, 215, 271`
- `AllocationView.swift:291, 659`
- `NetaSelectionView.swift:37`

**`.system(size:)` で文字（アイコン以外）を組んでいる箇所**（`.maru` を通らない）
- 週メイン：`WeekMainView.swift:371`（台詞）・`:507`（効果ピル）・`:530`（獲得チップ）・`:569`（所持金ピル）・`:578`（体力ピル）
- 舞台：`StageScene.swift:77-78`（寄席ポスター）
- 大会入口：`StageViews.swift:129`
- 決勝：`FinalsPresentationView.swift:159, 199, 222, 322`（rounded 大数字）・`:346`・`:371`・`:383`（「優勝」判）
- その他：`NetaSelectionView.swift:66, 73`・`TournamentResultView.swift:197`（星）・`AllocationView.swift:320, 411, 449`・`RootView.swift:211`（DEBUG）
- （アイコン用の `.system(size:)` は `WeekMainView.swift:229,289,348,461,602,606,610,749`・`CalendarView.swift:48`・`NotebookView.swift:50,295`・`SettingsView.swift:73,97`・`IntroFlow.swift:114`・`AllocationView.swift:99`・`NetaSelectionView.swift:94` で、ここは SF Symbols の寸法なので許容）

**`Color(hex:)` の Theme.swift 外の直書き＝116個（85行）**
- `FinalsPresentationView.swift`：33, 70, 74, 97, 117, 160, 166, 170, 201, 223, 239, 240, 284, 323, 342, 343, 347, 357, 373, 383, 385, 391, 406（金のグラデ3段 FFE9A8/FFF3C8/FFE07A・暗い面 1A1424/231B33/2A2040/171126・焦茶 5A3A06 が繰り返し登場）
- `StageScene.swift`：22, 40, 41, 47, 48, 60, 62, 63, 65, 67, 68, 90, 99, 107, 135, 137, 193, 198, 202, 232（稽古場の壁・床・人物・マイク）
- `CharacterAvatars.swift`：19, 21, 24, 50, 51, 59, 61, 64, 120, 122, 127-133（肌・髪・目＝ink の複写）
- `TournamentResultView.swift`：103, 106, 120, 152, 167, 171, 175, 185, 188, 189, 215（暗い地・講評の紙色 FDFBF4/F6EEDC/E6D9BE・金茶 A98B52）
- `IntroFlow.swift`：60, 101, 127
- `ChoiceEventOverlay.swift`：30, 93
- `StageViews.swift`：27, 74, 121, 184
- `WeekMainView.swift`：174, 368, 403, 486
- `Juice.swift`：116
- 重複の典型：**金のハイライト FFE9A8 系が決勝に7か所**、**ink の 2C2740 が CharacterAvatars に5か所＋Juice に1か所**、**俺の青 4A7BE8 が3ファイル**、**暗い紫 241C33 が Theme（pillDark）とイベントの地で二重定義**。

**`.white/.black.opacity(…)` の直書き＝93か所**（決勝35・イントロ14・勇退13・週メイン11・大会入口6・大会結果5・イベント4・他）。暗い系の「文字の濃さ」はこの不透明度の直書き（.38〜.92 の十数段）で決まっており、段が無い。

## §4 共通化候補（転用／新設）

方針：週メインで既に効いている語彙（朱・金・白い太枠・ハード影・顔グラ＋名札・2本バー・押下の沈み）を「本作の言葉」と定め、暗い系の画面へ持ち込む。暗い系から明るい系へ持ち込む価値があるのはジュース（紙吹雪・フラッシュ・シェイク）と判（押印）だけ。

### §4-1 既存トークン／既存部品の転用で書けるもの

| 言葉 | 転用元（File:行） | 持ち込み先 | 書き方 |
|---|---|---|---|
| **話者＝顔グラ＋名札＋白い吹き出し** | `WeekMainView.swift:358-381`（adviceBox）＋`CharacterAvatars.swift:30-79`・`:139-145`（FaceCatalog.speaker） | 選択肢イベントの会話行（`ChoiceEventOverlay.swift:69-77`）・回想（`IntroFlow.swift:34-40`）・大会結果の山場（`TournamentResultView.swift:209-227`） | adviceBox を共有 View に切り出し、名前がある行はこの器で出す。地の文だけの行は吹き出し無しの同じ書体で出す |
| **判（押印）** | `TournamentResultView.swift:151-163`・`YearResultView.swift:64-66`・`NotebookView.swift:163-167`（3か所とも `Theme.Rad.stamp`） | イベントの結末（選んだ結果）・カレンダーの済んだ大会（§2-5 5-2） | 3か所の判を1部品にまとめ、サイズ違いで使う。既に文法が揃っている唯一の部品 |
| **押下の沈み＋音** | `Theme.swift:253-270`（PressableStyle） | `ChoiceEventOverlay.swift:97`・`:112`／`StageViews.swift:135`・`:180` | `.plain` を `PressableStyle()` に替えるだけ |
| **等級バッジ G〜S と等級バー** | `Theme.swift:115-152`（rank／rankProgress／gradeColor）＋`AllocationView.swift:338-362`（バッジと帯内バーの実装） | ネタ帳「ちから」（数値・等級の欠落 §2-2）・年次リザルト・週メインの実力内訳 | 割り振り画面の等級表示をそのまま行部品にしてネタ帳に置く。数式不変・表示写像のみ |
| **能力バッジ（色＋1文字）** | `Theme.swift:285-295`（AbilityBadge） | レーダーの軸ラベル（`RadarChart.swift:111`）・獲得チップ（どの能力が伸びたか） | 色だけの軸ラベルをバッジ＋名前に替える（色弱規則 `Theme.swift:79-80` の徹底） |
| **伸びを重ねるバー** | `WeekMainView.swift:283-316`（statBar：塗り＋今週の伸びのオレンジ重ね＋満了で金縁） | ネタ帳の相性帯（`NotebookView.swift:83-93`）・ネタの完成度/手応え（`:323-335`）・年次リザルト | statBar を共有部品にし、ネタ帳でも「先週からの伸び」をオレンジで重ねる |
| **数字の手触り** | `WeekMainView.swift:308-312`（`.maru`＋`monospacedDigit`＋`contentTransition(.numericText())`＋`punch`） | 決勝の大数字（`FinalsPresentationView.swift:159`・`:199`・`:222`・`:322` は `.system(.rounded)` の別ルート） | フォント修正（§4-2 ①）の後、数字は全部この組み合わせに寄せる |
| **人物のシルエット** | `StageScene.swift:130-183`（ManzaiFigure。`headColor: nil` でシルエット・`:136`） | 回想（`IntroFlow.swift:63-67`）・タイトル（`IntroFlow.swift:154-157`） | 半透明カプセルを ManzaiFigure に置換＝週メインと同じ二人の形が最初の画面から出る |
| **トースト** | `WeekMainView.swift:673-682`（pillDark カプセル） | カレンダー（`CalendarView.swift:32-38`）・割り振り（`AllocationView.swift:689`） | 3か所の手書きを1部品に |
| **ジュース** | `Juice.swift` 全部品 | 選択肢イベントの結末（現状ジュース0）・イントロの「コンビ、組まへんか」の一拍 | ParticleBurst／punch／screenFlash を既存のまま呼ぶ |
| **余白・角丸・柔らかい影** | `Theme.Sp`・`Theme.Rad`・`e1/e2` | 決勝（角丸15・余白20の直書き）・大会結果・イベント | 値の置換。見た目はほぼ変わらず、以後の一括調整が効くようになる |
| **横断色** | `verm`・`gold`・`ink`（両系統で使用：§3-2） | 暗い系の強調色 | 暗い系の金グラデや焦茶の直書きを、まずこの3色からの派生に揃える |

### §4-2 新設が要るもの

| # | 言葉 | なぜ新設か | 中身（案・値は【仮】） | 効く箇所 |
|---|---|---|---|---|
| ① | **フォント名の修正＋文字サイズの段** | 名前不一致でゲームフォントが未適用（§3-1）。段が無くサイズが23種 | `RoundedMplus1c-*` に修正／段＝ display 30・title 20・headline 16・body 15・caption 12・micro 10 の6段【仮】。10pt未満は廃止 | 全画面（`.maru` 183か所） |
| ② | **読み物の書体の決定** | 暗い系の「細い明朝の小さい字」がオーナー不満の中心。明朝はヒラギノ明朝 W3 に落ちている | 地の文も丸ゴ Medium の15〜16pt【仮】に寄せる／明朝を残すなら「本番の講評」だけに限定し W6・16pt以上【仮】 | §3-4 の明朝30か所 |
| ③ | **ハード影の modifier** | 15か所の手書き＋文字に影が落ちる不具合（§2-1 D-1） | `.hardShadow(y: 3)`＝`compositingGroup()`＋`shadow(color: cmdShadow, radius: 0, y:)` を1つに | `WeekMainView.swift:278,365,377,490,534`・`AllocationView.swift` 9か所・`StageViews.swift:133` |
| ④ | **チャンキー面（白＋太枠＋ハード影）** | 週メインの顔なのに部品になっておらず、ネタ帳・カレンダー・設定は柔らかい影の別の面になっている | `ChunkyPanel(tint:)`＝`card` 地＋2.5〜3pt 枠＋角16＋③ | ネタ帳・カレンダー・設定・年次・イベントの吹き出し |
| ⑤ | **暗い場面用の地と文字の段** | 暗い系はトークン0で地6種・文字の濃さ十数段が直書き（§3-3・§3-4） | 「本番の夜」の地を1〜2種に集約（例：舞台の幕の暖色寄り）＋文字は hi/mid/lo の3段【仮】＋ガラス面1種。**ただし既決ではないので、暗い系を残すか自体が要オーナー判断** | 大会結果・決勝・勇退 |
| ⑥ | **金箔グラデ** | FFE9A8／FFF3C8／C8971A 系が決勝に7か所ばらばら | `Theme.goldFoil`（3段固定） | `FinalsPresentationView.swift:97,170,201,284,323,373`・`TournamentResultView` |
| ⑦ | **送りの合図** | 「タップで進む」を6か所で手書き・白38〜45%の10〜11pt（§5-2） | `AdvanceHint`＝▼＋短い文言・コントラスト4.5：1以上・Reduce Motion で点滅停止 | `IntroFlow.swift:42`・`ChoiceEventOverlay.swift:60`・`FinalsPresentationView.swift:58`・`TournamentResultView.swift:225`・`S6bView.swift:49,108` |
| ⑧ | **人物色** | 俺の青・谷口の朱が3ファイルに直書き（§2-1 D-6） | `Theme.cOre`（4A7BE8）・`Theme.cTaniguchi`（F0533E） | `WeekMainView.swift:368`・`StageScene.swift:60-68`・`CharacterAvatars.swift:120,122` |
| ⑨ | **主ボタンの型** | 朱塗り・金塗り（焦茶字）・ガラスの3通りを画面ごとに手書き | `PrimaryButtonStyle(.verm / .gold)`＋`Theme.onGold`（5A3A06） | `YearResultView.swift:216-218`・`ChoiceEventOverlay.swift:93`・`FinalsPresentationView.swift:406`・`S6bView.swift:145-147`・`StageViews.swift:176-178` |
| ⑩ | **獲得チップ（数字つき）** | 週メインのチップは矢印だけ・壁と同色の回あり（§2-1 C）／イベントの結末には効果表示が0 | `GainChip(ability|stat, +N)`＝色地＋白字＋白縁＋③。減りは朱系の別色【仮】 | 週メインの Beat2・選択肢イベントの結末・大会結果 |
| ⑪ | **動きの抑制スイッチ** | Reduce Motion 分岐が0（§5-4） | `@Environment(\.accessibilityReduceMotion)` を Juice とループ演出の入口で見る共通 helper | `Juice.swift` 全部・`StageScene.swift:178,217`・`CalendarView.swift:91`・`StageViews.swift:17` |
| ⑫ | **日常の地を1本に** | 3色版（週メイン）・2色版（5画面）・ピンク（大会入口）の3通り | `Theme.bgDaily` に統一し、大会入口は地ではなく帯やバッジで「本番前」を示す | `WeekMainView.swift:78`・§3-3 の明るい系の地・`StageViews.swift:121,184` |

## §5 アクセシビリティ現状

### §5-1 Dynamic Type：**非対応（全文字が固定pt）**

- `dynamicTypeSize`・`@ScaledMetric`・テキストスタイル（`.body` 等）・`relativeTo:` の使用は0件（全 Sources を grep）。
- `.system(size:)` は68か所すべて固定。`.maru` は本来 `Font.custom(_:size:)`＝本文スタイル基準で拡大縮小する API だが、§3-1 のとおり現状は `.system(size:)` に落ちているので、**結果として全文字が端末の文字サイズ設定を無視している**。
- フォント名を直した瞬間に `.maru` だけが追従し始め、次の固定枠が溢れる：実力/相性の枠幅196pt（`WeekMainView.swift:275`）・数字枠26pt/30pt（`:309`・`:667`）・体力ゲージ64pt（`:647`・`:652`）・台詞箱の最大幅250pt（`:374`）・ネタのバー見出し44pt（`NotebookView.swift:325`）・設定の見出し44pt（`SettingsView.swift:89`）・カレンダーの月ラベル34pt／マス高30pt（`CalendarView.swift:64`・`:89`）。
- 最小の文字：`.maru` 10pt以下が44か所。この担当範囲では目標バナー2行目9pt（`WeekMainView.swift:239`）・最下帯の「1年目」と大会名9pt（`:589`・`:595`）・名札9.5pt（`:366`）・ネタのバッジ9pt（`NotebookView.swift:310`・`:315`）・バー見出し9.5pt（`:325`）・尺チップ9.5pt（`:241`）・カレンダー凡例9.5pt（`CalendarView.swift:105`）・設定のクレジット9.5pt（`SettingsView.swift:55`・`:57`）。

### §5-2 コントラスト（WCAG 2.x の式で概算・背景は実際の重なりで合成）

基準：通常の文字4.5：1／大きい文字（18pt以上、または14pt以上の太字）3：1／枠・アイコン等3：1。本作の文字はほぼ太字だが、12pt以下が大半なので4.5：1が要る。

| 組み合わせ | 比 | 判定 | 主な箇所 |
|---|---|---|---|
| `ink` × 白 | 14.3 | ○ | 本文・カード名 |
| `inkDim` × 白／× `card2` | 3.46／3.31 | ✕（小さい字） | 60か所。見出し・凡例・「体力 -20」 |
| `inkFaint` × 白／× `card2` | 2.05／1.96 | ✕ | 36か所。ネタの数値（`NotebookView.swift:332`）・場数（`:239`）・保管庫説明（`:215`） |
| 閉じるボタン `inkFaint` × `bgTop` | 1.93 | ✕（アイコン3：1未満） | `NotebookView.swift:50`・`CalendarView.swift:48`・`SettingsView.swift:73` |
| 「+¥8万」`cMoney` × `cMoney` 14% | 1.77 | ✕ | `WeekMainView.swift:570-572` |
| 「体力 +30」`cMental` × 14% | 2.42 | ✕ | `WeekMainView.swift:579-581` |
| 「実力 ↑」`cSense` × 10% | 2.97 | ✕ | `WeekMainView.swift:507-510` |
| 体力ゲート中「谷口：今日は休め」／カード名（不透明度0.6） | 2.20／1.84 | ✕ | `WeekMainView.swift:471`・`:486`・`:491` |
| 残り3週以下の「あと3週」朱 × 暗いピル | 2.30 | ✕ | `WeekMainView.swift:233-234` |
| 最下帯「大会まで3週」朱 × `botbarDark` | 3.65 | ✕（12pt） | `WeekMainView.swift:596-597` |
| 最下帯 金 × `botbarDark`／白65% × `botbarDark` | 7.98／7.04 | ○ | `:596`・`:589` |
| 獲得チップ 白 × `cSense`（16pt black） | 3.32 | △（大きい太字なら可） | `WeekMainView.swift:530-535` |
| 獲得チップ 白 × `cMental` | 2.78 | ✕ | 同上（体力が増えた週） |
| 体力減チップ `card2` × 壁 FFF2DC | 1.06 | ✕（チップの形が消える） | `WeekMainView.swift:559` |
| レーダー軸ラベル 表現／メンタル／華／センス × 白（10pt） | 2.60／2.78／2.91／3.32 | ✕ | `RadarChart.swift:111` |
| 「鉄板」`goldD` × 金18% | 2.12 | ✕ | `NotebookView.swift:315-317` |
| カレンダーのバイトドット × `card2` | 1.84 | ✕（3：1未満） | `CalendarView.swift:86` |
| `line` 枠 × 白 | 1.23 | ✕（枠として機能しない） | カレンダーのマス・ネタ帳の区切り |
| 主ボタン 白 × 朱（16pt） | 4.04 | ○（大きい太字） | `YearResultView.swift:216-218` |
| 金ボタン 焦茶 × 金 | 5.57 | ○ | `ChoiceEventOverlay.swift:93` |
| （参考・暗い系）「タップで進む」白45% × 黒／白40% × 241C33 | 4.43／3.75 | ✕（10〜11pt） | `IntroFlow.swift:42`・`ChoiceEventOverlay.swift:60` |
| （参考・暗い系）地の文 白75% × 2F2540 | 8.70 | ○ | `ChoiceEventOverlay.swift:75`＝**暗い系の読みにくさはコントラストではなく、細い明朝（W3）×13〜14pt×上詰めの組みが原因** |

### §5-3 タップ領域（目安44pt四方）

| 部品 | 実寸（概算） | 箇所 |
|---|---|---|
| 最下帯のカレンダー/ネタ帳/設定 | 約20pt（14〜15ptの記号に枠なし） | `WeekMainView.swift:601-612` |
| 閉じる（✕） | 約24〜28pt | `NotebookView.swift:49-51`・`CalendarView.swift:47-49`・`SettingsView.swift:73-75` |
| ネタの操作チップ（選ぶ/型を変える/退避/呼び戻す） | 高さ約23pt | `NotebookView.swift:355-364` |
| 型ピッカーの色点 | 20pt | `NotebookView.swift:345` |
| ネタ名（改名） | 高さ約17pt | `NotebookView.swift:289-297` |
| ネタ帳のタブ | 高さ約33pt | `NotebookView.swift:65-70` |
| 目標バナー（→カレンダー） | 高さ約30pt | `WeekMainView.swift:242` |
| 設定「この年をやめる」 | 文字の部分だけ（`.plain`＋`Spacer` に `contentShape` 無し） | `SettingsView.swift:40-50` |
| 行動カード4枚／バイト | 92pt以上／約48pt | ○ `WeekMainView.swift:485` |
| カレンダーのマス | 高さ30pt・長押しのみ | `CalendarView.swift:89`・`:93` |

### §5-4 Reduce Motion：**非対応（分岐0件）**

- `accessibilityReduceMotion` の参照は0件。
- 常時動き続けるもの：稽古場の塵（`TimelineView` 20fps・週メイン表示中ずっと・`StageScene.swift:217`）、人形の呼吸（`repeatForever`・`StageScene.swift:178`）、カレンダー現在週の呼吸（`CalendarView.swift:91`）、笑い波形（`TimelineView(.animation)` 上限なし・`StageViews.swift:17`）、決勝の放射光/紙吹雪（`FinalsPresentationView.swift:548`・`:573`）。電池にも効く。
- 一拍の強い動き：画面シェイク（`Juice.swift:217-247`・大会結果と決勝）、画面フラッシュ（`Juice.swift:192-213`・白45%まで）、集中線（毎週・`WeekMainView.swift:189`）、パンチ（`WeekMainView.swift:312`・`:619`）。すべて設定に関わらず再生。

### §5-5 VoiceOver・その他

- `accessibilityLabel` は全体で7か所（`IntroFlow.swift:117`・`SettingsView.swift:75`・`WeekMainView.swift:314-315`・`:604`・`:608`・`:612`）。
- レーダー（Canvas）は読み上げ情報が0（`RadarChart.swift:58-119`）。画面上にも数値が無いので、読み上げでは能力が一切分からない。
- 体力ゲージにラベルが無い（`WeekMainView.swift:640-669`）。体力ゲートで押せないカードは「ボタン」のまま読まれ、ダブルタップの結果（トースト）は読み上げ通知されない（`WeekMainView.swift:413-418`）。
- 型ピッカーの7つの点は名前の無いボタン（`NotebookView.swift:341-347`）。ネタ帳・カレンダーの閉じるにラベル無し（設定だけ有り）。
- ダークモード：`preferredColorScheme`／`UIUserInterfaceStyle` の固定が無い（`project.yml:25-35`・`ManzaiGameApp.swift`）。独自色は固定のまま、標準部品（Slider・Divider・TextField・ステータスバー）だけが暗転に追従する＝§6-9。

## §6 不具合の疑い（原因箇所つき）

確度：高＝コードと実物（ファイル実測・スクショ）の両方で裏が取れた／中＝コードで説明がつくが未再現／要再現＝現象とコードが食い違う。

| # | 疑い | 確度 | 原因箇所 | 直し方の方向（コード不変更の前提で記述） |
|---|---|---|---|---|
| 6-1 | **ゲームフォント未適用**：全 `.maru` が system 丸ゴ（和文は角ゴ）に落ちている。14MB のフォントが死蔵 | 高 | ttf の PostScript 名＝`RoundedMplus1c-*`／コード＝`MPLUSRounded1c-*`（`FontLoader.swift:27`・`Theme.swift:241-246`）。可否判定が毎回 `UIFont(name:)` を引く（`Theme.swift:236`） | 名前を `RoundedMplus1c-*` に直す（ファイル名はそのままで可）。確認は simulator で `UIFont.fontNames(forFamilyName: "Rounded Mplus 1c")`。**同時に Dynamic Type が効き始める**ので §5-1 の固定枠を先に見直すか `fixedSize:` で入れる |
| 6-2 | **「舞台に立つ」を何回押しても実力が1も動かない**（README の所見） | 高 | 舞台に立つ＝存在感3＋間合い1を発行（`GameConfig.swift:191`）。能力のレシピは全通貨を同比率で要求する律速（`Allocation.swift:86-91` の `min()`）で、存在感・間合いだけで満たせる能力が無い（華は閃き、表現は語彙、センスは閃き＋胆力、メンタルは胆力も要る：`GameConfig.swift:126-132`）＝閃き・語彙が来るまで注げず、貯まった分は**見えないまま後の週に持ち越される**（通貨チップは A「削る」で非表示：`WeekMainView.swift:537-538`） | 見せ方で解く：カードに「経験がたまる」系の予告、Beat2 に「たまった」チップ、ネタ帳に「次に何が来れば伸びるか」【要 drama-voice：文言は未確定】。発行量やレシピを変えるのは **規律A・要オーナー判断** |
| 6-3 | **センス（実力の重み最大0.30）が1年中伸びない**／メンタルは休みのボーナスでしか伸びない | 高 | センスとメンタルのレシピに要る胆力（`GameConfig.swift:127`・`:131`）の発行元はネタ見せ会・ランニング（`GameConfig.swift:188`・`:190`）だけで、どちらも常設カードに無い（`CommandData.swift:26-30`）。イベント効果にも胆力の付与は無い | カードの写像は UI 層（`CommandData.swift`）だが、どの稽古を出すかはバランスに直結＝**要オーナー判断**。少なくともネタ帳で「センスは今の手札では伸びない」ことが読めるようにする |
| 6-4 | **文字に二重影**（ハード影が面でなく文字にも落ちる） | 高 | `compositingGroup()` 無しの `.shadow(radius: 0)`：`WeekMainView.swift:278`・`:377`・`:490`・`:534`（割り振り画面も同型 9か所） | §4-2 ③の modifier に寄せる。拡大スクショで「ネタを書く」「10」「5」の下にベージュの複製が出ている |
| 6-5 | **獲得チップが見えない／人物から遠い**（04_w01_tap_burst に何も写っていない） | 中 | 位置＝下から262pt（`WeekMainView.swift:198-199`）＝頭の約100pt上の壁。体力減チップは壁と同色（`:557-559`・1.06：1）。寿命1.2秒（`:143`）。舞台に立つの週は体力チップ1枚しか出ない（§6-2）＝実質「何も出ない週」 | 位置を頭の直上へ下げる・減りは別色・数字を入れる（§4-2 ⑩）。撮影は Beat1（0.82秒）の後を狙う必要がある（`:432-434`） |
| 6-6 | **イベントが被さり獲得バーストが見えない**（05_event_narration_w05） | 要再現 | コード上は Beat2 の退場＋0.25秒まで cover を保留している（`WeekMainView.swift:85-90`・`:121-147`・世代トークン `:126-127`）。保留が外れる経路は「チップ0枚」（`:133-136`）と「lastDeltaWeek 不一致」（`:128-131`）だけで、W4 のネタを書く（実力↑・新ネタ・体力-20 の3枚）はどちらにも当たらない | 体感の主因は 6-5（チップが右上の壁に1.2秒＝視線は左下の台詞にある）と見る。再現手順：W4 相当で体力20→ネタを書く→画面録画で Beat2 の有無を確認。保留が実際に外れているなら、`.task(id:)` の取り消し経路を疑う |
| 6-7 | **ネタ帳「ちから」が能力マックス状態なのにレーダーがほぼ中心**（14） | 中（撮影フック由来） | `MZ_UI=notebook` は初期 session（能力10）で NotebookView を先に出し（`RootView.swift:34`）、その後 `.task` で能力115の session に差し替える（`RootView.swift:60-61`・`GameSession.swift:902-907`）。相性は19に更新されているのに形が10のまま＝RadarChart の描画が差し替えに追従していない。実プレイは毎回新しく開く（`WeekMainView.swift:79-81`）ので影響は小さい | 本質は別：**上限120で正規化する設計そのものが、実プレイで常に中心の点を作る**（`RadarChart.swift:53`・`:91-99`）。表示だけの写像で解ける＝等級の境界（`Theme.swift:129` の rankBounds）を同心の輪にして「等級＋帯内の進み」（`Theme.rankProgress`・監査C-01 と同じ発想）で置けば、10→16 が G→F の輪越えとして見える |
| 6-8 | **体力0のバイトがタダに見え、実際にタダ** | 高 | 体力差分はクランプ後で計算（`WeekMainView.swift:456`）＝0の週は体力ピルが消える（04_w05）。標準バイトは体調ダウン抽選の対象外（`WeekRunner.swift:244-248`）＝体力0のまま無償で8万を稼ぎ続けられる | 表示は体力0を示す警告ピルで解ける【要 drama-voice：文言は既存トースト「体力が足りない。今日は休もう。」（`WeekMainView.swift:417`）の再利用を優先】。罰を足すのは **規律A・要オーナー判断** |
| 6-9 | ダークモード端末で、クリーム地の上のステータスバー文字が白くなる／標準部品だけ暗転する | 中（未検証） | 外観の固定が無い（`project.yml:25-35`・`ManzaiGameApp.swift:10-14`）。週メインの上端はクリーム（`WeekMainView.swift:174`） | simulator の外観をダークにして目視。固定するなら `UIUserInterfaceStyle=Light` |
| 6-10 | BGM 既定値の食い違い（画面70／実音60） | 高 | `SettingsView.swift:12` と `SoundManager.swift:69`（ヘッダ注記 `SoundManager.swift:4` も別値） | 既定値を1か所に寄せる |
| 6-11 | SE スライダーのドラッグ中に連打音 | 高 | `SettingsView.swift:29`（`onChange` ごとに再生） | 指を離した時だけ鳴らす |
| 6-12 | 行動カードの押下で音が二重に鳴る | 中 | 押下時のカーソル音（`Theme.swift:267`）＋実行音（`WeekMainView.swift:420`）。`silent` 指定なし（`:446`） | `PressableStyle(silent: true)`（用意済みの引数・`Theme.swift:256`） |
| 6-13 | 週ごとに4枚の行の高さが変わり、絵とカードの境目が上下する | 高 | `minHeight: 92` で中身に応じて伸びる（`WeekMainView.swift:485`）。04_w04→04_w05 で約12pt | 常設4枚は固定高にする |
| 6-14 | カレンダーで済んだ大会の合否が出ない | 高 | 大会週の判定が過去週の分岐より先（`CalendarView.swift:83-87`） | 過去の大会週は §4-1 の判（通過/敗退）を小さく置く |
| 6-15 | 等級（G〜S）・能力バッジ・通貨バッジがリリース版で一度も表示されない | 高 | 使用元が割り振り画面だけ（`AllocationView.swift:114,159,170,338-362`）で、その画面は DEBUG 経路のみ（`RootView.swift:39`）。ネタ帳の通貨欄は自動注ぎで常に非表示（`NotebookView.swift:108`） | §4-1 の転用でネタ帳・年次リザルトに戻す（表示写像のみ・数式不変） |
