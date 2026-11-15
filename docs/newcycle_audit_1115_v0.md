# 「次の周（新しいゲーム）」の始まりの点検（11/15・読むだけ）

要点
1. 新規 3件（高0・中0・低3）＋既出の再掲 4件。前の周の表示用の状態が新しい周に残って「知らせが出ない／二度出る／数字がずれる」実害の穴は**見つからなかった**（GameSession は周ごとに作り直し・UserDefaults の持ち越しは全部意図どおり）。
2. 引き継ぎ画面（タイトルの帯）の経験点・所持金は GameState.init の式と一致（同じ MetaBook.points を2回読むだけで、間に点が変わる経路なし）。帯に相性が出ない・「伸びしろ」の文が点1でも出るのは既出（trophy_meta #8）。
3. 周回の式の形は Python（apply_meta_start／meta_cap_lift／meta_budget）と Swift（GameState.init／WeekRunner:135-148）で足し順・上限・丸めまで一致。相性は最大でも 5+14=19 で上限20に届かず、2周目の第1戦で t14 が自動で付くことはない。

節構成：§1 新規の指摘（#1〜#3）／§2 既知・既出／§3 確認済み（問題なし）

対象：RootView.swift（returnToTitle:357・abandoned:343・mainFlow:376）・GameSession.swift（init:216・restoring:266・loadedOrNew:1372・abandonRun:1044）・IntroFlow.swift（S1TitleView:365・IntroFlowView:770〜）・Meta.swift（MetaBook:199・TrophyBook・EndingBook は Endings.swift:183）・GameState.swift:118〜139・WeekRunner.swift:130〜148・TournamentResultView.swift:46・WeekMainView.swift:1511・tools/sim_career.py:98〜127,911〜917。

## §1 新規の指摘

### #1 【低】「この周をやめてタイトルへ」の経路だけ、ネタ札の「光り方の記憶」が前の周から残る
- 場所：RootView.swift:343-349（`onChange(of: session.abandoned)`）と :357-362（`returnToTitle`）。`NetaStage.lastSeen = [:]`（:361）は returnToTitle にしか無い。
- 起きる手順：1周目の途中で設定→解散（DisbandFarewellView→abandonRun）→タイトル→新しい周で同じ id のネタを作る（id は周ごとに振り直し）。`lastSeen[id]` に前の周の段が残るので、段が上がっても `idx > prev` にならず光らない／逆に最初の1回で上がった扱いで光る。表示のみ・勝敗に影響なし。
- 既出との関係：code_review_2026-10-19i §2 の直し案は「returnToTitle と abandoned の両方」だったが、入っているのは returnToTitle 側だけ（abandoned 側は漏れたまま）。
- 直し方の案：abandoned の onChange にも `NetaStage.lastSeen = [:]` を1行足す（①）。または GameSession の init で消す（②・どの経路でも漏れない・ただし GameSession が表示の static に触れる）。推奨①。

### #2 【低】初舞台（FirstStageView）の途中でアプリを閉じると、その人は初舞台を一度も見ずに終わる
- 場所：IntroFlow.swift:850-851（`let first = !hasSeenIntro; markIntroSeen()` を初舞台の**前**に書く）。
- 起きる手順：初めて遊ぶ→回想を最後まで見る（この時点で introSeen が立つ）→初舞台の最中にアプリを落とす／切り替える。まだセーブは無い（GameSession が作られる前）ので次の起動はタイトルから。回想は「とばす ▶」付き・初舞台は `hasSeenIntro` で飛ばされる＝初舞台の場面を見る機会が二度と来ない。
- 実害：初回だけの演出が1回見られないだけ（状態・式に影響なし）。double_tap_audit #1 は二度押し対策で、この落ちた時は別の件。
- 直し方の案：①markIntroSeen を初舞台の完了（finish）で呼ぶ（回想だけ見て終えた人は次回もう一度回想が「とばす」なしで出る＝今の2周目動線との差を確認）②今のまま。推奨②寄り（影響が軽い）。

### #3 【低】「1周目」の判定が4系統あり、食い違う人がいる（意図の確認だけ）
- 場所：①導入のとばす＝`hasSeenIntro`（IntroFlow:793・回想を見終えたか）②結果画面「次へ」の0.8秒ロック＝`EndingBook.load().isEmpty`（TournamentResultView:48・終わりを見たか）③初回の説明（初週・生活費）＝`OneTimeHint`（「わかった」を押したか）④タイトルの帯＝`MetaBook.points > 0`（トロフィー＋図鑑）。
- 起きる手順（例）：1周目を設定→解散でやめる（エンディングを見ない）→2周目。導入は「とばす」が出る（①）・帯は取れたトロフィー分が出る（④）が、結果画面の「次へ」は1周目扱いのまま 0.8秒ロックが残る（②＝図鑑が空）。毎回やめる人は永久に②のまま。
- 実害：結果画面の操作が1周目と同じ慎重さのままなだけ（連打で飛ばしたい周回者向けの配慮が効かない人が出る）。
- 直し方の案：①今のまま（「終わりを見た＝周回者」と割り切る・オーナー 10/20 の記述どおり）②`hasSeenIntro || !EndingBook.isEmpty || MetaBook.points > 0` のような共通の `isReturningPlayer` にまとめる（表示側のみ）。判断：オーナー（周回者の定義）。推奨①。

## §2 既知・既出（再掲）
- 周の始めの帯に相性の上乗せ（最大+14）が出ない／点1でも「伸びしろの上限も、少し上がっています」と出る → docs/trophy_meta_audit_1115_v0.md #8（既出・表示のみ）。
- 夜行バス（t12）・稽古（t13）のカウンタ（`mz.trophyCounters`）は周回をまたぐ通算 → trophy_meta_audit_1115 #1 付記（既出・設計どおり「通算」）。`mz.careerRecords`（通算優勝・最多連覇・最速年・HANA 優勝）も周回をまたぐが、画面で「通算」と読ませる記録なので意図どおり。
- 周回の点の最大は 36（実際に取れる上限）で、頂点の束の基準 38 とずれる → docs/AUTOPILOT.md 147（判断待ち・候補 claude/rift-trophy-cand）。
- 周回メタの読み込みが1件の型違いで全部空になる穴 → AUTOPILOT 154（候補 claude/meta-lenient-load-cand）。
- エンディングの最中にアプリを落とすとセーブが無く図鑑にも入らない → save_restore_audit_1115 #7（既出）。
- 周回の式は 型1/頂点の束/相性/年の上限の天井 すべて check_config_sync で定数が同期済み（AUTOPILOT 485）。meta_start_bonus_1020 は型1（加算）＝今の実装の選定記録（110 は型2をやるかの判断待ちで未着手）。

## §3 確認済み（問題なし）
- **GameSession の持ち越し（観点1）**：新しい周は必ず `GameSession(...)` を新規に作る（IntroFlow 完了→RootView:380、returnToTitle:360、abandoned:346）。categoryLog・weeksWithoutPartner・totalPrize・debtWarnTier・didShowRiftHint・youthNoticeYear/tiredNoticeYear・usedPicks・shownOnce・usedFanLines・winFinale などの private(set) var は全部インスタンス変数＝前の周の値は残らない。static は Names（init で `Names.set`/`setKind` を呼び直す）・NetaStage.lastSeen（#1 以外は returnToTitle で消す）・Theme の連打間隔・FontLoader だけで、周の状態ではない。
- **復元（restoring）**：`GameState.metaPoints` がセーブに入る（Optional・GameState の合成 Codable）ので、復元は**今の図鑑の点で計算し直さず**保存時の点で続く。年初の成長予算（WeekRunner:135-148）も `s.metaPoints` から出す＝周の途中で図鑑が増えても数字がずれない。UI 層の一発化フラグは SaveData に入って復元で書き戻す（save_restore_audit_1115 §2 と同じ）。
- **タイトルに戻した時の余分な session**：returnToTitle の `GameSession()`（固定 seed 424242）は init→pump で UserDefaults に何も書かない（saveNow・TrophyBook は呼ばれない）。`started=false` の間は scenePhase の保存も走らない（RootView:352 `started` 条件）。副作用は `Names` を既定（俺・谷口・男コンビ）へ戻すことだけで、タイトル〜形の選択で前の周の名前が残らない効果として働く。
- **名前・形の選び直し（観点3の一部）**：IntroFlowView は `@State` を毎回既定で作り直す（name「あなたのコンビ」・kind 男コンビ・meeting 高校）。形は ComboKindPicker で必ず選ぶ（Names.setKind）→名前→回想。前の周の名前は図鑑の `lastPartnerName`（表示用）以外どこにも残らない。女コンビの THE HANA の印は `GameState.femaleCombo` で周ごとに決まる。
- **第1週の説明・はじめの会話（観点3）**：初週の「実力/相性/体力/経験点」の説明は `OneTimeHint("firstWeek")`＝端末に一度だけ（`mz.hint.*`・周回をまたぐ）で、2周目以降は出ない＝意図どおり（`？` から開き直せる：WeekMainView:369）。生活費の説明も同じ。決勝の導入・舞台の幕開けは初回フル・以降短縮（`finals_broadcast_intro_seen`／`stage_ceremony_seen`・端末に一度）。導入の回想は2周目以降「とばす ▶」（`manzai.introSeen.v1`）・初舞台は1周目だけ。年初の知らせ（若手最後・ネタの飽き）は session 側の年ごと印なので新しい周では年1・年2…で正しく出る。
- **引き継ぎ画面の数字と実際の値（観点2）**：`MetaBook.preview`（Meta.swift:215-219）＝経験点 `min(160, 4P) + 300·(P/38)^8`、所持金 `min(100万, 3万·P)`。GameState.init（:132-138）は同じ式を5通貨に 35/27/18/10/10% で配る＝合計は一致。丸めは帯が合計を1回丸め・実際は各通貨が小数のまま持つので、通貨ごとの表示は帯の合計と最大でも数点ずれうるが、帯の文は「経験点 +N」の合計でしか使わない（週メイン・手帳は通貨別の表示）。上限：所持金は P≥34 で 100万（帯も 100万・`/10_000` は3万刻みなので割り切れる）。経験点の型1は P≥40 で160頭打ちだが P の最大は 36＝型1は常に 4P（≤144）。`MetaBook.points` を読むのはタイトルの帯と GameSession.init の2か所だけで、その間（名前決め〜回想）に TrophyBook／EndingBook が増える経路は無い＝帯と実値は常に同じ点から。
- **相性の上乗せ**：初期相性 5.0（compatInit）＋最大 14（P=36 で 2.27·6=13.6）＝最大 18.6・上限 20 に届かない＝2周目の最初の大会で t14（相性が上限）が自動で付くことはない。
- **Python 正典との式の形（観点4）**：`apply_meta_start`（sim_career.py:114-127）と `GameState.init`（GameState.swift:129-139）は 型1の経験点→所持金→相性（`min(14, 2.27·P^0.5)`・`min(compatCap, …)`）→頂点の束の経験点（`300·(P/38)^8`・上限なし）の順まで同じ。年の天井の持ち上げ `0.2·P^0.3`（基準と下限の両方）と累計予算の頂点の束 `36·(P/38)^8`（足し順 meta_budget + Σ）も sim_career.py:911-917 と WeekRunner.swift:135-148 が一致。P=0 は両方とも何もしない（golden 不変）。DEBUG の `MZ_META` は `#if DEBUG` 内のみ（製品に出ない）。
- **設定・図鑑・トロフィーの持ち越し**：音量・演出の速さ・通知の既読・ガチャ台帳は周回をまたぐ設計（settings_leak_audit_1115）。トロフィー（`mz.trophies`）・図鑑（`mz.endingsSeen`）は周回で増える一方で消えない。図鑑への記録は EndingFlowView の onAppear（EndingViews.swift:51）＝タイトルに戻る前なので、次の周のタイトルの帯に必ず反映される。夜逃げ・解散・最終年のエンディングも endingID を持つので同じ経路で記録される。
- **ネタ・お店の品・状態**：どれも GameState／GameSession の中（ネタ・アイテムは state、お店の品の「その年だけ」は resetYearlyItems）で、周の始めは `GameState(config:metaPoints:femaleCombo:)` の初期値から。前の周の持ち物は新しい state に入らない（GameCore の golden が保証）。
