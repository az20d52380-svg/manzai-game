# 大会の結果画面の点検（11/15・読むだけ・コードは直していない）

- 要点1：実害のある穴は1件（中〜高）。GP の回戦・準決勝・敗者復活の結果画面の「知名度 ↑+n」が、その回戦の増分ではなく**前に出た道中大会の増分（または0）**のまま出る。
- 要点2：ほかは低が3件（講評の文が大会の種類を知らない／祝いの画面の長い名前／再開で札が欠ける＝既出）。中断→復元で結果が出ない・二度出る・別の結果が出る経路は見つからなかった。
- 要点3：結果画面は「週の結果の最後の1件」だけを出す作りだが、2件が同じ週に載るのは 敗者復活＋決勝 だけで、その2件は結果画面ではなく決勝演出か優勝演出に回る＝食い違いなし。

## 不具合・懸念

### 1. 【中〜高】GP回戦・準決勝・敗者復活の「知名度 ↑+n」が古い値（または0）
- 場所：GameSession.swift:372（`lastResultFameDelta` を書くのは `decideTournament` だけ）／:982-992（`advanceAuto` は経験点 `recordExpDelta` だけで知名度は書かない）／TournamentResultView.swift:516・:534（表示）
- 起きる手順：道中大会（例：週29 大阪戎コンクール）に出て通過（知名度 +5）→ 週30 の GP1回戦を落とす（または通過する）。結果画面の下段に「知名度 N ↑+5」が出る＝負けたのに知名度が上がったように見える。道中大会に出ていない年は0＝GP通過（回戦ごとに +3・決勝進出は fameFinalist の大きな加点）の増分がまったく出ない。`lastResultFameDelta` は `acknowledgeResult` でも消えないので年をまたいで残る。
- 実際の値：GameCore は回戦通過で `gpRoundFame`(3)、準決勝通過で `fameFinalist`(30×逓減) を足す（WeekRunner.swift:268-271・Calendar.swift:98-102）＝画面の札がこれと一致しない。
- 既出：no（docs と AUTOPILOT に `lastResultFameDelta` の記録なし・ResultExpRow1107Tests は経験点だけで知名度の固定テストなし）
- 直し方の案：`advanceAuto` で `let fameBefore = state.fame` を取り、pump 後に `lastResultFameDelta = state.fame - fameBefore`（`decideTournament` と同じ形・表示専用・golden 不変）。①それだけ ②加えて `acknowledgeResult`／`choose` で 0 に戻し、古い値が次の画面に残らないようにする。推奨は①＋②（②は判断不要）。

### 2. 【低】講評の文が大会の種類を知らない（文と判の語が食い違う）
- 場所：JudgeTalk.swift:591（passChemistryHigh「ネタが追えば決勝」）、:559・:563・:565・:636（「通過の線」「通過水準」＝failNear／failStaminaLow）／JudgeData.swift:15（大会名を渡していない）／TournamentResultView.swift:114
- 起きる手順：(a) 相性18以上で GP準決勝を通過（もう決勝進出）→ 講評「ネタが追えば決勝」。道中大会・THE HANA 決勝で「優勝」の判が出る時も同じ文。(b) 道中大会（判は「敗退」＝入賞しなかっただけ）や HANA で近い負け → 講評「通過の線に指が掛かっていた」。判の語は stampLabel で「優勝／敗退」に合成しているのに、講評は GP の語彙のまま。
- 既出：no
- 直し方の案：①今のまま（講評は審査員の一般論＝許容）②`paperReview` に「決勝進出済み／道中大会」の旗を渡し、その2語（決勝・通過）を含む文だけ除外する（乱数を使わない・golden 不変）。推奨は①（出る確率が低く、害は小さい）。

### 3. 【低】講評の「その時の状態」は週末の状態（体力・メンタル・相性の足切り）
- 場所：TournamentResultView.swift:114（`state: summary.state`）／WeekRunner.swift:262-277（GP 敗退で相性を先に下げた後の state）
- 起きる手順：GP予選で負けて相性が下がる（-0.5〜-0.125）→ 相性が 8 をまたぐと講評の候補が failChemistryLow に切り替わる。体力・メンタルは週末の生活費・療養後の値で選ばれる。数字としては画面に出ないので見た目の食い違いは起きない。
- 既出：no／直し方の案：何もしない（許容）。直すなら本番の瞬間の state を StageResult に載せる必要があり GameCore 変更になる＝割に合わない。

### 4. 【低】回戦突破の祝い（YosePassCelebrationView）でコンビ名・回戦名が長い時
- 場所：Design/YoseMilestoneFX.swift:115・:192-193（`Text(duoName)`／`Text(roundName)` に lineLimit も minimumScaleFactor も無い）。結果画面本体（TournamentResultView.swift:121-123 のコンビ名・看板）は lineLimit(1)＋縮小済み＝問題なし。
- 起きる手順：8文字級のコンビ名で GP を通過して「次へ」→祝いの画面。折り返すだけなら崩れないが、縦の余白が足りるかは未確認（目視していない）。
- 既出：no／直し方の案：`.lineLimit(1).minimumScaleFactor(0.6)` を足す（見た目のみ）。

### 5. 【低】再開で「知名度 ↑+n」札と経験点の行が出ない（既出）
- 場所：GameSession.swift:343（復元しない方針）／TournamentResultView.swift:516・:551
- 既出：yes＝docs/save_restore_audit_1115_v0.md #4（低・直さない方針）。#1 を直した後も、再開時は札が出ない（賞金・判は出る）。

## 問題なし（確かめた所）
- 中断→復元：結果画面で閉じても `pendingResult` は `saveNow` で保存（GameSession.swift:1338）、復元は結果が空なら捨てて次へ進める（:302・:347）。`acknowledgeResult` は `guard pendingResult != nil` で二度押しを防ぐ（:996）。祝い・山場の途中で閉じても、再開は結果画面の最初から出し直すだけで、二重に週が進む・結果が消える経路は無い（softlock_audit_1115 #3／save_restore_audit_1115 に既出の範囲）。
- 同じ週に結果が2つ：道中大会（12,15,27,29,35,38,46）・HANA（32,37,42,44）・GP（30,39,41,43,45,47）の週は重ならない。2件載るのは週47の 敗者復活＋決勝 だけで、敗者復活が通過なら続けて決勝＝ `last` は GP決勝。決勝負けは RootView.swift:422 が FinalsPresentationView、優勝は yearDone 側＝TournamentResultView に2件のものは届かない。
- 点・ライン・順位：画面に出さない設計（点数・基準なし・波形と3段の「あと一歩／届かず／遠い」だけ）。`nearMiss`（TournamentResultView.swift:83）と `missLine`（:91）は同じ境界（-3／-10）で一致。「知名度 N」は `summary.state.fame` の丸めで、増分は #1 以外は一致。
- 賞金：`r.prize/10000` は全大会 10万以上で切り捨てなし（100,000〜2,500,000）。10,000 未満の切り捨ては number_display_audit_1115 に既出。GP回戦・敗者復活の賞金は0で行が出ない＝正しい。
- 経験点：`ExpDisplay.total`／`value` は札と合計が合う作り（AbilityUpView.swift:520）。結果画面で2戦分の合算が要る場面は無い（敗者復活の経験点が決勝の行に混ざらない＝決勝は別画面）。
- 判・一言・語：stampLabel（道中=優勝／敗退・GP回戦=通過／HANA決勝=優勝）、hanko（優勝／突破）、metal（銅／銀）、テロップ（どっと沸いた／missLine／動画審査）は passed と種類に整合。HANA の週は `isHana` を先に見ているので `isMidTournament` と取り違えない（:72-73）。
- 山場：`ClimaxData.pages`（:644-652）は準決敗退と敗者復活敗退だけ。最終年は「来年は」の行を「悔しいね」に差し替え（`session.year >= careerYears`・結果表示中は年が進んでいない＝正しい）。キュー127（毎回同じ文面）は判断待ちの既出。
- 谷口の一言（taniguchiLossLine）：GP1回戦〜準決勝の負けだけ（:338）。敗者復活・決勝・道中・HANA では出ない＝文と種類が合う。名前の差し替えは name_substitution_audit_1115 の方式に従う既出。
- 女性コンビ：HANA の通過は「通過」、決勝の通過は優勝演出（showHanaChamp・賞金 `r.prize`）。種類の分岐は性別に依存しない。
- 最終年：山場以外に年の分岐は無い。「結成N年目　第N週」は縮小付きで10年目の2桁も収まる。
- 長いコンビ名：結果画面本体は lineLimit(1)＋minimumScaleFactor(0.6)（:121-123）。大会名の看板は StageSign が lineLimit(1)＋0.7 まで縮小。祝いの画面だけ #4。
