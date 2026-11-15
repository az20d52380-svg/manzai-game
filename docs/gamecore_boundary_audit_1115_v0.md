# GameCore 週送りの境目 点検（11/15・読み取りのみ・コード無変更）

対象：GameCore/Sources/GameCore の WeekRunner.swift・GameEngine.swift・Career.swift（＋週送りを呼ぶ ManzaiGame/Sources/GameSession.swift の startNextYear・choose・pump）。
照合先：tools/sim_career.py の run_year・rift_weekend・invite_weekend・roll_offer・enter_tournament、tools/gen_golden.py の run_year、tools/balance_sim.py の reset_yearly_items・roll_offer。
既出の調べ先：`git branch -r | grep cand`（候補名）・docs/decision_brief_2026-11-08.md・docs/AUTOPILOT.md・docs/events_app_parity_v0.md。
結論：**乱数の消費順で Python とずれる所は見つからなかった（golden に関わる不具合は0件）**。Swift だけの不具合は軽微3件（高0・中0・低3）。

## §1 Swift だけの不具合（Python は別の動き）

### 1-1 【低】療養の週は「相性凍結／ネタ合わせブースト」の残り週が減らない（sim は減る）
- 場所：ManzaiGame/Sources/GameSession.swift:427-433（tickCompatFreeze／tickNetaBoost／tickPreoccupied は choose() の中だけで呼ぶ）、GameCore/Sources/GameCore/WeekRunner.swift:429-433（週送りの減算 API）。Python：tools/sim_career.py:478（_app_week_event の頭で `_neta_boost -= 1`・自由週は療養の週も通る＝app_free は療養判定より前）、:1093。
- 手順：n年m週の自由週に「書けた一本（0016）」を選ぶ（netaBoostWeeks=2）または相性凍結（0012・3週）を受ける。同じ週の行動でキツいバイトを選び体力<50で体調ダウンが当たる（recoveryWeeks=2）。
- 起きること：アプリは次の2週（療養）で choose() が呼ばれず減算が走らない（runner が freeAction を返さず weekDone まで一気に進む）。ブースト／凍結が療養の2週ぶん長く残り、療養が明けた週に「効く」。sim は療養の週にも減る＝効く週数が少ない。
- 重さ：低（イベントの効き週数が最大2週ぶん長い・勝敗の式には直接関与しない）　確信度：高（コードで確認・実機再現は未）
- Python との一致：食い違い（Python が減らす）。ただし相性凍結（compat_freeze）は Python に減算自体が無い（balance_sim.py:193 は読むだけ）。
- 既出：一部（docs/events_app_parity_v0.md:34「療養中・体調ダウン週に札が出るか＝アプリの扱いが未確認」）。ここで確定：**アプリは療養の週に選択肢イベントが出ない**（freeAction が返らず evaluateChoiceEventFire が走らない）／**sim は療養の週にもイベント抽選（12%）が走る**。減算のずれはこの続き。
- 直し方（判断用）：①sim 側を直す（療養週は `_app_week_event` を呼ばない・run_year の `app_free` に `and _inj==0` 相当）か、②アプリ側で weekDone のたびに3つの tick を呼ぶ。どちらも golden 経路外（EVENTS_APP=False・イベント非発火）。

### 1-2 【低】年の最終週（48週目）末の「飲みの誘い」が、翌年1週目に持ち越されて体力が年初全回復の後に引かれる
- 場所：GameSession.swift:1393（pump で `inviteWaiting = true`）・:1176 startNextYear（inviteWaiting を落とさない）・:618（空いた自由週の頭で札を出す）。WeekRunner.swift:231-233 begin() は `week > config.weeks` で `pendingInvite = nil` の手前で返る（runner 内に残るが次の runner に引き継がれず無害）。Python：sim_career.py:1148 invite_weekend は48週目の末にその場で適用（年初の体力100リセットの前）。
- 手順：n年48週目末に誘いが来る（4%/週）→年末画面→「n+1年目へ」。
- 起きること：誘いは翌年1週目の頭に札として出る。「行く」で体力−10・所持金−5,000が**年初の体力全回復の後**に乗る（sim では年初リセットで消える体力−10が残る）。最終年（15年目）の48週目の誘いは年末総決算に入って捨てられる（札は出ず・効果もなし＝sim は効果を適用する）。
- 重さ：低　確信度：高（読み取り）
- Python との一致：食い違い（適用の時点が違う）。ただし「次週頭に札が出る流れ・確率の一致は未確認」は既出。
- 既出：一部（docs/events_app_parity_v0.md:33 weekendInvite の行・save_restore_audit_1115 #1 は inviteWaiting の非保存の話で別件）。年またぎの持ち越しは新規。
- 直し方（判断用）：何もしない（週末の誘いが年越しで翌年の頭に来るのは自然）か、startNextYear で `inviteWaiting = false`（年を越した誘いは流す）。

### 1-3 【低】ネタをしまう（applyNetaRetire）が2本目のネタ選択（selectedNetaID2）を外さない
- 場所：WeekRunner.swift:487-491（`selectedNetaID` だけ nil にする）・GameEngine.swift:272-276 netaScoreBonus（決勝の2本目の判定は `s.netas` から id を引く）。
- 手順：決勝用に2本目へ選んだネタをしまう→決勝（47週）。
- 起きること：しまった2本目の id が残り、`netas` に無いので「2本目なし」と同じ扱い＝決勝で netaSecondPenalty が引かれる（選び直しの案内が出るかは UI 次第）。呼び戻すと選択が復活する。表示の食い違いはあっても数値は一貫している。
- 重さ：低　確信度：中（UI の経路は未確認）
- Python との一致：Python は2本目を持たない（決勝の2本制は Swift のみ）。
- 既出：近い話は C-17「決勝で1本目に2本目と同じネタを選ぶと2本目が黙って外れる（候補 final-neta-notice-cand）」。しまった場合は別経路で新規。

## §2 問題なしと確かめた主な所

- **乱数の消費順（golden 直結）**：週の中の順番は Swift と Python で一致。大会（perform＝出来ブレ1＋ハマった夜1）→GP回戦→敗者復活→決勝→（行動なしの週のみ）rollOffer（1回＋当たれば2回）→療養判定 or 行動選択→体調ダウン抽選（体力<50・稽古かキツいバイト・短絡評価で Python と同じ引き方）→会計注ぎ（乱数なし）→生活費→解散判定→誘い（別系統の SplitMix64＝本編の乱数を使わない）。sim_career.py:941-1130／gen_golden.py:95-215 と突き合わせて消費の抜け・二重なし。
- **大会と GP の重なり**：データ上、道中の大会（12,15,27,29,35,38,46）・HANA（32,37,42,44）・GP回戦（30,39,41,43,45）・決勝/敗者復活（47）は同じ週に重ならない。重なっても `acted` の優先は Python と同じ（大会が先・出たら GP回戦は飛ばす・決勝週は acted に関係なく走る）。
- **大会と療養**：療養中でも大会に出られ、出た週は療養週数が減らず（acted で free セクションを飛ばす）、出なければ rollOffer を引いてから療養を1減らす。Python と同じ（§3-1）。
- **年またぎの持ち越し／リセット**：年初の WeekRunner.init が体力全回復・成長予算の再計算・resetYearlyItems（itemCounts／shinkansenActive／studioActive＝Python の reset_yearly_items と同じ3つ）・ネタの飽き更新を行う。持ち越し：recoveryWeeks・preoccupiedWeeks・compatFreezeWeeks・netaBoostWeeks（いずれも state に載るので落ちない）・借金・offerWeeks（通算週で窓判定）・riftWarned／rift・hanaYear（`hanaYear == year` で判定するので古い年の段は効かない）。
- **飽き（tiredYears）の二重加算**：`lastUsedTaikaiYear == year-1` の1回判定。Python の `used_y` を pop する形と同じ意味（連続使用なら毎年+1・上限 netaTiredCap・使わなければ据え置き）。startNextYear の再入・復元でも年初の更新は元の保存状態から1回しか走らない。保管庫のネタも同様に進む（Python に保管庫は無い＝golden 非経路）。
- **途中解散のゲージ**：`riftWeekStartCompat` と `riftJointWeek` を週頭に必ずリセット。Python は `_joint` を週末にしか戻さないため、**優勝の年の最後の `_joint=True` が翌年1週目に残る**（Python 側の癖・Swift は正しい側。§3-2）。`year<2` の頭打ち99・riftWarned の記憶も同じ式。
- **最終年（careerYears=15）**：startNextYear は `!careerOver` で止まり16年目の runner は作られない。GP 後半の上乗せ（gpLateBonus）・成長予算（k≤growthEndYear=15）・大会の資格（careerYearAtMost(10)＝11年目以降は新人賞系が消える・仕様）はいずれも未来の年を参照しない。upcomingStages は今年の週だけ。15年目の知らせ類は AUTOPILOT 356／359 で点検済み（既出）。
- **0 や負**：体力0＝体調ダウン確率は (50−0)×0.005＝25%で上限内・体力ゲートが稽古を先に休みへ差し替える・add は 0〜100 に clamp。お金が負＝applyTraining／applyRest／大会エントリー／GPエントリーが `money < cost` で弾く（GP は払えないとその年の挑戦終了＝Python と同じ）。夜逃げ判定は生活費の週だけ（Python と同じ）。ネタ0本＝netaScoreBonus が selectedNetaID なしで恒等0。相性0＝解散ゲージの gain は `(compatCap − compat)/compatCap`（compatCap>0 の定数）で割り算は安全。`remaining / w`（成長予算）の w は演技4能力の重み（メンタルは除外済み）で0にならない。割り算は他に fameOtherCap／allocation の `b/(w×m)`（定数が正）のみ。
- **オファー・札**：rollOffer は Python の roll_offer と同じ消費（1＋当たれば2）。offerRates の最終行 999 で知名度100でも落ちない。extraOffers は本編の乱数を使わない。
- **誘い（pendingInvite）**：begin() 冒頭で必ず nil に戻す（週末の誘いは次の begin で「断る」扱い）。大会週の末にも抽選は走り、行った効果は week-end 解散判定の後（Python と同じ）。お金が足りなくても押せて借金になる件は既出（B-9／候補 money-short-choice-candidate）。
- **二度押し／段違い**：weekClosed と currentPhase() で resolve* の再呼び出しは何もしない（懸念の台帳 L37）。

## §3 両方の仕様（Swift と Python が同じ動き・直すなら規律A＝オーナー判断）

### 3-1 療養が年をまたぐと、年初の体力全回復で療養の意味が消え、療養中でも大会に出られる
- 手順：48週目に体調ダウン（recoveryWeeks=2）→翌年1・2週目は「療養」（行動選択なし・オファーなし・バイト代なし）。ただし体力は年初に100へ全回復し、生活費（4週ごと）は療養中も払う。また療養中の週に大会があれば出場できる（その週は療養週数が減らない）。
- Swift：WeekRunner.swift:80-97（init）・:384-389（療養判定）・:182-205（大会は acted で free を飛ばす）。Python：sim_career.py:907・1048-1051、gen_golden.py:145-147（同じ）。
- 重さ：低　確信度：高　既出：no（「療養」は決定ブリーフ・AUTOPILOT に該当なし）。
- 選択肢：A そのまま（体調ダウンの罰は「療養中の2週ぶんの機会損失」で足りる）／B 年初の体力回復を `max(体力, 療養が残る時は据え置き)` にする／C 療養中は大会に出られない（体を壊した週に舞台に立つのは不自然）。いずれも golden の経路（体調ダウン golden・分岐 golden）を動かすので規律A。

### 3-2 優勝の週の「二人で舞台に立った」印（riftJointWeek／_joint）の扱い
- Swift は begin() で毎週戻す。Python は week-end の rift_weekend でしか戻さず、優勝（47週で即 return）の週の `_joint=True` が次の run_year の1週目に残る（sim_career.py:951・882-883）。勇退せず続ける王者編でのみ実害＝1週目のすれ違い加算が1回抜ける。Swift のほうが正しい側。直すなら Python 側（研究用の道具のみ・golden 影響なし）。重さ：低　既出：no。

### 3-3 決勝の2本目に使ったネタは「飽き」が進まない
- markNetaUsed（WeekRunner.swift:123-127）は `selectedNetaID`（1本目）だけに `lastUsedTaikaiYear` を付ける。2本目（selectedNetaID2）は決勝で演じても飽きない。Python も使ったネタ1本だけ（_neta_use）。仕様として2本目は毎年使い回せる＝ローテの抜け道になりうる。重さ：低（決勝のみ・netaSecondPenalty は完成度のしきい値だけ）　既出：no。直すなら規律A（ネタ補正の式の周辺）。

### 3-4 夜逃げ判定が生活費の週だけ（借金は週の途中でいくらでも深くなる）
- applyWeekEnd は `week % livingInterval == 0` の週にだけ bankruptLine を見る（GameEngine.swift:322-335）。Python も同じ（sim_career.py:1132-1140）。キツいバイト・誘い（−5,000）・有料稽古が借金の週にも通る点は B-9（既出）と同根。重さ：低　既出：近い話は B-9。

### 3-4b 参考：Python の既定オフの「波乱の年」（UPSET_ON）は年初に乱数を2つ引く
- sim_career.py:936-939。Swift に対応する処理は無い。既定 False（golden・実測とも不使用）なので不一致は現れない。もし将来 ON にするなら Swift 側に同じ消費を足す必要がある。既出：no（情報のみ・不具合ではない）。

## 件数
Swift だけの不具合 3（高0／中0／低3）・両方の仕様 4（低4）・確認して問題なしと分けた所は §2。
最も重い1件：1-1（療養の週に相性凍結・ネタ合わせブーストの残りが減らない＋sim だけ療養の週にイベント抽選が走る＝events_app_parity の未確認項目の確定）。
