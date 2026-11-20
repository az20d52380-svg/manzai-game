# WeekRunner.swift / GameEngine.swift 正しさ点検（11/16・読み取りのみ・コード無変更）

## §1 要約
- 11/02 以降の変更は2件（495e23d54：applyNetaRetire が selectedNetaID2 も外す／2f506d9cc：体調ダウン確率を GameEngine.injuryProbability に抽出）。どちらも式・順・乱数消費は不変で、境界の問題は見つからなかった。
- 件数：高0／中0／低1（既知に近い）／要確認3。golden に関わる不具合（乱数消費順・Python 正典との食い違い）は0件。
- 週1/48・年1/15・最終年の年末・0や負・空配列・除算0・セーブ復元を読んで確かめたが、新しい「高・中」は無し。既知の台帳と重なる所が大半。

## §2 指摘

### 2-1 【低・確信度 高（コード）／UI で起こるかは中】決勝で「1本目を未選択」のほうが「弱い1本目＋2本目なし」より有利になる
- GameEngine.swift:272-286（netaScoreBonus）。`selectedNetaID == nil` なら先頭の guard で 0 を返し、2本目ペナルティ（netaSecondPenalty=3）の判定まで届かない。1本目を選ぶと、完成度が低い場合は (polish−50)×係数＋飽きの減点＋2本目なしの −3 が乗るので、選ばないほうが得になる。
- 起きる条件：決勝で selectedNetaID==nil。ただしアプリは ensureStageNetaDefault（GameSession.swift ~837）が nil の時に補う＝通常は起きにくい。持ちネタ0本の人は元々恒等0。
- 直し方の案：仕様として「ネタを持つのに選ばない」を罰するなら guard の前で isFinal 時のペナルティを掛ける。**規律A（正典と同期・golden 再生成）**。ただし golden はネタ個体無し＝selectedNetaID nil で恒等0 を前提にしているので、ペナルティを nil にも掛けると golden が動く。持ちネタが1本以上ある時だけ掛ける案が安全。判断はオーナー。
- 既知との関係：docs/code_review_1116_cands.md:41（goNote の脅し文言とエンジン条件の一致）と近いが、「未選択のほうが得」は新規の見立て。

## §要確認
1. **GameSession.swift:1032 checkSpectatorFinal**：決勝週(47)に敗者復活で負けた直後の自由週も `!isFinalist && !hasRevival`（revivalTried=true で hasRevival=false）になり、観客版決勝が立つ。「決勝にも敗者復活にも出ない人向け」の説明（監査H-01）と文面が違うが、敗者復活に負けた人が決勝を観る流れとして自然かもしれない。意図の確認だけ。
2. **GameSession.swift:789 の誘い「行く」**（applyInviteGo）：所持金−5,000 に残高チェックが無い（WeekRunner.swift/GameEngine.applyInviteGo も無条件）。借金中でも行ける＝所持金が負になる。夜逃げ線との関係は設計次第。UI 側で札を出す条件に所持金があるかは未確認。
3. **WeekRunner.resolveTournament**：travel を選んでも所持金が entryFee(＋大阪の交通費)に足りないと黙って不出場になる（Python と同じ）。UI 側のグレーアウトで防いでいるか未確認。

## §既知（重ねない）
- finalLineOverride が中断復元で失われる：code_review_2026-10-16.md §3（アプリは override 不使用で実害なし）・code_review_1108f_kiritsu_a.md。
- gpStage の丸めで finalist が立たない：code_review_2026-10-25e.md §3（案のみ・オーナー判断）。
- 優勝の週は48週目の生活費を払わない：audit_all_v1.md A-9。優勝時の riftJointWeek 持ち越しは gamecore_boundary_audit_1115_v0.md §3-2。
- 2本目ネタは markNetaUsed の対象外（飽きない）：gamecore_boundary_audit_1115_v0.md の末尾（Python も同じ）。
- 療養の週の tick 減算・誘いの年またぎ・療養の年またぎ・selectedNetaID2 の取り残し（修正済み＝495e23d54）：gamecore_boundary_audit_1115_v0.md §1/§3、code_review_2026-10-19f.md。

## §3 見て問題なしの所
- 体調ダウン確率（Item.swift:77）：最大 (50−0)×0.005=0.25（アイテム・特技は ≤1.0 倍）＝1 超えなし。抽出前と式・掛け順が同じ。risky 判定は体力ゲートで稽古が休みに差し替わった後に評価され、乱数は risky かつ体力<閾値の時だけ1回（Python と同じ条件消費）。recoveryWeeks = injuryRestWeeks−1 は 0 以下でも療養分岐に入らず安全。
- begin()：週が 48 を超えると yearDone を返し続ける。週頭に revivalTried/finalTried/pendingSpec/Offer/Auto を掃除。週48で revivalTried が再び false になり hasRevival が true に戻る（revival=true で負けた年）が、upcomingStages は week 以前を除き、spectator 判定は週47限定＝実害なし。
- 年1の init：growthEndYear までの累計予算ループは year≥1 前提（precondition あり）。年16以降は runner が作られない（startNextYear の careerOver）。
- 敗者復活→決勝：resolveAuto(.revival) 後の proceed が section=.finalWeek で決勝へ続く。決勝週の処理は acted と無関係に走る（runYear と同じ）。
- GP 回戦：gpRounds[gpStage] は pendingAuto==.round に入る前の `gpStage < count` で守られている。エントリー費は初回だけ・払えなければ gpAlive=false（Python 同）。
- add()：予算 remaining が負でも max(0,…)、w はメンタル除外で 0 にならない、体力 0〜100 clamp、知名度 clamp、通貨は add を通らない。
- applyRiftWeekEnd：compatCap>0 の定数割り、year<2 の 99 上限、warn と 100 が同週でも解散は riftWarned 後。
- applyWeekEnd：week % livingInterval(4)。48週は払う。夜逃げは生活費週のみ（Python 同）。
- extraOffers：UInt64 は &+ &* で桁あふれなし、rest が空なら打ち切り、i は min で配列内。
- 大会の経験点（Python tourney_exp の kind と重み：road 0.5／round 1.0／revival・final 2.0）は Swift の weight 引数と一致。
- snapshot/restore：state・rng・section/acted/pending*/weekClosed を網羅。復元しないのは lastTrainingDone（表示専用）だけ。pendingSpec/Offer は config から取り直す（A-4）。
