# 読み上げ（VoiceOver）点検 a11y_check_1026_voiceover_v0（2026-10-26・読み取りのみ・コード未変更）

注：指定の a11y_check_1026_v0.md は別の点検（文字サイズ目視）が先に使っていたため、上書きを避けてこの名前にした。
対象：10/19 以後に変わった 43 ファイル（画面は約 25）。見方は grep で当たりを付けて該当行だけ読んだ。**実機の VoiceOver では未確認＝すべて読んだ上での推測を含む。** 10/19・10/25 の指摘（FinalistAnnounce・QualifierNotice・RentStatement・ComboKind 等）は繰り返さない。

## §1 まとめ
件数：全 11 件（**高 0／中 6／低 5**）。
- 良い点：文字の無いボタンはどれも accessibilityLabel あり（設定・＋－・年末へ等）。onTapGesture 17 か所のうち数か所（Notebook・FinalsBroadcastEnding・FinalsPresentation）は label／action 済み。長く動く画面の多くは reduceMotion を読んでいる。Canvas の飾りは既定で読まれない見込み（推測）。
- 一番重い（中）：**全画面タップで送る画面に「次へ」の操作が無い**（#1）。文字を2回タップすれば進むはずだが、探して押す手がかりが無い。動かなければ「高」に上がる（実機で要確認）。
- 「高」は無し（操作できない確証のある所は見つからず）。

## §2 指摘の表
| # | ファイル:行 | 何が | 直し方の案 | 重さ |
|---|---|---|---|---|
| 1 | IntroFlow.swift:83 / S6bView.swift:192 / TournamentResultView.swift:568 / ChoiceEventOverlay.swift:107 / StageFrame.swift:291 / FinalsBroadcastIntro.swift:57 | 全体に onTapGesture だけで進む。isButton も accessibilityAction も無い（FinalsBroadcastIntro:596 など一部の画面は付いている＝そこと不揃い）。読み上げ中に「押すと次へ」が出ない | 各画面に `.accessibilityAction(named: "次へ") { 同じ処理 }`（10/19 の直し方と同形）。ChoiceEventOverlay は announcement 済みなので action だけ | 中 |
| 2 | Design/YoseChampionCelebrationView.swift:170 / Design/YoseRankUpOverlay.swift:113 / Design/YoseMilestoneFX.swift:146 | 同形。ただし自動で進む／閉じる（MilestoneFX は reduceMotion で止め絵→閉じる）ので詰まりにくい | #1 と同じ action を足す（`handleScreenTap`／`dismissImmediately`／`onFinish`）。YoseMilestoneFX は VoiceOver 中に自動で閉じない作りかを実機で確認（推測） | 中 |
| 3 | WeekMainView.swift:612（banterBox） | 掛け合いの次の台詞へ進むのが onTapGesture だけ。最後の1行になるまで「まだ続きがある」ことが読まれない | `.accessibilityAddTraits(.isButton)`＋ヒント「押すと次の台詞」（最後の行では付けない） | 中 |
| 4 | RadarChart.swift:全体（YearResultView.swift:213 で使用） | Canvas 1枚で能力の形を描くだけで accessibilityLabel が無い。軸名は Canvas 内の文字なので読まれない見込み（推測）。年初と現在の差は図だけで伝わる | 呼び出し側に `.accessibilityElement(children:.ignore).accessibilityLabel("能力の変化、体力 〇→〇、…")`。数字が別の場所に文字で出ているなら低に下げる（未確認） | 中 |
| 5 | AbilityUpView.swift:306, 315 | 「＋」「－」は label あり（良）。ただし Image 自体に hidden が無く、label と二重になる可能性（推測。Button に label があれば通常は上書きされる） | 念のため Image に `.accessibilityHidden(true)` | 低 |
| 6 | Design/YoseGameParts.swift:121 / IntroFlow.swift:544 / WeekMainView.swift:777, 995 / StageViews.swift:255 | 文字つきボタンの飾り記号（dice.fill・plus・stamp・glyph）に hidden が無く、「dice fill、おまかせで考える」のように記号名が先に読まれる恐れ | 各 Image に `.accessibilityHidden(true)`（10/19 の基準②） | 低 |
| 7 | WeekMainView.swift:1045（札の iconBox・v.glyph） | 札の左の記号に hidden／まとめ（accessibilityElement）が見当たらず、札の読み上げが「記号名＋札名＋…」と細切れになる（推測） | iconBox を hidden にして、札全体を `.accessibilityElement(children:.combine)`（行 933 の札と同じ形） | 低 |
| 8 | S6bView.swift:47, 50, 131, 227 | 0.5〜1.8 秒の画面切替・数字カウントアップ・焼き付きが reduceMotion を読まない（長いのは 1.8 秒の数字だけ） | `@Environment(\.accessibilityReduceMotion)` を足し、true なら `counted = true`／アニメ無しで切替 | 低 |
| 9 | RadarChart.swift:120, 149 | 0.6〜0.8 秒のモーフが reduceMotion 未対応 | `animate` を reduceMotion で false に（#8 と同じ） | 低 |
| 10 | IntroFlow.swift:86, 370, 540, 668／EndingViews.swift:55, 395／RootView.swift:314, 329, 351／CalendarView.swift:165／NetaSelectionView.swift:26／ChoiceEventOverlay.swift:135, 306 | 0.15〜0.5 秒の短い切替で reduceMotion を読まない。長くないので影響は小さい | 余裕のある時に `Theme.Motion` 側へ reduceMotion を読む共通口を作ると一括で直せる（案） | 低 |
| 11 | Design/YoseChampionCelebrationView.swift:603 ほか Canvas 10 か所（YearTurnCurtain:446・MilestoneFX:155・RankUp:359・FinalsBroadcastIntro:303 等） | Canvas の飾りに hidden が無い。Canvas は既定で読まれない見込みだが未確認 | 実機で読まれるなら親 View に `.accessibilityHidden(true)`。読まれないなら対応不要 | 低 |

色だけ・図だけの意味（観点3）：星・ランク・目盛りを色だけで示す所は今回の対象では **#4 のレーダー以外に見つからなかった**（EventBackgrounds の Circle は背景の飾りで、container 側で hidden 済み：行 255・325）。CharacterAvatars の顔の図形は飾り（呼び出し側の label 次第・未確認）。

## §3 見たファイル
全 43：AbilityUpView／CalendarView／CharacterAvatars／ChoiceEventData／ChoiceEventOverlay／ComboKind／ComboKindPickerView／Design（EventBackgrounds・YoseChampionCelebrationView・YoseComponents・YoseGameParts・YoseMilestoneFX・YoseRankUpOverlay・YoseTokens・YoseYearTurnCurtain）／DialogueData／EndingViews／Endings／FanReportData／FinalsBroadcastIntro／FinalsPresentationView／GameSession／IntroFlow／MeetingKind／Names／NetaSelectionView／NotebookView／QualifierNoticeView／RadarChart／RootView／S6bView／SettingsView／ShopView／StageFrame／StageScene／StageViews／Store/StageOutfit／TalkParts／Theme／TournamentResultView／WeekHint／WeekMainView／YearResultView。
- 深く読んだ（該当行まわり）：#1〜#11 の各所。
- grep だけ（データ・ロジック系で画面ではない）：ChoiceEventData・DialogueData・FanReportData・GameSession・MeetingKind・Names・Endings・ComboKind・WeekHint・YoseTokens・StageOutfit。
- 見落とし：SettingsView・ShopView・CalendarView・StageScene の個別の画面はコントロール単位では読んでいない（grep の当たりが無かっただけ）。
- 10/27 深夜の定期：#11 済＝飾りの Canvas 26か所（レーダー図を除く・12ファイル）に .accessibilityHidden(true)。表示は不変・ビルド OK。
