# トロフィー・図鑑・周回メタの解除/記録条件の点検（11/15・読むだけ）

要点
1. 新規 7件（中1・低6）＋既知の再掲。落ちる・消える類はなし。最も重いのは **t12「夜行バスの常連」が東京開催の大会の「出場する」でも数えられる**（中・1pt が早く取れすぎる）。
2. 判定が呼ばれない穴は「夜逃げ／解散になった週の大会結果」と「GP決勝を優勝した週」の2つ（どちらも低）。夜逃げ・解散で、決勝に立っていないのに t17「決勝の照明」（2pt）が付く経路が1つある（低）。
3. 周回の点の式と、画面（周の始めの帯）の数は一致。食い違いは「帯に相性の上乗せが出ない」「点が小さい時も『伸びしろが少し上がる』と出る」の表示2点（低）。保存は UserDefaults だけで iCloud 合流なし（ガチャだけ iCloud）。

節構成：§1 新規の指摘（#1〜#7）／§2 既知・既出／§3 確認済み（問題なし）

対象：ManzaiGame/Sources/Meta.swift（TrophyBook／MetaBook）・Endings.swift（EndingBook:183〜）・GameSession.swift（pump:1381〜／decideTournament:362／行動:396）・StageViews.swift:163〜・GameCore WeekRunner.swift。

## §1 新規の指摘

### #1 【中】t12「夜行バスの常連」が東京開催の大会でも数えられる
- 場所：StageViews.swift:225（東京開催の「出場する」が `decideTournament(.夜行バス)` を渡す）→ GameSession.swift:367（`travel == .夜行バス` で `bump("bus")`）。
- 起きること：若手限定賞・推薦制中堅賞・寒梅漫才杯（東京開催＝`osaka:false`、交通費なし）と THE HANA の各回戦で「出場する」を押すたびに「夜行バス遠征」が1回増える。3年目ごろに10回に届き、一度も夜行バスに乗らずに t12 が付く。表示条件は「夜行バスで遠征を10回する」。大阪開催（春新人賞A/B・夏中堅賞・大阪戎）は正しく数える（新幹線を選べば数えない）。
- 直し方の案：①bump の条件を「大阪開催の大会で夜行バスを選んだ時」に絞る（session 側で `phase` の spec.osaka を見る／GameCore は不変）。②東京開催の出場ボタンが渡す値を別の印（例：nil 以外で交通なし）にする＝GameCore の `Travel` に手を入れるので不採用寄り。推奨①。なお、すでに付いてしまった人の t12 は取り消さない（取り消し機構なし）。
- 付記：t12・t13 のカウンタは周回をまたぐ通算（条件文に「通算」なし・docs/trophy_design_v1.md は「通算10回」）。表示は取った後にしか読めないので実害なし（低）。

### #2 【低】夜逃げ／解散で終わる年に、決勝に立っていなくても t17 が付くことがある
- 場所：Meta.swift:onYearEnd（`outcome.reachedFinal || outcome.champion`）／WeekRunner.swift:462-468（週末の夜逃げ・解散で `reachedFinal: finalist`）。
- 起きること：GP準決勝（または敗者復活）を通って `finalist = true` になった週の週末に、生活費で所持金が bankruptLine を割る（夜逃げ）かすれ違いで解散すると、決勝の週に進まないまま年が閉じる。それでも `reachedFinal=true` なので t17「GP決勝の舞台に初めて立つ」（2pt）が付き、`YearRecord.reachedFinal` も true になる（年表・エンディング判定 #5/#6 の分岐にも効く）。
- 直し方の案：①`onYearEnd` の t17 を `!(bankrupt||dissolved)` かつ決勝の結果が出た年（`didWatch`でなく runner の `finalTried`）に絞る ②今のまま（準決勝を通った＝決勝進出の扱いと割り切る）。確率は低い。推奨①（GameCore に触れない形で `outcome` と log から判定）。

### #3 【低】夜逃げ・解散になった週の大会結果が TrophyBook に渡らない
- 場所：GameSession.swift:1385-1388（onStage は `.weekDone` の results だけ）／1420 以降の yearDone 分岐（夜逃げ・解散の週の結果は log と賞金だけ足し、TrophyBook は呼ばない）／WeekRunner.swift:461-470。
- 起きること：大会に優勝（通過）した同じ週の週末で夜逃げ・解散すると、その大会のトロフィー（t01〜t11・t21 と HANA 優勝の記録）が付かない。smallWon にも入らない（t22 は優勝年のみなので影響なし）。夜逃げ直前の勝利は「所持金マイナスで回戦を通る」(t16) の典型場面でもある。
- 直し方の案：yearDone 分岐の `if outcome.bankrupt || outcome.dissolved` の中で、`rs.filter(\.isStage)` に onStage を呼ぶ（GameCore 不変）。実害は小さい。

### #4 【低】GP決勝を優勝した週は onStage が呼ばれない
- 場所：WeekRunner.swift:309-318（優勝は週の結果を返さず即 `.yearDone`）／GameSession.swift:1449-1458。
- 起きること：決勝を優勝した週は t14（相性が上限）と、決勝での t15/t16 の判定が走らない。t14 は他の大会週で付くので実害は小さく、t15/t16 は「回戦を通る」＝決勝は対象外とも読める。**決勝を負けた時は weekDone を経て判定される**ので、優勝と敗退で扱いが違う。
- 直し方の案：①今のまま（条件文は「回戦」）②yearDone の優勝分岐で `runner.snapshot().weekResults` の GP決勝に onStage を呼ぶ（t15/t16 を決勝にも効かせる＝条件文の変更が要る）。推奨①。

### #5 【低】t15・t16 は週末処理の後の状態で判定される
- 場所：Meta.swift:onStage（`state` は `summary.state`＝週末処理後）／GameEngine の applyWeekEnd（生活費の引き落とし・所持金マイナスなら体力減）。
- 起きること：GP回戦（賞金0）を通った週に、通した時点の所持金は +3万でも、週末の生活費で −2万になれば t16「所持金がマイナスのまま回戦を通る」が付く。逆に、大会で賞金が入って週末後にプラスなら付かない。t15 も、所持金マイナスの週末の体力減（debtLifeStamina）を含めた体力で見る。
- 直し方の案：①今のまま（週末後の状態＝その週の終わりに赤字・疲労）②大会を終えた直後の状態を使う（WeekRunner が state を持つ＝GameCore に触れるため重い）。推奨①＋条件文を「その週の終わりに」を足す程度。

### #6 【低】t14（相性が上限）は大会の週にしか判定されない
- 場所：Meta.swift:onStage の最終行。
- 起きること：相性が上限（20）に達しても、次に大会の結果が出る週まで付かない。最終年の最後の大会以降（決勝の優勝週＝#4 含む）に上限へ着くと取り逃す。大会は毎年あるので実害は小さい。
- 直し方の案：onYearEnd でも `state.compat >= compatCap` を見る（引数に state を足す）。軽微。

### #7 【低】二重に数える窓：結果を数えた後・保存の前に落ちた時
- 場所：GameSession.swift:decideTournament（367 → 368 pump → 372 saveNow）・行動（396）・pump 内の recordChampion。
- 起きること：pump の中で `bump`（夜行バス・稽古）・`recordChampion`（通算優勝・連覇）が UserDefaults に書かれた後、saveNow の前にアプリが落ちると、再開は前の保存（行動の前）から同じ週をやり直す＝乱数は復元されるので同じ結果になり、通算優勝・稽古回数・夜行バス回数が1つ余分に数えられる。窓は数ミリ秒で、トロフィー本体（award）は冪等なので誤解除なし。didRecordChampion は保存しないが、復元は pump を走らせないので今の経路では二重にならない（既知 230・231・save_restore_audit_1115 で既出）。
- 直し方の案：据え置き（実害が通算優勝回数の +1 だけ）。

### #8 【低・表示】周の始めの帯と実際の上乗せの食い違い
- 場所：Meta.swift:bannerLines／GameState.swift:118-140。
- 起きること：①経験点・所持金は式が同じで一致（所持金は 3万/点・100万で頭打ち＝点34以上は帯も 100万）。②実際は相性の上乗せ（最大 +14）も入るが帯に出ない。③「年ごとの伸びしろの上限も、少し上がっています」は点が小さい時に実質0（`36·(P/38)^8`：P=10 で約 0.0002）なのに、点が1以上なら必ず出る。
- 直し方の案：①今のまま ②③の文を点が大きい時（例：P≥30）だけに絞る／相性の行を足す。表示だけ。

### #9 【低・判断】周回メタは端末内だけで iCloud に載らない
- 場所：GameSession.store = UserDefaults.standard（GameSession.swift:1307）。iCloud（NSUbiquitousKeyValueStore）は Store/GachaStore.swift だけ。
- 起きること：機種変更・再インストールで、トロフィー・図鑑・通算記録・周回の点が消える（ガチャの持ち物は残る）。iCloud 合流のコードは周回メタには無いので、合流ロジックの点検対象はなし。1件の型違いで全部消える点は既知 154。
- 直し方の案：①今のまま ②ガチャと同じ型で iCloud に載せる（和集合で合流：トロフィーは集合、図鑑は count 大・日付古い方、通算は最大）。オーナー判断。

## §2 既知・既出（新規に数えない）

- 周回の点の最大36と基準38のずれ（t19 が取れず −2pt・Meta.swift:3,206／GameConfig metaTopPoints）＝キュー147。t19 は `obtainable=false` で画面の分母は21（22個のうち）。
- t18「十年選手」の名前と15年の不一致（Meta.swift:41,62,153）＝キュー172。条件判定自体（優勝なし・夜逃げでも解散でもない・最終年）は正しい（§3）。
- meta の読み込みで1件の型違いにより全部消える（EndingBook／CareerRecords のデコード）＝キュー154・save_compat_audit_1108 §表。
- 最後の年末でエンディングへ進む前に落ちると図鑑が記録されない（EndingFlowView の onAppear で記録／saveNow が finished && careerOver でセーブを消す）＝キュー117（夜逃げ・解散の年末も同じ経路）。
- didRecordChampion を保存しない件＝キュー230・231（save_restore_audit_1115 に「今の経路では起きない」と既出）。
- 周回メタのキーは未知 ID を捨てるだけ・配列が壊れていれば空（save_compat_audit_1108）＝既出。

## §3 確認済み（問題なし）

- t01〜t04（GP1回戦〜準々決勝）：名前は gpRoundNames と一致（Calendar.swift:88）。`passed` の時だけ付与。問題なし。
- t05「準決勝に初めて出る」：通過・敗退どちらでも付与（文のとおり）。問題なし。
- t06〜t11（春新人賞A/B・夏中堅賞・戎・若手限定賞・推薦制中堅賞）：大会名が Calendar.swift:65-70 と一致。条件（若手＝5年目まで・推薦制＝知名度30）も到達可能。問題なし。
- t13「稽古を100回」：`runner.lastTrainingDone != nil` の時だけ数える（体力ゲートで休みに替わった週は数えない）。問題なし（通算カウンタ。#1 付記）。
- t17：決勝を優勝・敗退・敗者復活経由のどれでも付与（#2 の夜逃げ経路を除く）。問題なし。
- t18：`year >= careerYears`（15）・優勝なし・同キャリアで優勝済みでない（yearHistory は当年を足す前に見る）・夜逃げ／解散でない。条件の文と判定は一致（名前だけ既知 172）。勇退した場合は優勝年が必ず終点なので重ならない。問題なし。
- t20「玉座奪還」：`streak == 1`（前年は優勝でない）かつ以前に優勝あり。yearHistory に当年を足した後で判定。優勝して続ける→負け→また優勝で取れる。問題なし。
- t21：「敗者復活」を通った時に付与。問題なし。
- t22「六冠の年」：smallTournamentCount が GP・敗者復活を除き、HANA は1回戦で出た・決勝で優勝と数える。出た大会が5以上かつ全部優勝＋GP優勝。年が替わる/yearDone で 0 に戻す。見送りは数えない（条件文どおり）。出られる大会は最大7（春A・B・夏・戎・若手・推薦・寒梅）で、見送りで5以上に絞れる＝到達可能。問題なし。
- t19：どの経路でも解除不能（解散危機の和解の仕組みなし）＝仕様で `obtainable=false`・画面の分母から除外（既知147の一部）。他に届かないトロフィーはなし。
- 二重に数える：award は集合への insert の初回だけ true（冪等）。yearDone の再入（"pump が同じ年末に再入"）でも t17/t18/t22 は冪等・recordChampion は didRecordChampion で1回。復元は pump を走らせない。取り消せない誤解除は #2 の1経路だけ。
- 中断セーブからの復元：smallEntered/smallWon は保存・復元される（GameSession.swift:336-337）。weekDone で結果が空の時は begin→pump で次へ（二重に onStage しない）。復元後に年末へ入る経路（yearDone を保存）は記録済みの状態から出し直すだけ。問題なし。
- 勇退（優勝後）：recordChampion・t20・t22 は年末の pump で済んでから勇退選択に進む。問題なし。
- 解散（設定からのやめる）：abandonRun はセーブを消すだけ・トロフィーは付いた分が残り図鑑には入れない（オーナー決定10/20）。問題なし。
- 周回の点：`TrophyBook.points + EndingBook.load().count`。EndingID は8個・全て到達可能で最大8。経験点・所持金の式は GameState.init と preview が同じ（metaStartExpSplit の合計＝1.0）。新周回の GameSession は図鑑記録（エンディングの onAppear）の後に作られる（returnToTitle→ 開始時の GameSession(seed:…)）＝直前の周の分が次の周に乗る。問題なし。
- 通算記録：recordChampion は優勝年の年末に1回（最多連覇は yearHistory の末尾から数える・最速は min）。THE HANA 優勝は "HANA決勝" の通過で1回。問題なし。
- DEBUG のみ：MZ_TROPHIES／MZ_META 指定時、`award` が load()（フック値）を元に保存する＝リリースには入らない。問題なし（目視用）。

## 追記（11/15 定期・親）
- #1 は既出＝decision_brief_2026-11-08 の C-16（候補 `night-bus-trophy`）。判断待ちのまま。
- #3 を直した（GameSession.pump の yearDone・夜逃げ／解散の週の大会結果を TrophyBook.onStage に渡す・年末の再入は既存の guard で1回だけ）。GameCore 472／アプリ 420 green。
- #2・#4〜#9 は低・判断の材料として残す。
