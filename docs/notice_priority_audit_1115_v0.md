# 週の画面の「知らせ」の優先順位と取りこぼしの点検（11/15・読むだけ・コードは変更なし）

対象：ManzaiGame/Sources/WeekMainView.swift（以下 W）・GameSession.swift（以下 G）・StageViews.swift・RootView.swift。
既出の照合：stale_timer_audit_1115・onappear_audit_1115・softlock_audit_1115・save_restore_audit_1115・gamecore_boundary_audit_1115・stamina_audit_1115・money_audit_1115・code_review_2026-10-19b・AUTOPILOT 361/446/451 を grep。

## 要点
1. 新規 8件（中 2・低 6）＋既出の確認 6件。確定（判定・数値）を誤らせる物は無し（表示と一回きりの知らせの取りこぼしだけ）。
2. 最も重いのは N1：選択肢イベントの確定発火が if-else の一本鎖で、上位が出た週に下位は持ち越されない。予告 0050（riftWarning）と同じ週頭に重なると、負けた後の一言（justLostRehearsal）・通過の分かれ道（justPassedFork）・前夜（preTournamentEve）が二度と出ない（フラグは次の行動で失効・前夜は週ぴったり）。次点 N2：借金などの知らせが「Beat1 の最中（pulledID 立ち・burstHold 未立ち）」に割り込み、週が進む間ずっとモーダルの下で数字とずれる。
3. 構成：§1 知らせの一覧表／§2 指摘（N1〜N8）／§3 既出／§4 問題なし。

## §1 知らせの一覧（出す条件・出した印・優先）
「先に」＝出す前に印を立てる（出せなかったら消える）。

| 知らせ | 出す場所・条件（ガード） | 出した印（いつ） | 優先 |
|---|---|---|---|
| 選択肢イベント | G:595 evaluateChoiceEventFire（週頭・freeAction）→ W:181 cover。出す条件＝pending あり・burstHold 無・pulledID 無（W:1303） | イベントごとに didFire*（G:603〜634 の発火時＝先に）。選ぶ→applyEventChoice／閉じる→dismiss（G:817） | G の else-if 鎖：riftWarning > justLost > styleTalk > passFork > Eve > earlyFormality > tsuuka > nameless > taniguchiJob > 誘い > 週次ランダム |
| 先輩の誘い | 鎖の下位（G:629）。週末 pump で inviteWaiting（G:1407） | inviteWaiting=false を発火時（先に・G:632）。セーブされない | 確定発火の後（19b で既出の仕様） |
| 獲得の一拍（burst） | W:289 .task(id:week)。lastDeltaWeek==week・chips/line あり | burstPlayedKey（先に・W:304）。burstHold は choose 直前に立て、タスク終端で下ろす | イベントより前（burstHold 中はイベントを待たせる） |
| 月末の支払い（rent） | W:1285 presentRent（burst 後・burstHold 中・1週1回） | rentShownKey（先に・W:1289） | burst の後・イベントより前 |
| 体調ダウン | W:1470 maybeShowDebtNotice の先頭。injuryNoticeWeeks>0・pending/showEvent/burstHold/rent/injuryNotice 無・freeAction | clearInjuryNotice（先に・W:1471・保存なし） | 借金・すれ違いより上。大会入口の週は StageViews:236 が代わりに出す |
| すれ違いの一言（rift） | 同関数。riftHintToShow・debtNotice/riftNotice/rent/pending/showEvent/burstHold 無 | markRiftHintShown（先に・保存あり） | 体調ダウンの下・借金の上 |
| 借金の段 | 同関数。debtNoticeTierToShow（深い段が未告知） | markDebtWarned（先に・保存あり） | 最下位。1回の呼び出しで1種だけ |
| 初回の説明（hint） | W:1512 maybeShowFirstHints。hint/rent/debt/rift/toast 無・pending/showEvent/burstHold/pulledID/各 cover 無・year==1 | OneTimeHint.markDone（閉じた時・後） | 他の知らせと重ねない設計（injuryNotice だけ見ていない→N4） |
| 年初の知らせ：若手最後／飽き | W:1527・1542。onAppear 0.7秒後・year 変化。week<=1・各 NoticeYear 未 | markYouthNotice／markTiredNotice（先に・保存あり・451 で session へ） | ガード無し（toast 直出し）。若手最後だけ toast 待ち（446） |
| 器満了トースト | W:1550 onChange(vesselIsFull) | vesselFullToastShown（先に・@State） | ガード無し |
| トースト | showToast（W:1458）。上書き式・消すのは toastSeq の待ち（1.4〜4.5秒） | なし | 無条件で前のを上書き |
| オファーの札 | W:151・376。session.offerChoices／runner の offer。受けるのは二度押し（W:928） | offerArmed（3秒） | 立っているイベントの間は触れない（W:171） |
| 予選の知らせ | RootView の phase 切替（別画面・WeekMainView は作り直し） | 画面内部 | 週メインの知らせとは競合しない（§4） |

## §2 指摘

### N1 【中】確定発火は上位が出た週に下位を持ち越さない（予告 0050 と重なると、負けた後の一言・通過の分かれ道・前夜が消える）
- 場所：G:595〜634（else-if 鎖）・choose の `justPassedStage=false`／`justLostStage=false`（次の行動で失効）・Eve は `m.week - week == 1`（G:614）。
- 手順：週末に riftWarned になる週と、大会の負け（または通過）が同じ週に起きる→次の週頭は riftWarning を立てて終わる（G:602）→選んだ後に行動→justLostStage／justPassedStage が失効→justLostRehearsal／justPassedFork は二度と立たない。前夜は「大会の1週前」ぴったりだけ＝同じ週頭で riftWarning／justLost／styleTalk に取られると、翌週は m.week-week==0 で消える（1週前が自由週になる大会が多い）。
- 起きること：一回きりの演出（谷口の一言・分かれ道・前夜）が重なった年だけ欠ける。判定・数値は変わらない。誘い（inviteWaiting）の持ち越しは 19b で既出だが、確定発火同士の持ち越しは無い（choice_event_inventory_v0.md:6 は優先順位を書くだけ＝新規）。
- 直し方の案（判断が要る）：①持ち越す＝justLost／justPassed の失効を「そのイベントを出した週まで」に延ばす（choose 側の2行・Eve は ±0 週許容）②今のまま（重なる確率が小さい・欠けても害が無い）と明記。

### N2 【中】借金・体調ダウン・すれ違いの知らせが Beat1（引き抜き〜週送り）の最中に割り込み、週が進んでいる間モーダルの下で内容と数字がずれる
- 場所：W:1470・1475（ガードに `pulledID == nil` が無い。firstHints W:1514 だけ持つ）・W:262〜269（burstHold が下りて 0.6 秒後に呼ぶ）・W:1309 tapOrQueue（burst 中の押下を「畳んだ後に実行」で予約）・W:872〜876（beatTask：0.12 秒＋一言 0.7 秒の後に burstHold=true と choose）。
- 手順：支払い等で借金の段が新しく深くなった週。burst/rent が終わる前に行動カードを押して予約する（W:1309）→burstHold が下りた瞬間に予約が走る→perform が pulledID を立て、一言（0.7秒）の間 burstHold は未立ち→0.6 秒後の maybeShowDebtNotice が通る→借金のモーダルが出る→その後ろで choose が走って週が進み、獲得の一拍・支払いはモーダルの下で終わる。
- 起きること：「バイトに専念すれば間に合う」等の文を読んでいる間に、別の行動で週が進んでいる（文は押す前の所持金の段）。印は先に立っているので閉じたら二度と出ない。体調ダウン・すれ違いも同じ。
- 直し方の案：ガードに `pulledID == nil` を足す（firstHints と並べる）。ガードを1つの関数にまとめると N3・N4 も一緒に直る。

### N3 【低】1回の呼び出しで1種だけ出し、閉じても次を呼ばない＝借金の知らせが1週遅れる／優先が逆（すれ違いの一言が借金より先）
- 場所：W:1470〜1500（early return）。再判定の契機は onAppear・burst 終了・イベント終了・週替わり2秒後だけ（W:262〜338）。モーダルの「わかった」（W:214・222・230）は再判定を呼ばない。
- 手順：体調ダウンで倒れて所持金が割れる週→体調ダウンを閉じる→借金の知らせは次の契機（次に行動した後の 0.6 秒）まで出ない。すれ違いの一言が先に出る週は、その後ろに借金が回る。
- 起きること：段の知らせが「週の頭」でなく次の週に出る（内容は出す時の所持金で作るのでずれは小さい）。印は出す時に立てるので消えはしない。
- 直し方の案：各モーダルの閉じる処理で `maybeShowDebtNotice()` を 0.3 秒置きに呼ぶ。優先を直すなら借金を体調ダウンの次に（判断）。

### N4 【低】知らせ同士のガードが非対称＝重なって出る（体調ダウン＋初回の説明・借金＋体調ダウン／説明）
- 場所：W:1512〜1514（firstHints は injuryNotice を見ない）・W:1475（debt は injuryNotice と hint を見ない）・W:1470（injury は debt/rift/hint を見ない）。重なり順は W:212〜246 の記述順（hint が最前面）。
- 手順：1年目の生活費の週（第4週）の頭に体調ダウンの知らせ（0.7 秒）→1.3 秒で生活費の説明も出る。または体調ダウンを閉じる前に週替わり2秒後の借金が通る。
- 起きること：モーダルが2枚重なる。閉じれば順に出る（印は先なので消えはしない）。見た目と読む順の問題。
- 直し方の案：§1 の「出す条件」を共通のガード関数（モーダルの有無・pulledID・各 cover・phase を同じ並びで見る）に集約。

### N5 【低】トーストで出す知らせ（年初2種・器満了）は、印を先に立てたうえで、上書き・cover に隠れて読まれないことがある
- 場所：W:1537・1546・1553・1458（showToast は上書き式）。
- 手順：①飽きの知らせ（年初）の直後 1.4〜4.5 秒のうちに、行動カードの無効タップ（W:925・1009）や別の toast が出る→前の文が消える。印は先に立つので戻らない。②満了トーストは burst・rent の間は出るが、直後のイベント cover（W:181）が出ると下に隠れて時間切れ。
- 既出：②と年初2種が「イベントの下で出て閉じた時には消えている」は AUTOPILOT 361（未決・候補あり＝案②）。①の「無効タップで上書き」は新規（stale_timer #3 は同じ文の測り直しで別件）。
- 直し方の案：361 の案②に含めて、toast を出す前に showEvent/burstHold を待つ。無効タップの toast は知らせ toast を上書きしない（判断）。

### N6 【低】年をまたぐ療養の自動送りで、年初の知らせ2種が条件（week<=1）を外れて、その年は出ない
- 場所：W:1530・1543（`session.week <= 1`）・G:1405〜1417（療養の週は pump が自動で次週へ送る＝freeAction が返るまで WeekMainView は出ない）・gamecore_boundary 3-1（療養は年をまたぐ）。
- 手順：48週に体調ダウン→翌年の1・2週が療養で自動送り→WeekMainView が現れるのは第3週→week<=1 が偽で、飽きの知らせ・「若手最後」の知らせ（その年に当たっていれば）は出ない。印は立たないので翌年にも出ない。
- 起きること：年初の一言が欠ける（判定は不変）。ごく稀（週47〜48で倒れた年のみ）。
- 直し方の案：`week <= 1` を `week <= 3` に緩める（印は年単位なので重ならない）か、今のまま。

### N7 【低】中断復元：知らせを見せている最中に落とすと、印が先に保存されていて二度と出ない（借金・すれ違い・年初）／月末の支払い・獲得の一拍は復元で出ない
- 場所：G:1305（markDebtWarned は saveNow）・G:1313・G:197〜198 は表示前に保存。体調ダウンだけ clearInjuryNotice が保存しない（G:67・save_restore #5 で既出）ので復元で再表示される。lastLivingPaid・lastDeltaWeek はセーブしない（復元側に代入なし＝W:289 の `lastDeltaWeek == week` が偽）。
- 手順：知らせ（借金のモーダル等）が出ている間／月末の支払いの最中にアプリを落とす→再開。
- 起きること：①借金・すれ違い・年初の知らせは読まれないまま済になる（読み返しは hint の「？」だけ・借金は無し）。②支払い画面は出ない（お金は引かれ済み）。③選択肢イベントは保存されて onAppear（W:274）で出る＝問題なし。誘い（inviteWaiting）は保存されず消える（save_restore #1 補足・partner_audit で許容と既出）。
- 直し方の案：モーダルを閉じた時に印を保存する（出す時は仮の印）か、今のまま（落とすのが稀）。判断。

### N8 【低】借金の知らせ「段1」の文が原因を決めつける（「生活費が払えず」）
- 場所：W:1481。段は `money<0` で決まる（G:1296 debtTier）＝参加費・飲みの誘い（gate なし）でも段1になる。
- 手順：生活費の無い週に、お金が足りないまま誘いの「行く」を押して所持金<0（choice_gate_audit #1）→次の週頭に「生活費が払えず、借金になった」。
- 起きること：画面の数字（借金）と原因の文がずれる。近傍の既出：AUTOPILOT 487（借金の次の支払い文言・候補あり・判断待ち）・money_audit。文言は判断。
- 直し方の案：①段1の文を原因を言わない形に（「借金になった」）②今のまま。

## §3 既出（新規に数えない）
- 年初の知らせ・「今年の実力の伸びはここまで」がイベントの下で出る：AUTOPILOT 361（案②・判断待ち）。
- 年初の知らせが覆いの往復・再開で二度出る：onappear #4／AUTOPILOT 451 で済。
- 若手最後の知らせが前のトーストを上書き：stale_timer #4／446 で済。
- 獲得の一拍・週めくり札が cover 往復で二度出る：onappear #1・#2／449 で済。
- 一拍中の下の帯・目標帯がイベントの覆いと重なって固まる：softlock #1 で済（W:1298 openOverlay）。
- 療養の週に選択肢イベント・オファーが出ない／療養の週の生活費が支払い画面に出ない：gamecore_boundary 1-1・money_audit／stamina N1。

## §4 問題なし（確かめた）
- 週を進めるボタンが知らせの間に押せる経路：体調ダウン・借金・すれ違い・hint・rent はいずれも全面の黒幕付きモーダル（`Color.black.opacity(0.65)` を全面に敷く＝下のタップを受ける）。立っているイベントがある間は `.allowsHitTesting(false)`（W:171）＋各カードの guard（W:920・1006・1625）。年末へ（W:1625）も guard 済。例外は N2 だけ。
- 同じ週に burst→rent→イベント→借金が並ぶ順：burstHold は rent の終了まで保持（W:296 の defer が presentRent の後）。下りて 0.3 秒でイベント・0.6 秒で借金（W:262〜269）＝順が一本。イベントが立っている間は体調ダウン・借金・すれ違い・hint が全部出ない。イベントが閉じて 0.5 秒後に再判定（W:272）。
- 印を先に立てて出せない物：借金・すれ違い・体調ダウンは「印→即モーダル」が同じ関数内で await 無し（W:1471〜1497）。取りこぼしは落とす場合だけ（N7）。
- 体調ダウンが大会入口・結果画面に重なる週：StageViews:236 が入口で先に出す。結果画面は通過して次の freeAction で出る（injuryNoticeWeeks は残る）。
- 誘い（inviteWaiting）の持ち越し：確定発火の下位・週次ランダムの上（G:629）。19b で既出。
- 週次ランダム抽選の二重引き：lastEventRollWeek（保存あり・G:644）。
- オファーの札：立っているイベントの間は触れず、閉じれば残る（offer_audit で既出）。
- 予選の知らせ：RootView の phase 切替で別画面（週メインの知らせと同時に出ない）。
