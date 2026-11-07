# コード点検 1107g：startNextYear のリセットと通算表示（読み取りのみ・コード未変更）

対象：ManzaiGame/Sources/GameSession.swift ほか。最長15年（config.careerYears=15）。
確かさ＝「確認済み」はコードを読んで手順を追えた物。「推測」は実行していない物。

## §0 結論
- 新しく見つけた不具合：2件（中1・低1）＋注意1件（低）。通算が年明けに減る同種の不具合は、手帳の優勝・賞金以外には見つからなかった。
- 一番重い物：#1 中断→再開で「六冠の年」トロフィー(t22)の判定が狂う（確認済み・中）。

## §1 startNextYear（GameSession.swift:1159-1200）でリセットされる値と、読んでいる画面
| 値 | 読む画面 | 通算/今年の整合 |
|---|---|---|
| log（:1170） | NotebookView.logEntries(:160)・kirokuPage(:179)、YearResultView 出来事(:280,:304,:391) | 手帳は yearHistory（優勝・賞金・smallWins）で補っている＝OK。年末画面は「今年」として使う＝OK |
| categoryLog（:1171） | CalendarView(:103,:118,:186)、YearResultView 色帯(:240) | 今年の週ごとの内訳。文言も今年＝OK |
| totalPrize（:1172） | CalendarView:47「今年の賞金」、YearResultView:319「今年の賞金」 | 文言どおり今年＝OK |
| didWatchFinal / watchingFinal / lastFinalMargin / didRecordChampion | 年ごと（yearHistory.watchedFinal に写してから消す :1416） | OK |
| lastAction 系（lastGains…lastFameDelta） | 直前の行動への反応だけ | OK |
| stablePicks | 同じ key の再描画用 | usedPicks（通算）は消さない＝意図どおり |
| pendingChoiceEvent / choiceApplied / lastEventRollWeek / lastBanterRollWeek | 週ガード | OK |

リセットされず持ち越す物（意図どおり）：lossStreak、inviteWaiting、weeksWithoutPartner、debtWarnTier、didShowRiftHint、usedPicks、usedFanLines、shownOnce、firedWeeklyEvents、weeklyEventFiredCount、jobCount、yearHistory。

## §2 指摘

### #1 中断して再開すると「六冠の年」(t22) の数え直しで判定が狂う
- 場所：GameSession.swift:189-190（smallEntered/smallWon は @ObservationIgnored で SaveData に無い）、:1361（加算）、:1393-1396（年末判定とリセット）、Meta.swift:193（`smallEntered >= 5, smallWon == smallEntered`）、復元 :328 付近（復元しない）。
- 手順：ある年の道中大会で何件か出る→アプリを閉じる／中断→再開→残りの大会に出て優勝年にする。
- 結果：再開前の出場・優勝が0に戻る。
  - 偽陰性：再開前に3件勝ち、後で2件勝って六冠（5/5）でも entered=2 になり t22 が付かない。
  - 偽陽性：再開前に負けがあった年でも、再開後の5件が全勝なら smallWon==smallEntered で t22 が付く。
- 重さ：中（トロフィー＝周回の点 MetaBook.points に直結。年に1度の稀な条件なので頻度は低い）。確かさ：コードで確認済み（SaveData に項目が無いことを grep で確認）。
- 直し方の案：年末に log から数え直す（log は保存される。出た数＝優勝/通過/敗退の道中大会の件数。HANA は決勝通過＝優勝の規則を smallTournamentCount と揃える）か、SaveData に Optional で2値を足す。

### #2 手帳の通算（優勝・賞金）が、年末画面から翌年の開始までの間だけ二重になりうる
- 場所：NotebookView.swift:179-183（kirokuWins と total）。yearHistory.append は pump の yearDone（GameSession.swift:1409）で行い、log のリセットは startNextYear（:1170）。その間は「今年」が log と yearHistory の両方に入る＝頂GP優勝(:171-175 gpChampionYears と thisYear)・道中優勝(pastSmallWins と thisYear)・賞金(entries.prize と yearHistory.prize/10000)が重なる。
- 起きる手順：yearDone の状態で手帳を開く。手帳は WeekMainView:1395 のフッターからしか開けない。年末は YearResultView なので、通常の操作では届かない。
- 結果：届いたとすれば優勝数が1多く出る。
- 重さ：低。確かさ：推測（二重になる式はコードで確認済み、届く経路は見つからなかった＝RootView の遷移を全部は追っていない）。
- 補足：もし将来、年末画面から手帳を開く入口を足すなら、今年分を yearHistory.last(year==session.year) で除く必要がある。

### #3 旧セーブ（smallWins なし）は、年明けに道中大会の優勝が通算から消える
- 場所：GameSession.swift:1244 付近の YearRecord.smallWins（nil＝0 扱い）、NotebookView.swift:182。
- 手順：smallWins が入る前のバージョンで2年目以降まで進めたセーブを、今のバージョンで開く。
- 結果：過去の年の道中大会の優勝が通算に入らない（今年の分は出る）。新規の遊びでは起きない。
- 重さ：低。確かさ：コードで確認済み（過去の記録は復元不能）。

## §3 問題なしと確かめた項目
- 手帳「優勝」：今年分＋yearHistory の頂GP優勝＋道中の smallWins＋HANA（state.hanaWins から今年分を引く）。年明けに減らない（今日の直しで解消済み）。HANA は state が保存されるので再開でも保たれる。
- 手帳「獲得賞金」：yearHistory.prize を /10000 で万にして log の「+N万」と足す。単位は揃っている。10年以上の5桁は minimumScaleFactor(0.6) で1行に収まる。
- 手帳「今年の出場」：名前が「今年」で、数えるのも今年の log。文言と中身が合う。
- 「今年の賞金」（CalendarView:47、YearResultView:319）：totalPrize は今年分で文言どおり。
- 文言が「通算/これまで/合計/累計/キャリア」の表示：EndingViews.swift:341「通算優勝」は CareerRecords（UserDefaults の周回をまたぐ記録）で、文言どおり。YearResultView:159「これまでの頂グランプリ」と手帳の同見出しは yearHistory 全年で合っている。「今年」と書いて通算を数えている表示は見つからなかった。
- didRecordChampion（保存されない）：復元は yearDone を再 pump しない（init(restoring) は pump を呼ばず phase を書き戻すだけ）ので、再開で recordChampion が二重に積まれることはない。次の年は startNextYear で false に戻る。
- 長いキャリアの表示：yearHistory の一覧は YearResultView/手帳（ScrollView 内）では最大15行で縦に伸びるだけ。S6bView の年表は 15年分を ViewThatFits＋ScrollView で対応済み（:195-197）。年・週で配列を直接引く箇所（`[year]` 系）は GameSession と GameCore の grep で見つからず、範囲外アクセスは無い。YearResultView の名前引き（gpRoundNames[r.roundsPassed]）は count との比較で守られている（reachLabel）。
- usedFanLines は600件で打ち止め(:  fanVoices)。usedPicks は場面ごとに count で絞る。shownOnce は年ごとの鍵で最大15件。いずれも増え続けて壊れる心配なし。
- ネタ：持ちネタは netaActiveSlots の上限があり、しまったネタ（archivedNetas）は上限なしだが ForEach を ScrollView に並べるだけ。数十件でも崩れない（件数の上限は確認していない＝見た目は推測）。
- 保存される値（log / categoryLog / totalPrize / yearHistory / didWatchFinal / usedPicks 等）は SaveData に入っており、再開で数え直しにならない。数え直しになるのは #1 の smallEntered/smallWon だけ（その他の @ObservationIgnored は表示用キャッシュ・年内の再描画ガードで、結果に影響しない）。
- 注：inviteWaiting（先輩の誘いの待ち）も保存されないが、軽い誘いが1回流れるだけで通算・トロフィーには無関係（コメントで許容と明記）。
