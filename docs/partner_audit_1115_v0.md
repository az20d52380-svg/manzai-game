# 相方との関係の流れの点検（2026-11-15・読むだけ）

- 要点1：新規8件（高0・中1・低7）。**予告なしに突然解散する経路は見つからなかった**（解散＝riftWarned が真の時だけ・警告は rift≥50 で立ち、増え幅は週0.5以下＝50→100に最短100週。1年目は rift を99で止める）。
- 要点2：最も重い1件＝§1-1（予告の知らせは「キャリアで1回だけ」。向き合って rift が下がった後や、流した後は、再び100に届くまで知らせが一切無い）。
- 要点3：Python 正典と Swift のすれ違い・誘いの式／乱数の消費順は一致（規律A違反なし）。先輩の誘いの二重適用は無い。取りこぼし（再開で消える持ち越し分）は既出。

節構成：§1 解散と知らせ／§2 相性・凍結・チップ／§3 先輩の誘い／§4 画面の説明の数字と GameConfig／§5 Python と Swift／§6 問題なし

## §1 解散に至る条件と知らせ

条件（確認済み）：GameEngine.swift:289-310 `applyRiftWeekEnd`。相性がその週に上がらず・二人で舞台に立たない週は rift += 0.5×(20−相性)/20（相方思い ×0.8）／相性が上がった週は −3／rift≥50 で riftWarned が真／rift≥100 かつ riftWarned で解散。夜逃げ判定の後・誘いの抽選の前（WeekRunner.swift:461-478）。

### 1-1 【中】予告（0050）は1回きり。A のあとの再接近・B のまま100へ向かう間は無告知で解散できる
- 場所：GameEngine.swift:303（riftWarned は一度真になったら戻さない）／GameSession.swift:597-600（`!didFireRiftWarn`＝キャリア1回）／ChoiceEvent.swift:358-362（A＝rift−30）
- 手順：①rift 50 到達→0050 を見て「A 向き合う」（rift 約20へ）→以後ネタ合わせ・相方と過ごすをほぼしない（相性5前後で週 +0.375）→約200週で再び100→**予告なしで解散**。②「B 流す」を選ぶと rift 50のまま→約100〜130週で解散（知らせは「すれ違いが減る」の帯が1回出るだけ・rift の値を見せる画面は無い）。
- 実害：現実には「2年以上相方に会わない」が要るので稀。ただし画面に rift が出ず、WeekHint の「最近、相方とゆっくり話していない」（§1-3）が唯一の継続的な知らせ。
- 直し案（判断が要る）：①今のまま（1回きりが仕様）②rift が80を越えた週に2回目の短い知らせ（独白1行・乱数なし・状態は「rift≥80かつ未表示」のフラグ1つ＝UI層のみ・GameCore と golden は不変）③A で rift が下がった時に riftWarned を戻す（GameCore の式変更＝規律A＝Python も同時に）。推奨②。

### 1-2 【低】riftWarning の台詞「バイトが続いてた」は原因が違っても固定
- 場所：ChoiceEventData.swift:757-761。rift は休養・稽古（ネタ合わせ以外）・バイトのどれでも溜まる。体力が低くて休み続けた人にも「バイトが続いてた」が出る。
- 直し案：①今のまま ②原因を言わない言い方（文言はオーナー決定）。

### 1-3 【低】WeekHint「相方とゆっくり話していない」と rift が別カウント
- 場所：GameSession.swift:387-390・WeekHint.swift:52。weeksWithoutPartner は自由週の行動がネタ合わせ／相方と過ごす以外なら +1（ネタ見せ会・フリーライブも数える）。一方 rift は舞台に立つ週は増えない（riftJointStill）。
- 起きる：ネタ見せ会・フリーライブを続ける人に6週で「話していない」が出るが rift は溜まっていない。逆に rift が溜まる週は必ず数える＝安全側（早めに出る）。
- 直し案：①今のまま ②舞台週は数えない。

### 1-4 予告を見ないまま消える経路
- 問題なしに近い。再開時（GameSession.swift:316-319）と年末へ（:1010-1011）で未発火に戻る。ChoiceEventOverlay の「とじる」は選択後か選択肢が無い札だけ。

## §2 相性の上限・凍結・チップ

### 2-1 【低】週頭イベントの相性の増減が「相性が上がった週」に混ざる
- 場所：WeekRunner.swift:191（riftWeekStartCompat は begin 時点）／イベント効果は begin の後（applyEventEffects）。
- 起きる：相性+1 のイベントが出た週は、行動がバイトでも rift が −3。逆に 0019A（相性−1）の週にネタ合わせ(+1)をすると差し引き0＝「上がらない」判定で rift が増える。Python も同じ式（EVENTS_APP 時）＝仕様の範囲。
- 直し案：①今のまま ②イベントの前に基準を取り直す（式変更＝規律A）。推奨①。

### 2-2 【低】相性の内部値（小数）と表示（四捨五入）・ゲートの丸めが三通り
- 表示：WeekMainView.swift:565・NotebookView.swift:133 は四捨五入／イベント発火：GameSession.swift の `compat >= 15`・`>= 8`・`<= 7` は生の値、ChoiceEvent.swift:398 の greenroom は `Int(compat)`（切り捨て）。JudgeTalk.swift:222・470・478 も生の値。
- 起きる：GP 予選落ち（−0.5・−0.25・−0.125）と周回ボーナス（2.27√P）で小数になる。例：相性14.6は「15」と表示されるがツーカー（≥15）は未発火。トロフィー t14（Meta.swift:177 compat ≥ 20）は 19.5 だと「20」表示でも付かない（次の +1 で付く）。
- 直し案：①今のまま ②ゲートを表示と同じ四捨五入にそろえる（帯の変更＝決定はオーナー）。

### 2-3 凍結（compatFreezeWeeks）
- 問題なし。イベントデータで compatFreeze を使う選択肢は現在0（定義と適用だけ）＝旧セーブの残りのみ。減算は GameSession.swift:435 で週ごと。凍結は add の増加だけ止め、イベントの `.compat(d)` は素通り（ChoiceEventEffect.swift:30）＝設計どおり。

## §3 先輩の誘い（pendingInvite）

- 受ける：GameSession.swift:783 で runner.applyInviteGo を1回（choiceApplied :778 で二度押し防止）。runner.resolveInvite は app からは呼ばない（bot の Career.swift:89 だけ）＝二重に引かれない。
- 断る：効果なし。runner.pendingInvite は次の begin()（WeekRunner.swift:188）で nil。
- 再開：札を出したまま閉じる→inviteIdea は保存済み（GameSession.swift:1288・1359＝11/15 直し済み）。選択後に閉じると pendingChoiceEvent は nil で保存（:1346）＝二重適用なし。
- 既出：持ち越し中の誘い（inviteWaiting）は再開で消える＝save_restore_audit_1115 §1 補足（許容）。
- 来る週（解散判定の後）と札の出る週（次の自由週の頭）がずれるのは設計（:626-629）。

### 3-1 【低】持ち越し中に次の誘いが来ると上書き（1回分が消える）
- 場所：GameSession.swift:1403。確定発火が続く週だけ・率4%＝重なる確率は低い。
- 直し案：①今のまま ②持ち越し中は新しい誘いを無視（古い方を残す）。

## §4 画面の説明の数字と GameConfig

一致（確認済み）：誘いの札「（5,000円）」＝inviteMoney 5000（ChoiceEventData.swift:341・363）／体力線は injuryThreshold を直接参照（WeekHint.swift:34）／設定画面の「すれ違い」（SettingsView.swift:276）・週メインの帯（WeekMainView.swift:1478）に数字は無く、仕組みは GameEngine の式と一致。
- 「相方と過ごす・ネタ合わせをした週は減る」は相性が**実際に上がった週**だけ。ネタ合わせが休みに差し替わった週は減らない（WeekHint 側は :402 で差し替えを数えている＝一致）。相性が上限20なら増えもしない（gain＝0）。

## §5 Python 正典と Swift

一致（確認済み）：rift_weekend ⇔ applyRiftWeekEnd（式・year<2 の 99 止め・警告・100 判定・順序）／invite_roll ⇔ rollInvite（ハッシュ・SplitMix64・2回目の引き）／invite_weekend ⇔ applyInviteGo／GP 予選落ち −0.5,−0.5,−0.5,−0.25,−0.125／metaStartCompat（係数・指数・上限14・compatCap 20）。誘いと rift は本編の乱数を消費しない。

### 5-1 【低】check_config_sync.py が見ていない定数がある（現在値は一致）
- 場所：tools/check_config_sync.py PAIRS（riftHeal・riftJointStill・inviteMoney/Stamina/Mental/Idea は有る）。無い：riftGain(0.5)・riftWarn(50)・inviteRate(0.04)・inviteIdeaP(0.5)・gpLossCompat・compatInit(5)・compatCap(20)。AUTOPILOT.md:24 の「誘い・すれ違い」はその一部だけ。
- 直し案：PAIRS に足す（gpLossCompat は配列比較が要る）。式・値は変えない。

## §6 問題なし（1行ずつ）
- 予告なしの即解散：不可能（riftWarned 必須・週の増え幅 ≤0.5・1年目は99止め）。
- 年またぎ：riftWarned・rift・riftWeekStartCompat は GameState に入り持ち越し。
- 年末へ：予告は見ないまま消さず未発火に戻る（GameSession.swift:1010）。
- 予告の優先順位：evaluateChoiceEventFire の先頭＝他の確定イベントに譲って遅れない。
- 予告の中断復元：保留中なら再表示・選択後は riftWarnChoice 保存で二重に出ない（:318・:789）。
- weeksWithoutPartner：休み差し替え週の補正あり（:402）・旧セーブ nil＝0。
- 相性チップ：丸めた差で数える（number_display_audit 既出）。
- 誘いの二重適用：なし（§3）。
