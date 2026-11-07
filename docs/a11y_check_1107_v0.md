# 読み上げ（VoiceOver）＋文字サイズ点検 a11y_check_1107_v0（2026-11-07・読み取りのみ・コード未変更）

見方は a11y_check_1026_voiceover_v0.md に合わせた（grep→該当行だけ読んだ）。実機の VoiceOver・大きい文字では未確認＝すべて「コードを読んだ推測」。
対象：GachaView／GachaRatesView／ShareCard／Meta（周回の案内・トロフィー表示。Meta.swift 自体は画面コード無し＝表示は IntroFlow.swift:359 と EndingViews.swift:335-350）／FirstStageView／SettingsView「演出の速さ」／TournamentResultView.expGainRow。

## §1 まとめ
件数：全 16 件（**高 0／中 7／低 9**）。
- 一番重い（中）：#1 ガチャのログインスタンプ（丸の列）が読み上げ0＝何枚たまったか分からない／#2 衣装の札が未入手だと「未入手の衣装」としか読まれず、「交換できる」が読まれない（押して交換できるのに気づけない）。
- 観点① 丸の中の一字：expGainRow の「種・帳・間・見・場」は label あり（良）。ガチャの「？」「新」も label 側で処理済み。意味不明になる所は実質なし（#8 は合計の読み上げのみ）。
- 観点③ 全画面タップ：今回の対象では背景タップ閉じが GachaView の結果だけ（とじるボタンがあるので詰まない・#3）。FirstStage は時間送りで、ボタンも明示＝accessibilityAction 不要。
- 観点④ 文字サイズ：フォントは mzScaled で最大 1.35 倍止まり（Theme.swift:259）＝標準の大きい文字には効くが「アクセシビリティ用の特大」には追従しない（#16）。固定枠で切れそうなのは #11・#12・#13。

## §2 指摘の表
| # | 場所(ファイル:行) | 何が起きる | 直し方 | 重さ |
|---|---|---|---|---|
| 1 | GachaView.swift:85-89（ログインスタンプ Circle 22×22 の列） | 丸に文字も label も無い。VoiceOver では何も読まれず「何枚たまったか」が分からない（本文の説明文は枚数を言わない） | 列を `.accessibilityElement(children:.ignore)`＋`.accessibilityLabel("スタンプ \(s.loginStamps) / \(GachaCatalog.loginGoal) 枚")` | 中 |
| 2 | GachaView.swift:190-212（outfitCell） | `.accessibilityLabel` が子の文字を上書き。未入手は常に「未入手の衣装」＝「交換できる」タグ(canX)・「広告カット付き」が読まれない。canX でも交換でき ないでも同じ読み上げ。未入手で交換できない札は押しても何も起きないのに disabled でない。着用中は文字だけで isSelected が無い | 未入手：`canX ? "未入手の衣装、交換できます" : "未入手の衣装、まだ交換できません"`（広告カット付きも足す）。`.disabled(!owned && !canX)`。着用中は `.accessibilityAddTraits(.isSelected)`。`.accessibilityHint(owned ? "押すと着替えます" : "")` | 中 |
| 3 | GachaView.swift:216-236（resultOverlay） | 結果の板が出ても背景（衣装一覧・ボタン）が読み上げ対象のまま。出た瞬間の読み上げ・フォーカス移動も無い。背景の Color は onTapGesture だけ（ボタン扱いされない＝とじるボタンで代替できるので詰みはしない） | 板に `.accessibilityAddTraits(.isModal)`、背景 Color に `.accessibilityHidden(true)`、出た時に `UIAccessibility.post(.screenChanged, …)` か「結果」見出しへ focus。onTapGesture の Color に `.accessibilityAction(.escape){ results = [] }` | 中 |
| 4 | GachaView.swift:238-252（resultCell） | 1枠が「図→名前→レア→判子『新の判子』／かけら+3」とバラバラに読まれる。新規かどうかが「新の判子」で意味が弱い | `.accessibilityElement(children:.combine)`＋label `"\(名前)、\(レア)、\(isNew ? "新しく入手" : "かけら\(n)個")"` | 中 |
| 5 | GachaView.swift:168（天井 `3 / 100`） | 「3スラッシュ100」と読まれ何の数か不明（ゲージは hidden 済み＝良）。かけら行・説明文は別々 | HStack を combine し label `"天井ポイント 3、目標 100"` | 低 |
| 6 | GachaView.swift:89-96 の loginNote（:98）、:226 の結果 | 「今日の札をもらいました」「無料の1回がたまりました」が出ても読み上げ通知が無い（ボタンの文言が変わるだけ） | note 設定時に `AccessibilityNotification.Announcement(note).post()` | 低 |
| 7 | GachaRatesView.swift:15-36, 53-57（block 見出し・「提供割合」「レアリティ別」「衣装別」） | 見出しに isHeader が無く、見出し間ジャンプ（ローター）が使えない。長い規約ページなので不便 | 見出し Text に `.accessibilityAddTraits(.isHeader)` | 低 |
| 8 | GachaRatesView.swift:75-82（row）＋ TournamentResultView.swift:545-570（expGainRow） | 割合の行は「名前」「2.5%」「3着」が3つに割れて読まれる。経験点も「経験点 +12」「閃き」「+3」「語彙」「+2」…と全部別。種・帳等の一字自体は label あり（良）だが合計が文として読まれない | row／expGainRow の HStack に `.accessibilityElement(children:.ignore)`＋まとめ label（例 `"経験点 12、閃き3、語彙2。負けても入ります"`）。一字の丸は hidden にしてよい | 低 |
| 9 | FirstStageView.swift:88-95（`ツッコむ！`）・bottomPanel 全体 | 画面が自動で進む（ボタンは出てから約6.5秒で自動押下）。フェーズが変わる時の一文（「客席が、どっと沸いた。」等）は新しい Text が出るだけで読み上げ通知なし＝VoiceOver だと次の文を聞き逃す。ボタンを探す間に自動で進む | フェーズ変更時に `AccessibilityNotification.Announcement(文)`。VoiceOver 稼働中（`UIAccessibility.isVoiceOverRunning`）は自動押下の待ちを延ばす（または自動押下しない）。ボタン label は「ツッコむ」で良（済） | 中 |
| 10 | FirstStageView.swift:70-72（`とばす ▶`） | 「▶」が「右向き三角」と読まれる。左上でなく右上に出るため大きい文字だとコンビ看板（StageSign・padding.top 54）に重なり得る | `.accessibilityLabel("とばす")`。重なりは実機の大文字で確認 | 低 |
| 11 | TournamentResultView.swift:556-557（丸 22×22＋12pt）・:566 付近（`lineLimit(1).minimumScaleFactor(0.7)`） | 丸は固定 22pt なのに中の字は 12→最大 16pt に拡大。16pt の一字は収まるが、5種＋合計＋「負けても入る」を1行に押し込むため、大きい文字にしても 0.7 まで縮められ「大きくならない」。通常でも窮屈 | `@ScaledMetric` で丸の大きさを字に合わせる。`dynamicTypeSize >= .xxLarge` では ViewThatFits で2段に折り返す（`lineLimit(1)` を外す） | 中 |
| 12 | IntroFlow.swift:353-367（周回の案内 `bannerLines`＋はじめるボタン） | ScrollView 無しの縦並び（Spacer 固定高 118＋看板＋舞台＋案内3行＋ボタン）。大きい文字で案内が6行以上に折り返すと下の「はじめる」が画面外へ押し出される恐れ（実機未確認）。読み上げは3行が別要素 | 案内を combine して1つに。全体を ScrollView か ViewThatFits、または案内に `lineLimit`＋`minimumScaleFactor` | 中 |
| 13 | GachaView.swift:206（`Color.clear.frame(height: 20)`）・:203（名前 11pt `lineLimit(1)` `minimumScaleFactor(0.6)`） | 札のタグ行を高さ20固定で揃えているが、大きい文字ではタグが 20 を超え札の高さがそろわない。名前は 3 列の狭い幅で 0.6 まで縮む（最大 14.9×0.6≒9pt）＝大きくしても小さくなる | タグ行は `minHeight` 化。大きい文字では列数を 2 に（`dynamicTypeSize` で GridItem 数を切替） | 低 |
| 14 | ShareCard.swift:46-56（ShareCardButton） | 画像の生成前は 1×1 の透明＝共有ボタンが読み上げに存在しない（生成は一瞬）。共有する画像に代替テキストが無い（受け手側の話）。ShareCardView は画像化専用で固定 720×720＝画面に出ないので文字サイズ問題は無し | 生成前は `Label("共有", …)` を disabled で出す。SharePreview の題は既に「コンビ名　見出し」（良） | 低 |
| 15 | EndingViews.swift:343-346（トロフィー表示）・:360-390（図鑑 cell） | トロフィー見出し「記録」「トロフィー 3 / 22」に isHeader 無し。図鑑の未入手札は Button なのに押しても何も起きず disabled でない（読み上げは「？？？、No.3、ヒント」と並ぶだけ）。cell は押すと再生と分かる hint が無い | 見出しに isHeader。未入手は `.disabled(rec == nil)`（見た目は変えない）。入手済みは `.accessibilityHint("押すとエンディングを見返します")` | 低 |
| 16 | Settings：SettingsView.swift:48-54（演出の速さ）・:117-123（section） | Picker は label「演出の速さ」あり、選択中は VoiceOver が読む（良）。ただし下の説明（勝ち負けは変わらない）が Picker と結び付かず、見出し section に isHeader が無い。フォントの上限が 1.35 倍（Theme.swift:259）で、特大の文字サイズ（xxxLarge 以上のアクセシビリティ用）には追従しない＝全画面共通 | 説明は `.accessibilityHint`、section の見出しに `.accessibilityAddTraits(.isHeader)`。mzScaled の上限は意図した制限か要判断（オーナー決定の領域） | 低 |

## §3 良かった所（直し不要）
- 文字無しの丸（expGainRow）に label（c.displayName）あり。YoseHankoStamp は spoken() で意味が通る形に読む。YoseGauge は hidden＋隣に数字。FirstStage は reduceMotion 対応済み・波形は hidden。
- ガチャの有料ボタンは disabled を正しく使っている（無料0枚・スタンプ受取済み）。
- 提供割合ページは数値を GachaCatalog から生成＝読み上げも表示と一致。

## 対応（11/07 定期の回）
- 直した：#1 #2 #3 #4（ガチャ）・#9（初舞台の読み上げ＋読み上げ中は自動で押さない）。実機の VoiceOver では未確認。
- 残り：#11 #12（大きい文字の時の詰まり）と低9件。実機で確かめてから。
- #2 の disabled は入れない：未入手の札が灰色に沈み「広告カット付き」が読みにくくなった（目視）。読み上げの文だけ直した。
