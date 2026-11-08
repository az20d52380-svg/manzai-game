# 10年前提の取り残し 静的点検（careerYears 10→15・2026-11-08・記録のみ）

対象：ManzaiGame/Sources・GameCore/Sources（Tests除く）。コードは直していない。
既知（数えない）：t18「十年選手」・10年目の「今年が最後」・春新人/夏中堅/寒梅が結成10年以内。

## 結論
- 年の数字を条件にした台詞・独白・エンディングの選び分けで、**10年前提のまま取り残された物は見つからなかった**（高0・中0）。
- 実害のある所は直っている：Endings（題名・ヒント・キャプション・場面は「十五」「十六年目」）／判定 `year >= careerYears`／YearResultView の「来年」除外／TournamentResultView の finalYear／WeekMainView の満了トースト／EndingViews の年表 `1...15`／kanjiNumber（19まで）／GP の11年目以降ライン・成長予算は GameConfig に設定済み。
- 残りは文言・コメント・デバッグ用の小物のみ（低 6件）。

## 所見（すべて低）

### 1. GameConfig.swift:120 ― 説明コメントが10年のまま【低】
「本編は結成10年で完結・master_spec_v2 §1」。15年制で事実と合わない。動作には影響なし。
直し方：①今のまま ②「結成15年（10→15・較正A）」に書き換え（コメントのみ）。

### 2. YearResultView.swift:6 ― ファイル冒頭コメント「結成10年目の年末」【低】
動作は `careerYears` 参照で正しい。直し方：①今のまま ②「結成最終年（config.careerYears）」に。

### 3. GameSession.swift:1709・1848・1854・1865 ― デバッグ自己診断が10年表記【低】
- 1709（MZ_STOPWEEK コメント「10年目の年末を手で遊ぶ用」）、1848/1854（ラベル「10年完走」「10y …」）は、`GameConfig()` 既定＝15年を回すので表示が事実と違う。
- 1865 は `year: 10, careerYears: 10` を明示で渡す判定表（#3〜#6）。判定自体は引数どおりで正しく、15年制の config では検証していない。
- 起きること：デバッグ出力の読み違いだけ。ゲーム本編には出ない。
- 直し方：①今のまま ②ラベルを `\(config.careerYears)y` に、1865 を `year: 15, careerYears: 15` に（出力の #番号は不変）。

### 4. ChoiceEventData.swift:1213（0057 年末のライブ）― 「来年の話も、そこで出るかもしれないな」【低】
年末ライブは12月（週33-36）の抽選で、15年目にも出うる。15年目の年末は区切り（来年がない）ので、野々村の「来年の話」だけ少し浮く。出ても事務所の話で矛盾は小さい。
直し方：①今のまま ②最終年だけこの一言を外す（GameSession 側で year >= careerYears の時に1行省く。表示のみ）。③最終年はこのイベントを出さない（乱数・golden に触るので非推奨）。

### 5. EndingViews.swift:217-224（#5 年表の絵）― 15行の縦配置が詰まりぎみ【低】
行 y = h×(0.03+0.058×(y−1))、高さ 0.045。15行目の下端は約 0.887h。下の幕の線は 0.9h なのでほぼ接する（余白 約0.013h）。小さい端末で重なる恐れ。
直し方：①今のまま（目視で問題なければ）②行間 0.058→0.055 に詰める（15行目の下端が約 0.845h）。※目視はしていない。

### 6. 「10年で読み返しの多い所」系の増補（DialogueData.swift:66・247・311、FanReportData.swift:115、NotebookView.swift:265 のコメント）【低】
- 台詞プールの量は10年想定で増補している。15年だと同じ行が1.5倍まわる。
- 年末独白（YearResultView の yeLeap/yeStall は各13行）は `indexAvoidingUsed` で使用済みを避け、全部使うと古い順に戻る。決勝に立った年は独白なし・躍進/停滞に分かれるので、同じプールから13回取るのは稀。最終年は「来年」を含む2行を除いて約11行。→ 実害はほぼなし。
- NotebookView:265 の「通算の賞金は10年で5桁（万）」：15年だと6桁もありうるが `minimumScaleFactor(0.6)` と lineLimit(1) あり。
- 直し方：①今のまま ②読み返しが気になる場面だけ、実プレイ（15年）の目視/採点で増補を足す。

## 確認して問題なしと判断した物（数えない）
- Endings.swift 題名・hint・caption・場面：すでに十五年表記（「十五冊目のノート」「十五年分の年表」「十六年目の一月」）。enum 名 `tenYearsClose/tenYearsTrue` はコード上の識別子のみ（表示に出ない・図鑑は number で保存）。
- Endings.judge／Meta.onYearEnd／GameSession.canChooseRetire 付近：`careerYears` 参照で15年に追随。
- Design/YoseYearTurnCurtain.swift:177 `year >= 10 ? 76 : 112`：「十一〜十五」は2文字で、10と同じサイズで収まる。kanjiNumber も 19 まで対応。
- GameConfig.growthEndYear=15・lateGrowthStartYear=11・Calendar.gpLateStartYear=11：15年制として設定済み（仕様）。
- GameSession.swift:671 `year >= 2 || week >= 24`（後輩の誘い）・FanReportData.isKnown `year >= 2`：下限の条件で、上限の取り残しではない。
- S6bView.swift:163「来年も、また出よう」：思い出のモンタージュ（過去の場面）で、現在の年と無関係。
- WeekMainView.swift:1499/1521、CalendarView.swift:195：`careerYears`／eligibility 参照で追随済み。
- 年で選ぶプールの「最大の年が10」という作りは見つからなかった（年の数字で台詞を引く表は無く、`year` は 1年目／2年目以降／最終年 の3分岐のみ）。

## 件数
所見 6件（高0・中0・低6）。いずれもコメント・デバッグ・目視確認レベルで、15年制の本編動作を壊す取り残しは無し。
