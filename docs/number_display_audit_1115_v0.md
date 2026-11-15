# 数字表示の不具合 静的点検 v0 / 2026-11-15

読むだけ（コード・シミュレータ非接触）。前回 number_display_audit_1108_v0 の修正（Yen.text の「−¥」・Yen.man の 99,999→10万・compactYen）は反映済みを確認。ここでは残りを拾う。
範囲の根拠：GameConfig 既定＝weeks 48 / careerYears 15 / livingCost 140,000 / 賞金は全て 10,000 の倍数（最小 100,000）/ jobs・offers の income は 32,000 以上。

## §1 指摘（3件・いずれも重さ「低〜中」。画面で確実に壊れる「+0」「第0週」は見つからず）

### 1. 相性チップとカードの丸め方が違い、同じ増分が「+1」と「出ない」に揺れる（中・確信度 中）
- 場所：WeekMainView.swift:1333（週明けの獲得チップ `Int(session.lastCompatGain.rounded())`）と :1565（行動カードの予告 `Int(after.compat.rounded()) - Int(s.compat.rounded())`）。
- 手順：相性が 4.7 → 5.3（増分 0.6）になる行動。チップは 0.6→「相性 +1」。カードの予告は 5−5＝0 で何も出ない（逆に 4.4→5.1 だとカード「+1」・チップ「+1」と一致、4.4→4.9 だとチップ「+1」・カード無し）。0.5 刻みの増分が揺れる典型。
- 画面の例：「相性 +1」が出たのに、相性の整数表示（5→5 など）は動かない／押す前のカードに出ていない。
- 直し方：チップも「前後それぞれ丸めて引く」に揃える（体力 :1068・年末 YearResultView:320 が既にその方式）。before の compat を週頭に保持して `Int(after.rounded()) - Int(before.rounded())`。

### 2. 知名度の「+N」が増分の丸め、バー表示は値の丸め（低・確信度 中）
- 場所：WeekMainView.swift:1345-1346（チップ）・:1569-1570（カード）は `Int(fd.rounded())`（増分を丸める）。一方バー（:1401, StageViews:198）は `Int(fame.rounded())`（値を丸める）。
- 手順：知名度の「その他の伸び」は ×0.6×(1−知名度/80)² がかかる（GameConfig fameOtherMult/Cap）＝端数になる。オファー fame:1 は序盤で約 0.54 → チップ「知名度 +1」。3.54→4.08 だとバーは 4→4 で動かない。逆に 0.4 の伸びはチップ無しでバーが 3→4 になる。
- 画面の例：「知名度 +1」と出たのにバーの数字が変わらない。
- 直し方：#1 と同じく前後を丸めて引く（週頭の fame を保持）。0 は今まで通り出さない。

### 3. 生活費の画面で所持金が負に近づく途中、「−0」が出うる（低・確信度 低）
- 場所：RentStatement.swift:87 `(money < 0 ? "−" : "") + RentStatement.yen(Int(money))`。money は数え上げ用の Double（.numericText 補間）。
- 手順：所持金が 0 を跨ぐ支払い（例：残 30,000 で生活費 140,000）。補間の途中で money が (−1, 0) になった一瞬、`money<0` は真・`Int(money)` は 0 →「−0」。1コマ程度で、実機で見えるかは未確認。
- 直し方：`let n = Int(money.rounded())` を先に出し、`n < 0` で符号を決める。

## §1b 既定値では出ないが、設定を変えると出る潜在（件数に含めない・低）
- Yen.man（Theme.swift:462）：v<500 は「0万」、10,400 は「1万」（400 が消える）、10,500 は 1.05→「1.1万」（四捨五入が +0.05 ずれる）。呼び出し元：WeekMainView:904（`+` + man の仕事札）・:1498・WeekHint:44/48/51・NotebookView:213・StageViews:187（>0 で守ってある）。既定の金額は全て 10,000 以上の 1,000 倍数なので出ない。1万未満を整数円で逃がす分岐は costPill（:1375）と :1163 だけにあり、offerPickCard（:904）には無い＝オファーの income を 1万未満に調整すると「+0.4万」「+0万」が出る。直し方：man の中で `v < 10000` は `v.formatted()` を返す。
- 賞金の「万」切り捨て：GameSession:1784（`r.prize / 10000`）・TournamentResultView:526・NotebookView:183 は 10,000 未満の賞金だと「+0万」（:1784 は prize>0 で出すため）。既定は最小 100,000 なので出ない。

## §2 問題なしと確かめた主な所
- 符号の 0 抑止：結果1行（WeekMainView:1274-1278 md/sd≠0・exp>0）、体力チップ（:1349 sd≠0）、所持金の木札（YoseGameParts: onChange で new≠old）、費用ピル（:1124 moneyDelta≠0）、実力札（YoseGameParts:19 delta>0）、知名度↑（:67 >0）、経験点（ExpDisplay.total / value>0 / TournamentResult:553 total>=1）、ネタ +N（:1339 pd>0 or 新ネタ）。「+0」「+-5」「−−」は出ない。
- 二重符号：金額は常に `abs()` を取ってから符号を付ける（YoseGameParts:75/97・WeekMainView:1163/1376・Yen.text・compactYen・RentStatement）。
- 経験点の丸め：ExpDisplay.total は札の和と必ず合う設計（切り捨てで揃え、全部 0 の時だけ内部合計）。コストは切り上げで「持ち分より多く要求」しない。
- 体力：チップ・カード・バーとも前後を丸めて引く方式で整合（lastStaminaDelta は :417）。休養の回復量だけ別式（:1074）だが満タン時の予告の意図的な例外。
- 週：session.week は復元時 min(week, weeks)（GameSession:282）で 49 を出さない。年末は summary.week（48）。CalendarView は 1…4 列×12 行で 第0週 なし。週スタンプ（:447）は weekStampVisible の時だけ（:329）。
- 年：careerYears=15 で startNextYear は careerOver ガード（GameSession:1171）＝「16年目」は幕間にも結果にも出ない。Endings の「十六年目の一月」は物語上の文（数字表示ではない）。YoseYearTurnCurtain.kanjiNumber は 1〜19 を正しく変換、20 以上は桁ごとの置換（二〇）になるが 15 年設定では未到達。
- 回数：「今年の出場 N回」「優勝 N回」は 0 が正しく 0 と出る（0回目のような序数は無い）。「ネタ 舞台 N回」は stageCount そのまま。
- 借金の符号は 前回(1108)の修正で Yen.text と compactYen は「−¥」。YoseVitalMoneyBar は ASCII「-¥」。
- 賞金・生活費の合計：RentStatement.breakdown は端数を最後の行で吸収＝行の和が合計に一致。NotebookView の獲得賞金（entries の万＋年履歴/10000）は賞金が 10,000 の倍数なので和が合う。
- 1万未満の混在回避：:1163 と costPill は 10,000 未満を整数円で出す（¥0.5万／¥0.0万を出さない）。賞金の無い段は `prize>0` でガード（StageViews:187）。

## §3 表記の流儀の参考（money-format-cand と重なる・判断待ち。間違いではない）
- 負号の字：画面ごとに「−」（U+2212）と「-」（ASCII）が混在。Yen.text・compactYen・RentStatement・結果1行（:1270）＝「−」。YoseVitalMoneyBar（:75）・所持金の木札（:97）・費用ピル（:1376）・:1163・体力ピル「体力 -20」（:1386 は `\(delta)` の ASCII 負号）＝「-」。
- 符号の位置：「−¥912,000」（Yen.text）に対し「-¥100,000」（バー）。どちらも円記号の前で位置は揃っている（「¥-」は無い）。
- 単位の流儀が3つ：「¥6.4万」（ピル）・「+6.4万」（offerPickCard :904、円記号なし）・「14万円」（WeekHint・用語集 :1498）・「+25万」（賞金 :239/526 は万のみ）。RentStatement は ¥ なし「140,000」、所持金行だけ「−」付き。
- 万の閾値：10,000 以上は万（小数1桁）、未満は整数円（ピル）。Yen.man 単体は閾値なし（§1b）。1.2万／12,000 の境目は「ピル系は 1.2万、バー・木札・生活費画面は 12,000」で場所ごとに違う（バーは常に全桁）。
- 直し案（候補ブランチと合わせる前提）：Yen に `signed(_:)`（U+2212 固定）を1つ足して、バー・木札・ピル・結果行から使う。Yen.man の1万未満ガード（§1b）を同時に入れる。
