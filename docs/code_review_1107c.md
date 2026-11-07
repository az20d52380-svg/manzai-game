# コード点検 11/07c（女性コンビ × THE HANA を1キャリア通しで見る・読み取りのみ）

範囲：Calendar.swift の hanaTournaments／WeekRunner.swift:219／TournamentResultView／StageViews／QualifierNoticeView／CalendarView／RootView と、そこから辿れる GameSession・WeekMainView・YearResultView・NotebookView・Meta。
既出の docs/code_review_1107.md の項目は除く。確かめられなかった物は「未確認」と書く。式・乱数・golden の変更提案は無い（すべて表示側の直し）。

| # | ファイル:行 | 具体的に何が起きるか | 重さ | 直し方の案 |
|---|---|---|---|---|
| 1 | TournamentResultView.swift:108〜150（isHanaVideo は :136 の札と :72 だけ） | HANA1回戦は動画審査なのに、結果画面は他の回戦と同じ舞台のまま出る。明るい舞台（StageFrame）、「客席のウケの波形」、「——どっと沸いた！」（StageTelopBelt）、審査講評（舞台上の講評文）。札だけ「動画審査」。入口（StageViews）とお知らせ（QualifierNoticeView）は動画用に直してあるので、結果画面だけ舞台のまま | 中 | isHanaVideo の時は波形板を出さない・テロップを「——通知が届いた」系に替える・講評は動画審査用の短い文に替える。通知が先に結果を知らせるので（needsQual）判の演出は薄くしてよい。表示だけで判定は触らない |
| 2 | TournamentResultView.swift:60（FanReportData.voices）／FanReportData.swift:17〜33 | 結果画面の「ファンの声」の文面に「客席と完全に噛み合ってた」「拍手が鳴りやまなかった」などがあり、HANA1回戦（動画審査）でも同じ文面が選ばれる可能性がある。fanActive が HANA1回戦で実際に起動するかの分岐は未確認 | 中（未確認あり） | isHanaVideo の時は FanReportData を使わない（または動画向けの声に替える）。まず fanActive の起動条件を確認 |
| 3 | GameSession.swift:583（nextMilestoneForEvent, highStakes）／ChoiceEventData.swift:258〜（preTournamentEve） | 大会前夜イベントは「次の本番が1週後・highStakes」で発火する。HANAの段は全部 highStakes:true（GameSession.swift:719）なので、HANA1回戦（動画審査）の前夜にも「明日の大会、駅に集合でいい？」「じゃあ明日、駅で」が出る。舞台に立たない週に駅集合は合わない | 低〜中 | nextStage の name が "HANA1回戦" の時は前夜イベントを出さない、または動画用の1本を用意する（文章は正典の v2 バナーを読んでから） |
| 4 | GameSession.swift:719／WeekMainView.swift:1648（nextMilestone）／:448〜 goalBanner | 日程の目標帯・次の本番の名前が内部名のまま「HANA1回戦　今週！」「HANA決勝」と出る。頂GPは GPName.display を通して「頂GP 1回戦」になるが、HANAは通さない（結果画面・入口は「THE HANA 1回戦」）。同じ大会が画面ごとに名前が違う | 低 | upcomingStages の StageInfo(name:) で HANA の時も GPName.display(t.name) を通す（表示のみ） |
| 5 | YearResultView.swift:156〜170（「これまでの頂グランプリ」）／NotebookView.swift:186〜212／GameSession.swift:1083 YearRecord | 年表は YearRecord（GPの到達だけ）で作るので、女性コンビの HANA の結果（どの段で敗退・優勝）が年表に一切出ない。HANAだけ勝ち上がった年も「1回戦敗退」等の GP の行になる。金額（その年の大会の賞金の合計）には HANA が入るので、行と金額が合わない年が出る | 中 | YearRecord に Optional で hanaBest（到達した段・nil＝男コンビ／旧セーブ）を足し、年表の行末に小さく「HANA 準決」等を出す。旧セーブは nil で開ける |
| 6 | NotebookView.swift:173（通算の優勝） | 通算「優勝」は 今年の出来事ログの「優勝」＋ yearHistory の GP優勝 の和。前の年の HANA 優勝はログが年ごとに消えるので数に入らない（道中大会の優勝も同じ仕組みで消える既存の癖）。HANA優勝の通算はエンディング（EndingViews:341 の MetaBook.hanaWins）にしか出ない | 低 | きろく画面の優勝に state.hanaWins を足すか、「THE HANA 優勝 N回」を1行足す |
| 7 | YearResultView.swift:396〜（stageRecord）／:415・:450 付近の独白 | stageRecord は出来事ログから「敗退」を数えるので、HANA の敗退も負けに入る。HANA1回戦で落ちた年（GP は好調）に「今年は、予選で落ちる日が多かった」系の独白が出る可能性がある。独白の選び方の全体は未確認 | 低（未確認あり） | 数える対象を GP名（"GP"始まり）と道中大会に限る、または HANA を別集計 |
| 8 | CalendarView.swift:176〜179（isTournamentWeek） | 過ぎた週は「従来どおり true」なので、HANA1回戦に落ちた年の第37・42・44週（出られない段）も日程表で「大会」の色に塗られる可能性がある（道中の推薦制中堅賞などは同じ作りで既存）。塗りと categoryLog の優先関係は未確認 | 低（未確認あり） | 過ぎた週は weekResults／categoryLog に大会の記録がある週だけ塗る |
| 9 | TournamentResultView.swift:166（gpQualifierNames） | GPの予選で落ちると相性が下がる＋谷口の「……次、いこう」が出るが、HANA1・2回戦／準決勝で落ちても出ない。意図的かどうかは未確認（オーナー判断） | 低（判断が要る） | 揃えるなら gpQualifierNames に HANA を足す（相性の式は WeekRunner 側＝規律A。表示の一言だけなら view 側のみ） |

## 確かめて問題なしだった点
- **男コンビに HANA が出ない／旧セーブ**：femaleCombo は Optional（GameState.swift:108）。tournament(inWeek:state:) は femaleCombo==true の時だけ HANA を返す（Calendar.swift:116〜120）。isEligible も femaleCombo を見る。
- **週の重なり**：HANA は 第32・37・42・44週。道中は 12・15・27・29・35・38・46、GP回戦は 30・39・41・43・45、決勝・敗者復活は 47。同じ週は無い（tournament(inWeek:state:) の「道中優先で先返し」が実際に効く場面は無い）。近い週は 43(GP準々)・44(HANA決勝)・45(GP準決) の3連続だけで、WeekRunner.proceed の section 順（道中/HANA→GP）で別々に処理される。ただし週を動かした時の重なり検出テストは無い（低・案：Calendar の週の重複を調べる単体テストを1本）。
- **中断→復帰**：hanaYear／hanaNext／hanaWins は GameState の Optional フィールドで、WeekRunnerSnapshot.state（WeekRunner.swift:632）→ SaveData.runner に含まれて保存される。復帰時の pendingSpec も tournament(inWeek:state:) で引き直す（WeekRunner.swift:689）。comboKind も SaveData に保存され（GameSession.swift:1192・263）、femaleCombo と合う。進みは失われない。
- **HANAの進み方**：通過で hanaYear=year／hanaNext=i+1、最終段の通過で hanaWins+1（WeekRunner.swift:219〜225）。年が変わると hanaYear!=year で2回戦以降は閉じ、1回戦はいつでも出られる。
- **年末の賞金合計**：StageResult.prize を totalPrize に足す経路（GameSession.swift:1326）はGP・HANA共通で、HANA決勝の250万も入る。解散・夜逃げの週の分も weekResults から足される（:1350）。出来事ログの「優勝／通過」の言葉は prize>0 で決まり HANA決勝＝優勝になる（:1695）。
- **次の大会の案内**：upcomingStages は HANA を含み（GameSession.swift:718）、通過後に開く段だけが出る。「年末へ」の条件 noStagesLeft にも HANA が効く。
- **カレンダー**：tournamentName は HANA を GPName.short で略す（CalendarView.swift:165）。
- **結果画面の語**：HANA決勝の通過は「優勝」の判・優勝演出・判子「優勝」、他の段は「通過／突破」。決勝の敗退は FinalsPresentationView（GP決勝専用）に行かず TournamentResultView に来る（RootView.swift:394）。
- **トロフィー・戦績**：HANA決勝の通過だけ recordHanaWin（Meta.swift:162、passed で囲われている）。六冠の数え方は HANA 1大会＝1回戦で「出た」・決勝通過で「優勝」。
- **一人称・相方の呼び方**：Text(String) は全部 Names.show を通る（Names.swift）。「俺」だけの文字列は自分の札（女＝私）に、「谷口」は相方名に差し替わり、{me}／{partner1} も解決される。山場ページ（TournamentResultView.swift:665〜）・谷口の一言（:498）・前夜イベント・エンディングの会話は全部この経路。StageViews／QualifierNoticeView／CalendarView／RootView に直書きの「俺」「あいつ」は無い。文の途中に直書きされた「俺」は、点検した結果画面・年末・エンディング・S6b・StageScene には無い（話者札の「俺」だけ）。JudgeTalk の「俺」は審査員自身の一人称（相方ではない）。
- **QualifierNoticeView**：HANA1回戦は送り主「THE HANA公式」・表題「動画審査」に差し替わる。通過者一覧のNPC名は中立の名詞（FinalsPresentationView.swift:1406〜）で男名は無い。

## 未確認（今回確かめきれなかった物）
- #2 の fanActive の起動条件／#7 の独白の選び方／#8 の塗りの優先／審査員（JudgeData）が HANA でも男の審査員固定で良いか。
- 相方名を空で始めた女性コンビは相方名が既定の「谷口」のまま（IntroFlow.swift:582 の入力欄の例）。設計どおりだが、女性の名前にしたい場合は別の判断。
