# 画面の文の直書き数字 × GameConfig 静的点検 v0 / 2026-11-08

## 結論（3行）
- 今の値と**食い違う（不一致）直書きは 0 件**。ただし**一致しているが直書き（設定を変えると置いていかれる）が 8 件**ある。目立つのは借金の知らせ（WeekMainView.swift:1454-1456）＝「100万／50万／80万／あと20万」が `bankruptLine` から作られておらず、段の境目（GameSession.swift:1264 の -80万・-50万）も直書きで、文と段が二重に固定されている。
- 設定から組み立て済み（安全）なのは、生活費・生活の間隔（WeekHint／WeekMainView:1476／SettingsView:253）、夜逃げライン（SettingsView:254）、エントリー費（StageViews:173）、決勝の週（SettingsView:277・CalendarView:144）。
- 台詞・エンディングの「十五年」「十五冊目」は careerYears=15 と一致（物語上の数だが値と結びつく）。ほかの台詞内の数（五千円・一万円・二か月など）は個別イベントの物語上の額で、GameConfig とは結びつかない。

方法：ManzaiGame/Sources の文字列リテラルを 数字（半角・全角・漢数字）＋単位（円・万・週・年・回・%・点・枚・本・人）で grep し、GameConfig（GameConfig.swift／Calendar.swift の CalendarConfig）と突き合わせた。行番号は 2026-11-08 時点。机上の点検（ビルド・実機は未実施）。

## 1. GameConfig の主な数値（今の値）
| 項目 | 名前 | 値 |
|---|---|---|
| 1年の週数 | weeks | 48 |
| 芸歴の年数 | careerYears | 15 |
| 初期の所持金／体力／知名度／能力 | initMoney／initStamina／initFame／initAbility | 30万／100／3／10 |
| 生活費・間隔 | livingCost／livingInterval | 14万円／4週ごと |
| 部屋の家賃上乗せ | roomRents | 0／5万／15万 |
| 借金ライン（夜逃げ） | bankruptLine | -100万 |
| 能力の上限／メンタル上限 | abilityCap／mentalCap | 120／100 |
| 体力の稽古不可線／体調ダウン閾値 | staminaGate／injuryThreshold | 20／50 |
| 相性の上限・初期 | compatCap／compatInit | 20／5 |
| 先輩の誘い（行く）の費用 | inviteMoney | 5,000円 |
| エントリー費 | calendar.entryFee | 2,000円 |
| 決勝の週・GP回戦の週 | gpFinalWeek／gpRounds | 47／30,39,41,43,45 |
| GP優勝賞金・HANA決勝賞金 | gpPrize／HANA決勝 prize | 500万／250万 |
| 道中大会の週 | tournaments | 12,15,27,29,35,38,46 |
| 知名度の閾値 | offerCardFames／推薦制中堅賞 fameAtLeast | 30,55／30 |
| 遠征費 | busTravel／trainTravel | 1万／3万 |
| 持ちネタ枠・ネタの完成度 | netaActiveSlots／（完成度は0〜100） | 4／100 |
| 店の価格 | items | 3千〜240万 |

## 2. 表（不一致・一致だが直書き）
「種別」：説明＝説明文／ヒント、台詞＝物語内の台詞・地の文、札＝選択肢ラベル。判定「一致・直書き」は今は正しいが設定を変えると置いていかれる。

| # | ファイル:行 | 文の抜粋（20字まで） | 数字 | 対応する GameConfig と今の値 | 判定 | 直すなら（設定から組み立てる） | 種別 |
|---|---|---|---|---|---|---|---|
| 1 | WeekMainView.swift:1454 | 借金が100万を越えると、芸人を… | 100万 | bankruptLine = -1,000,000 | 一致・直書き（既知 number_display_audit #12） | `-session.config.bankruptLine / 10_000` で組む | 説明 |
| 2 | WeekMainView.swift:1455 | 借金が50万を越えた。あと50万 | 50万／あと50万 | bankruptLine の半分（-100万の 50%）。段の境目 GameSession.swift:1264 の -500_000 も直書き | 一致・直書き（文と段の境目が二重固定） | 段の境目を `bankruptLine * 0.5/0.8` から作り、文は境目と「ラインまでの残り」を計算して埋める | 説明 |
| 3 | WeekMainView.swift:1456 | 借金が80万を越えた。あと20万 | 80万／あと20万 | bankruptLine の 80%（-80万）。境目 GameSession.swift:1264 の -800_000 も直書き | 一致・直書き | 同上 | 説明 |
| 4 | ShopView.swift:74 | …（4週ごとの支払い） | 4週 | livingInterval = 4 | 一致・直書き | `\(session.config.livingInterval)週ごと` | 説明 |
| 5 | ShopView.swift:110 | 生活費と合わせると 4週で… | 4週 | livingInterval = 4 | 一致・直書き | 同上 | 説明 |
| 6 | ShopView.swift:135 | 新しい家賃は次の支払い（4週ごと）… | 4週 | livingInterval = 4 | 一致・直書き | 同上 | 説明 |
| 7 | ChoiceEventData.swift:341,363 | 先輩と飲みに行く（5,000円） | 5,000円 | inviteMoney = 5,000（効果 GameEngine.swift:325 が config を読む） | 一致・直書き（効果は設定、ラベルだけ固定） | ラベルを `inviteMoney.formatted()` で組む（ChoiceEventText に値を渡す口が要る） | 札 |
| 8 | Endings.swift:32,34,60-63,73,75,154 | 十五年分の年表／十五冊目のノート／十五年、ずっと隣に… | 十五 | careerYears = 15 | 一致・直書き（結末の判定自体は `year >= careerYears`＝設定連動。名前の `tenYears…` も歴史的な呼び名で数と食い違う） | 年数だけを漢数字変換して差し込む（台詞は物語上の数なので変更は任意。変えるなら careerYears とセットで文を見直す） | 台詞 |
| 9 | FinalsBroadcastIntro.swift:155,286 | 審査員席 7名・1人100点満点／今夜の7人 | 7名／100点 | 審査員数・満点は GameConfig に無い（JudgeData 側の構造） | 設定外（対応する名前なし）。審査員の数を変えるとここだけ残る | `judges.count` から作る（点満点は定数化） | 説明 |
| 10 | FinalsPresentationView.swift:844 | …/ 7 人 開票 | 7 | 審査員数（同上） | 設定外 | `judges.count` | 説明 |
| 11 | SettingsView.swift:236,246 ほか用語集 | 5種の経験点／4つの段／上位3組 | 5／4／3 | ExpCurrency 5種・仕上がりの段4・決勝の最終決戦3組（いずれも GameConfig に値なし。列挙型や固定の構造） | 設定外 | 列挙の件数から作る（任意）。用語集の注記に「数値は GameConfig の既定値に合わせて書く」とあるので、現状の運用ルールとしては許容 | 説明 |
| 12 | SettingsView.swift:236ほか（完成度）／WeekMainView.swift:1587 | 完成度 0〜100／…/100 | 100 | 完成度の上限は GameConfig に値なし（ネタ側の定数） | 設定外 | 上限を定数にして参照 | 説明 |
| 13 | Meta.swift:62,63 | 夜行バスで遠征を10回する／稽古を100回する | 10回／100回 | GameConfig に対応なし（実績の閾値）。**達成判定の実装行が見つからず、文と判定の一致は未確認** | 要確認（判定コードを読む必要あり） | 実績の閾値を定数にし、文と判定が同じ定数を読むようにする | 説明 |

## 3. 設定から組み立て済み（直書きではない・参考）
| ファイル:行 | 何を | 読んでいる値 |
|---|---|---|
| WeekHint.swift:44,48,51 | 今週末の生活費◯万円 | livingCost（部屋の上乗せ込み＝livingCostDue） |
| WeekMainView.swift:1476 | ◯週に1度…◯万円が引かれる | livingInterval／livingCostDue |
| SettingsView.swift:253 | 生活費の用語 | `GameConfig()` の livingInterval／livingCost |
| SettingsView.swift:254 | 夜逃げ◯万円 | `GameConfig().bankruptLine` |
| SettingsView.swift:277 | 決勝（第◯週） | `GameConfig().calendar.gpFinalWeek` |
| CalendarView.swift:144 | 第◯週が決勝 | `cal.gpFinalWeek` |
| StageViews.swift:173 | エントリー費◯円 | `cal.entryFee` |
| GachaView／GachaRatesView | ◯枚・◯円・天井◯ | `GachaCatalog`（GameConfig 外だが定数経由） |
| WeekMainView.swift:1499, 1521 | 芸歴の年数制限／最終年の表示 | careerYears |

補足：SettingsView の用語集は `GameConfig()`（既定値）を読むので、実行中の `session.config` が既定値と違う場合は食い違い得る（今は同じ）。

## 4. 台詞のうち値と結びつく物
- 結びつく：Endings.swift の「十五年」系（#8）。
- 結びつかない（物語上の額・期間）：ChoiceEventData.swift:900「一組一万円」、:1043「一万二千円」、:1211「一人五千円」、:1098-1114「二か月」ほか。イベントの所持金効果は ChoiceEvent.swift（GameCore）側に別に書かれており、台詞の額と効果の額が一致しているかは**この点検では未確認**（上の 0044/0048/0057 は GameCore のコメントと金額が一致）。
- DialogueData.swift:64 は「本番まであと二週」と実週数（`weeksLeft == 2`）の対応を持つ。数は文に直書きだが、判定と同じ値なので一致。

## 5. 件数
- 不一致（今の値と食い違う）：**0 件**
- 一致だが直書き（設定を変えると置いていかれる）：**8 件**（#1〜#8。借金ライン3行・4週3行・先輩の誘いラベル・十五年系を各1件で数える）
- 設定外の数字（GameConfig に対応する値が無い）：4 件（#9〜#12）／要確認 1 件（#13）
- 補足：借金の知らせ（#1〜#3）は、文と段の境目（GameSession.swift:1264）の 2 か所に同じ前提が散っている。bankruptLine を変えるならここを最初に直すのが効率的。
