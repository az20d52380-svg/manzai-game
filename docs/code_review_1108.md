# コード点検 1108（662a684a..HEAD の ManzaiGame/Sources 差分）

読むだけ。コードは直していない。対象5ファイル（CalendarView／GameSession／NotebookView／RootView／S6bView）。

## 指摘（3件・どれも低）

### 指摘1：過ぎた週の塗りが「出られなかった大会」でも残る場合がある（低・コードで確認済み）
- 場所：ManzaiGame/Sources/CalendarView.swift:188-194（isTournamentWeek）
- 手順：推薦制中堅賞（知名度30以上・第38週）に、知名度が足りないまま第38週を過ぎる。
- 結果：過ぎた週の判定は `isAgedOut` と HANA だけを特別扱いする。`.fameAtLeast` の大会は `paintsPastWeek` が true を返すので、出ていないのに朱で塗られたまま残る。今回の「出られなかった週は塗らない」の趣旨と揃っていない。長押しの文は categoryLog のラベル（稽古など）になり、塗りと食い違う。
- 備考：これは今回の差分で入った矛盾ではない（以前からの挙動）。今回の変更の延長として揃えるかどうかの判断材料。

### 指摘2：日程表の凡例に「結成の年数で出られなくなった週は塗らない」の説明が無い（低・コードで確認済み）
- 場所：ManzaiGame/Sources/CalendarView.swift:130-150（legend）
- 手順：6年目以降に日程表を開き、若手限定賞（第35週）の週を見る。
- 結果：去年まで朱だった週が稽古などの判子に変わる。凡例は「大会＝朱」のままで理由は出ない。長押しの文は「第35週 稽古。」で正しく出る（isPast 週では categoryLog を読むだけなので破綻しない）。
- 今週が該当する場合：`w >= session.week` の分岐で `spec.isEligible` が使われ、`isAgedOut` と同じ答え（年が `n` を超えたら false）になる。今週も未来週も塗られず、栞だけが出る。表示は矛盾しない。

### 指摘3：年表の ViewThatFits が、収まる行数でもスクロールを選ぶ可能性（低・推測）
- 場所：ManzaiGame/Sources/S6bView.swift:195-198
- 手順：行数が中くらい（8〜10行）で、上下に Spacer と固定の文がある画面（小さい端末・大きい文字）。
- 結果：VStack が ViewThatFits に渡す高さは、Spacer と分け合った後の値になりうる。実際は Spacer を縮めれば収まるのにスクロール版が選ばれることがある。選ばれても全行は見えるので害は小さい。スクロールできることを示す印は無い（「タップで進む」の文のみ）。
- 実機・シミュレータで15行を見た確認はしていない（推測）。

## 問題なしの項目

### 1. 通算優勝の数え方
- 頂GP決勝の行の順序：champion の年は `yearHistory.append`（GameSession.swift:~1412）の後に「頂GP 決勝 優勝」の行を足す（~1436）。`smallWinCount` は append 時点の log を数えるので決勝の行は入らない。入っても `title.contains("頂GP")` で除かれる。数えもれ・数えすぎは無い。
- 夜逃げ・解散の週：`log.append(summarize(...))`（~1409）が `yearHistory.append` より先なので、その週の道中大会の優勝は数に入る。順序は正しい。
- THE HANA：`summarize`（GameSession.swift:1760）は「賞金が出た勝ち＝優勝」。HANA の賞金は決勝だけ（Calendar.swift:79-82）。1回戦から準決勝は「通過」。決勝の「優勝」はタイトルに HANA を含むので `smallWinCount` で除かれ、THE HANA の優勝は `hanaWins` 側で別に数える。二重にならない。
- 敗者復活：WeekRunner.swift:296 で prize は常に 0。通過しても「通過」。頂GPの回戦も prize 0（WeekRunner.swift:281）。決勝だけ gpPrize がつくが、タイトルが「頂GP」なので除かれる。道中に混ざらない。
- 道中大会の賞金は全部 10万以上（Calendar.swift:65-72）なので、`prize/10000` が 0 になって「通過」と書かれる取りこぼしは無い。
- 手帳での二重数え：`kirokuWins`（NotebookView.swift:172）に足す `pastSmallWins` は yearHistory の合計。手帳を開けるのは自由週（WeekMainView.swift:167）で、その時点では今年の行は yearHistory に未登録（年末で追加）。今年分の二重は起きない。旧セーブ（`smallWins` が nil）は過去年の分が 0 扱いで数が少なく出る（仕様どおり・旧データの限界）。
- 小さな不整合（影響なし）：夜逃げ・解散の週の道中大会は smallEntered/smallWon に入らない（weekDone を経ないため）。ただし champion でない年なので、トロフィーt22（champion 条件）には響かない。smallWins（log を数える）には入る。

### 2. 保存の順序
- `smallEntered`／`smallWon` は weekDone の処理（pump 内）で加算され、呼び出し側が pump の後に `saveNow()` する（decideTournament など）。保存値は加算後。
- 年末の `yearDone` では、トロフィー判定の後に 0 へ戻し、同じ呼び出しの saveNow に 0 が載る。
- 復元（init(restoring:)）は pump を呼ばない。phase が `.yearDone` なら finished/winFinale を立てるだけ。同じ年末に pump が再入するとしても、その時点の値は 0 なので t22 が誤って付くことは無い。t17/t18/t22 の award は年末の再入に対して冪等。
- 復元時の `?? 0`：旧セーブは 0 に落ちる。
- SaveDataConventionTests：`smallEntered: Int?`／`smallWon: Int?` はどちらも Optional で、非Optional凍結集合（frozenNonOptional）に触れない。行末コメントの書式もテストのパースに合う。
- `private(set)` を付けただけで、Observation の対象外（@ObservationIgnored）はそのまま。

### 3. 日程表（isAgedOut）
- `isAgedOut` は `.careerYearAtMost(n)` を `year > n` で見る。`isEligible`（Calendar.swift:51）の条件と同じ。HANA・fame 条件は見ないので、年が決まれば変わらない条件だけを扱うという説明どおり。指摘1・2以外に問題なし。

### 4. 年表
- タップ：`.contentShape(Rectangle()).onTapGesture { advance(.wall) }` は外側の VStack にあり、ScrollView の子に独自のタップは無い。タップは親に届く。ドラッグでスクロールした時はタップにならない（意図どおり）。
- 行の縮み：スクロール版は ScrollView の中なので行は縮まない。非スクロール版は ViewThatFits が「理想の高さが収まる」時だけ選ぶので、切れない。
- `MZ_CHAMP_YEARS`：`forceChampion`（RootView.swift:485）は `#if DEBUG`（434-510）の中。リリースには含まれない。ループ内の `startNextYear` は `careerOver` の guard があるが、15年以内なら進む。
