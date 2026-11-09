# 未採点の文の置き場の洗い出し v0（2026-11-10・静的・コード未変更）

## 結論3行（採点の優先順の上位5つ）
1. WeekMainView.swift（98）・SettingsView.swift（73）・FinalsPresentationView.swift（86）：画面の説明文・ボタン・お知らせ。文面を○△×で見た記録が無く、触れた文書は 10/26 の表記ゆれ点検（ui_copy_consistency_1026）だけ。
2. Meta.swift（63・節目称号などの名前）・GachaView.swift（40・衣装ガチャの説明）・YoseGameParts.swift（12・実力/体力ラベル）：採点系文書に名前が一度も出ない。
3. TournamentResultView（49）・NotebookView（44）・AbilityUpView（39）・StageViews（33）：10/26 の表記ゆれ点検のみ。台詞系の採点（dialogue_score 等）には入っていない。
（補足）DialogueData/ChoiceEventData/FanReportData/JudgeTalk は採点記録あり。ただし文の何割が○△×済みかは文書上の数え上げが無く未確認。

## 方法と限界
- 数え方：`grep -c` で日本語を含む文字列リテラルの行数（ManzaiGame/Sources と GameCore/Sources、上位40ファイル）。
- 「採点の記録」判定：ファイル名または主な型名が、ファイル名に score / independent / lines / ui_copy / text_repeat を含む docs/*.md に出るか（53本。code_review・visual_・a11y_ は見た目・コード点検なので除外）。名前が出るだけで、その文面を全部見た証拠ではない。
- ui_copy_consistency_1026_v0 は表記ゆれ（閉じる/戻る等）の静的点検で、○△×採点ではない（○△×記号は1件）。よって「ui_copy のみ」は実質「文面の採点なし」扱いにした。
- 日付は git log -1 --format=%cs。

## 表（日本語文字列リテラル数の多い順）
区分：A=文面の採点文書あり／B=ui_copy 表記ゆれ点検のみ（実質未採点）／C=記録なし

| 数 | ファイル | 区分 | 最新の関連文書（日付） | 場面 |
|---|---|---|---|---|
| 98 | WeekMainView | B | ui_copy_consistency_1026（10/26） | 週のメイン画面の説明・ボタン・お知らせ |
| 86 | FinalsPresentationView | B | ui_copy_consistency_1026（10/26） | 決勝の演出画面の文 |
| 73 | SettingsView | B | ui_copy_consistency_1026（10/26） | 設定画面の項目名・説明 |
| 63 | Meta | C | なし | 節目・称号などの名前（t01 初舞台の足音 等） |
| 49 | TournamentResultView | B | ui_copy_consistency_1026（10/26） | 大会結果画面 |
| 44 | NotebookView | B | ui_copy_consistency_1026（10/26） | ノート画面 |
| 40 | GachaView | C | なし | 衣装ガチャの説明・ルール導線 |
| 39 | AbilityUpView | B | ui_copy_consistency_1026（10/26） | 能力アップ演出の文 |
| 38 | Design/YoseCatalog | B | ui_copy_consistency_1026（10/26） | DEBUG専用の部品見本（製品に出ない） |
| 33 | StageViews | B | ui_copy_consistency_1026（10/26） | 舞台画面の文 |
| 28 | S6bView | B | ui_copy_consistency_1026（10/26）※dialogue_score_1108b にも名前あり | 場面画面 |
| 28 | QualifierNoticeView | B | ui_copy_consistency_1026（10/26） | 予選のお知らせ |
| 27 | NetaCatalog | A? | dialogue_score_1027（10/27・1件のみ） | ネタ名・説明 |
| 27 | CommandData | A? | dialogue_score_1019e（10/19） | コマンド名・説明 |
| 26 | GachaRatesView | A? | dialogue_score_1107（11/07・1件のみ） | ガチャ提供割合の説明 |
| 25 | Design/EventBackgrounds | B | ui_copy_consistency_1026（10/26） | イベント背景の名前 |
| 23 | ShopView | B | ui_copy_consistency_1026（10/26） | ショップ画面 |
| 22 | Design/YoseMilestoneFX | B | ui_copy_consistency_1026（10/26） | 節目演出の文 |
| 21 | GameConfig | A? | text_repeat_15y_1108（11/08） | 設定値に付く文 |
| 20 | EndingViews | B | ui_copy_consistency_1026（10/26）、dialogue_score_1107 | エンディング画面 |
| 19 | Design/YoseYearTurnCurtain | B | ui_copy_consistency_1026（10/26） | 年変わりの幕間 |
| 17 | FinalistAnnounceView | A | finals_mc_lines_score_1110（11/10） | 決勝進出者の発表 |
| 16 | StageFrame | C | なし | 舞台の足元ネーム（俺/谷口）・コンビ名 |
| 16 | FirstStageView | A? | dialogue_score_1108b（11/08・1件のみ） | 初舞台画面 |
| 15 | Design/YoseChampionCelebrationView | B | ui_copy_consistency_1026（10/26） | 優勝演出 |
| 15 | CalendarView | B | ui_copy_consistency_1026（10/26） | カレンダー画面 |
| 14 | Theme | C | なし | 能力の略称（セ・発・表） |
| 14 | Store/StageOutfit | C | なし | 衣装名（標準・黒紋付・紺スーツ） |
| 14 | RootView | A? | dialogue_score_1107b（11/07・1件のみ） | ルート画面の文 |
| 12 | Design/YoseGameParts | C | なし | 実力/体力ラベル・読み上げ文 |
| 797 | DialogueData | A | veteran_lines_main_sweep_1110（11/10）ほか24本 | 登場人物の台詞 |
| 497 | ChoiceEventData | A | veteran_lines_main_sweep_1110（11/10）ほか18本 | 選択肢つきイベント |
| 417 | JudgeTalk（GameCore） | A | text_repeat_rate（10/15）・judge_final_comment_score_v1 など | 審査員の講評 |
| 358 | FanReportData | A | veteran_lines_main_sweep_1110（11/10）ほか15本 | ファンの声 |
| 97 | YearResultView | A | veteran_lines_main_sweep_1110（11/10） | 年間結果画面 |
| 58 | Endings | A | veteran_lines_main_sweep_1110（11/10） | エンディングの文 |
| 50 | IntroFlow | B | ui_copy_consistency_1026、after_win_lines_1107 に名前あり | 導入フロー |
| 41 | MeetingKind | A | veteran_lines_main_sweep_1110（11/10） | 打合せの種類・文 |
| 41 | GameSession | A? | text_repeat_rate（10/15） | 進行中に出るお知らせ文 |
| 32 | FinalsBroadcastIntro | A | finals_mc_lines_score_1110（11/10） | 決勝の生放送イントロ |

## 次の一手（決めなくて進められる）
- 区分B・Cの上位（WeekMainView・SettingsView・FinalsPresentationView・Meta・GachaView・TournamentResultView・NotebookView）の文面を抜き出し、他の採点と同じ○△×の様式で独立採点する。
- 区分A?（名前が1件だけ出る）は、その文書で本当に文面を見ているかを確認してから区分を確定する。
