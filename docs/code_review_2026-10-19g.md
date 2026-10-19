# コード点検 2026-10-19g（StageViews・StageCeremony・ShopView・NotebookView の操作部・CalendarView・AbilityUpView の通読・6回目）

**件数：4件（確度 高 3・中 1）。** 19〜19f と review_today_fixes_1019_v0 に無い物だけ。読み取りだけ・コードは変えていない。
**節構成**：§1 確度 高／§2 確度 中／§3 見たが問題なかった所

## §1 確度 高

1. **新幹線回数券を持っている年、大阪の大会の入口の値札・「体力を使う」の注記が実際と食い違う**
   - 場所：StageViews.swift:208-215（`busTotal`／`trainTotal`）と :172（hintSpec の交通費の文）。実際の引き落とし：WeekRunner.swift:185-190（`shinkansenActive == true` なら交通費0・体力変化0に差し替え）。
   - 手順：お店で「新幹線回数券」（20万円）を買う → 大阪開催の大会週（春新人賞A など）。画面は「夜行バスで出場 ¥12,000・体力を使う」「新幹線で出場 ¥32,000」と出し、所持金が 3.2万円未満だと「残高不足で出られない」で押せない。実際は エントリー費2,000円だけで出られ、バスでも体力は減らない。回数券の効果が画面のどこにも出ず、買った意味が分からない上に、お金が足りない人は出場自体を止められる。
   - 直し案：`entryButton` の値段を `session.state.shinkansenActive == true` なら交通費0として組み、sub の「体力を使う」も外す（hintSpec も同条件で文を替える）。
   - 確度：高

2. **年間香盤が、その年に出られない大会の週も「大会」の朱で塗る（推薦制中堅賞・若手限定賞など）**
   - 場所：CalendarView.swift:168-172 `isTournamentWeek`（`cal.tournament(inWeek:) != nil` だけ）、:93-100。実際の出場判定：WeekRunner.swift の `spec.isEligible(year:state:)`（Calendar.swift:46）。
   - 手順：知名度30未満で年間香盤を開く → 第38週（推薦制中堅賞・`fameAtLeast(30)`）が朱で「大会」と出るが、その週に入口は出ず普通の自由週になる。同様に 6年目以降の第35週（若手限定賞・`careerYearAtMost(5)`）。年が進んでも毎年「出られる大会」と見える。
   - 直し案：`isTournamentWeek` で `spec.isEligible(year: session.year, state: session.state)` も見る（過去週は categoryLog が「大会」なら塗る、で足りる）。
   - 確度：高

3. **ネタ帳「戦績」の「大会出場」だけが今年分で、「優勝」「獲得賞金」は通算＝2年目から数字がちぐはぐ**
   - 場所：NotebookView.swift:184-188。`played` は `session.log`（年が替わると `startNextYear` で空になる：GameSession.swift:994）から数え、`wins` と `total` は `yearHistory` を足して通算。
   - 手順：1年目に大会3回出て優勝1回 → 2年目の第1週にネタ帳「戦績」を開く。「大会出場 0回・優勝 1回」と出る（通算の札なのに、出た回数より優勝が多い）。
   - 直し案：`played` にも `yearHistory` 分を足す（YearRecord に出場数が無いので、`roundsPassed` など既存の値から数えるか、札の名前を「今年の出場」に替えて優勝・賞金の側を分ける）。
   - 確度：高

## §2 確度 中

4. **大会入口・本番前カードが開くたびに、手で選んだ「まだ舞台でやっていない・完成度が低い」ネタを一番完成度の高いネタへ黙って戻す**
   - 場所：StageViews.swift:192, 310（`.onAppear { session.ensureStageNetaDefault() }`）→ GameSession.swift:802-809（`cur!.stageCount == 0 && cur!.polish < best.polish` なら `selectNeta(best.id)`）。
   - 手順：ネタ帳で未披露の新ネタ B（完成度40）を「勝負ネタにする」→ 持ちネタに完成度60のネタ A がある → 大会の入口を開く。B の選択が A に替わる（入口の画面で選び直しても、画面を開き直す＝次の大会・回戦でまた戻る）。19f §7 は「新しく書く／別のネタに替える」で外れる件で、こちらは選択が正しく残っていても入口で上書きされる別経路。
   - 直し案：自動の既定は「選択が nil の時だけ」入れる（`cur == nil` のみ）。「磨いた方に寄せる」を残すなら、手動で選んだ印（フラグ）が立っている時は触らない。
   - 確度：中（意図した既定の可能性あり）

## §3 見たが問題なかった所

- **StageCeremony（StageFrame.swift:272）**：`done` ガードで `finish()` は一回だけ。タップ後の `run()` は最初の sleep 明けで `guard !done`。`duck(0.3)`→`duck(1)` は `finish` で必ず対になる（親は `ceremonyDone` でだけ外す）。
- **ShopView**：値札・「あと¥」は `GameEngine.canMoveRoom`／`canBuy`／`livingCostDue` と同じ式。`buy`／`undo` は `purchases` と `visitStart` の整合が取れている（引っ越し後の起点更新は 19 §1-1 で直済）。範囲外・強制アンラップなし。
- **NotebookView の操作**：改名・型変更・しまう・出すは id 検索。`recallNeta` は枠満杯を session 側でも弾く。`renamingID` が残るだけで害なし。DEBUG の `MZ_TAB` は `#if DEBUG` の中。
- **CalendarView**：`categoryLog` は辞書なので範囲外なし。トーストの消去タイマーはトークンで保護済み（閉じた後は状態を書くだけ）。月ラベルの式（第1週=4月）は正しい。
- **AbilityUpView**：`previewAllocation` と `allocate` は同じ `pourStep` の再生。特技の「覚える」は先に割り振りを確定してから `learnSkill`（見積もり `pv` と確定後の状態が一致）。`confirm()` は先に `taps` を空にしており二度押し対策済み。ヒントの `.task` は閉じた後に `@State` を書くだけ。DEBUG の `MZ_SKILL`／`MZ_TAPS` は `#if DEBUG` の中。
- **TournamentEntryView**：東京開催の `money >= entryFee` は WeekRunner.swift:186 と一致。`OneTimeHint.suppressedForDebug` はリリースでは `false` 固定。

## 直した所（10/19 自走・ビルド OK）
- §1 回数券の年の大阪の入口（ボタン1つ・エントリー費のみ・体力温存）。§2 香盤はこれからの週だけ出場条件で塗る（目視：1年目の推薦制の週が塗られない）。§3 札名を「今年の出場」に。
- §4（手で選んだ未披露ネタが入口で最高完成度に戻る）は作りの判断 → キュー114 にまとめる。
