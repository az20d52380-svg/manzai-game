# 今日(2026-10-19 09:00 以降)の直しの再点検 v0

**件数：見たコード系コミット 37（docs のみは除外）／所見 7（高 0・中 5・低 2）／問題なし 30 前後（末尾の表）。**
読み取り専用の机上点検（ビルド・実機は未実施）。確度は「そう動く見込み」の度合い。

## 節構成
§1 所見（要対応の候補）／§2 問題なしの直し／§3 点検の限界

## §1 所見

### 1. 決勝：ネタが1本しか無い時、2本目の候補が「空のまま無言」になる（確度 中）
- コミット 1f660b5・`ManzaiGame/Sources/NetaSelectionView.swift:33-36`（`activeNetas.isEmpty` の空表示は元の全件が空の時だけ。フィルタ後が空の時の文言なし）
- 手順：持ちネタ1本で決勝へ→「決勝・2本目」の「ネタを選ぶ」を開く→候補が1行も出ない（「持ちネタがない」等の説明も出ない）。以前は同じネタを2本目に選べて `netaSecondPenalty` を免れていた（その抜け道を塞ぐのは意図どおり）。進行は止まらない（「2本目は選ばずに進む」が出る）。
- 直し案：フィルタ後が空なら「2本目にかけられるネタが無い（1本目と同じは選べない）」を1行出す。

### 2. 旧セーブで1本目＝2本目が既に同じ場合は、そのまま残る（確度 中）
- コミット 1f660b5・`GameSession.swift:802-809`（`ensureStageNetaDefault`）／`GameEngine.swift:271`
- 手順：修正前に両方同じネタを選んだセーブで再開→2本目の札は選択済みのまま（候補からは消えているので外せない）→減点を免れる状態が残る。
- 直し案：`ensureStageNetaDefault` の先頭で `selectedNetaID2 == selectedNetaID` なら `applyNetaSelect2(id:nil)`。

### 3. 長い名前が以前より早く末尾が切れる（見た目が変わる）（確度 中）
- コミット 753937d・`FinalsBroadcastIntro.swift:209-210`（`minimumScaleFactor` 0.5→0.7）
- 手順：長いコンビ名／相方名の組を出す決勝の紹介→縮小の下限が上がり、収まらない名前は「…」で切れる（以前は小さくして全部出していた）。
- 直し案：長い名は `lineLimit(2)` か `minimumScaleFactor(0.6)` に戻して目視（最長名で1枚）。

### 4. VoiceOver：決勝エンディングの閉じ口が「スキップ」ボタンだけになる可能性（確度 中）
- コミット 66472d7・`FinalsBroadcastIntro.swift:595`（コンテナ全体への `.accessibilityAction { finish() }`）
- 手順：VoiceOver 中は自動で閉じない（意図どおり）。コンテナ（ZStack）に付けた accessibilityAction は読み上げ要素にならず出ない可能性があり、その場合の出口は左上の「スキップ」ボタンのみ。閉じられなくなる事故にはならない（ボタンは `accessibilityLabel("スキップ")` 付きで到達可）。
- 直し案：本体の `VStack` に `.accessibilityElement(children: .contain)` ではなく、可視の「スキップ」ボタンを正式な出口とし、実機 VoiceOver で1回確認。

### 5. sim：`_ev_add` が EVENTS_APP=True かつ COMPAT_GROWS=False の組で相性を動かしてしまう（確度 中）
- コミット 56cf713・`tools/sim_career.py` の `_ev_add`（`key == "compat"` 分岐）
- 手順：`B.add` は `COMPAT_GROWS=False` なら相性を変えないが、`_ev_add` は無条件に加減算する。相性を固定にして測る実験スクリプトで EVENTS_APP=True を使うと、イベント経由でだけ相性が動く。通常設定（COMPAT_GROWS=True）では一致。
- 直し案：`_ev_add` の compat 分岐を `if not B.COMPAT_GROWS: return` で囲む。

### 6. 体調ダウン線を `GameConfig()` の既定値から取る（確度 中・影響小）
- コミット 45c56a0・`WeekHint.swift:29`
- 手順：難度などで `session.config.injuryThreshold` を変える場合、ひと言の判定は既定値（50）のまま食い違う。現状は既定のみ運用で同値＝今は問題なし。
- 直し案：`Input` に閾値を渡して `session.config` から取る。

### 7. VoiceOver の読み上げが連続で上書きされる可能性（確度 低）
- コミット 66472d7・`FinalistAnnounceView.swift:110-111`
- 手順：`called` が短い間隔で増えると `.announcement` が次の投稿で打ち切られ、組名の一部が聞き取れない場合がある（`stage` 変化の同時投稿も）。
- 直し案：実機で確認し、必要なら `AttributedString` の `accessibilitySpeechQueueAnnouncement(true)` で順番待ちにする。

## §2 問題なしの直し（1行ずつ）
- 0eff7be acknowledgeResult のガード：呼び手（TournamentResultView 165/274/558・FinalsPresentationView 424・GameSession 内のループ）はいずれも pendingResult 表示中。RootView:368 は pendingResult が nil になれば別の画面に替わるので進めなくなる経路なし。問題なし。
- b2b173b choiceApplied：立つのは applyEventChoice のみ、降りるのは dismissChoiceEvent と startNextYear。ほかに pendingChoiceEvent を nil にする所は無く、立ちっぱなしの経路なし。保存は applyEventChoice 内の saveNow で pending を nil にして出す（落とすと選び直し不要・効果は一度だけ）。startNextYear の hasYearStart・injuryNoticeWeeks の保存も整合。問題なし。
- 6a91db3 SaveData.injuryNoticeWeeks を既定値なしの Optional に：旧セーブは decodeIfPresent で nil→0。問題なし。
- 5123de9 誘いの順序変更：確定発火（いずれも1回きり）が尽きれば次の自由週で必ず出る。誘いが永遠に出ない経路なし（一回きりの確定が毎週続く条件は無い）。問題なし。
- 1c6e36e 買い物・戻すの保存：1操作1回の保存で、ループ内保存なし。重くならない。問題なし。
- 1f660b5 の selectNeta／retireNeta 側：1本目選択で2本目と重なれば2本目を外す、しまう時に2本目も外す。ensureStageNetaDefault 経由の連鎖も無限ループなし。問題なし（所見1・2を除く）。
- 0e380e9 / be4b19d / 7ba8fc2：`do_rest(s, name, use_ticket=True)` は既定値つきで gen_golden*.py・balance_sim 本体の呼び手は不変。差し替え3本＋exp_fun_audit は同じ引数を通す。exp_balance_snapshot_v0/exp_money_balance_v1/exp_money_harshness_v0 は `B.do_rest` を退避・復元するだけで再定義しないので落ちない。sim_career の `python3 -I` 構文確認も通過。Swift 側 runCareer の `dissolved` 打ち切りは Python と同期（Swift のテストは本点検では未実行）。問題なし。
- 56cf713 `_ev_add` のその他：キー名（sense/idea/chara/expr/mental/fame/stamina）と定数（COMPAT_CAP・MENTAL_CAP・ABILITY_CAP）は balance_sim に実在。EVENTS_APP=False は従来どおり B.add＝golden 不変。問題なし（所見5を除く）。
- 86283e9 .task 化：一度は必ず鳴る（場面が出た時に cheerMid／判の 0.4 秒後にファンファーレ）。鳴らなくなるのは早送りで画面を離れた時だけで意図どおり。問題なし。
- 016e8ce BGM：stopBGM は currentBGM を nil に戻すので、isPlaying 判定の再生は同曲の割り込み復帰だけに効く。Timer は .common に載せ替えただけ。既定音量 0.6 は SoundManager の既定と一致。問題なし。
- c46d626 トーストのトークン／確定の二度押し：allocate の前に taps を空にするので、確定の一瞬だけ割り振り表示が戻って見える可能性はあるが画面はすぐ閉じる。問題なし。
- dae9a6f コンビ名の空白・二重押し：NameEntryView は .nameEntry の度に作り直される（IntroFlow:765）ので decided が次回に持ち越されない。問題なし。
- 776ac8f 課金：起動時に StoreManager.shared を生成するだけ。復元の userCancelled は無音で false。問題なし。
- bd543cd 支払い／予選の取消確認：キャンセル後は音・振動・onDone が走らない。問題なし。
- 66472d7 の RentStatement：`.accessibilityAction { onDone() }` が結合要素に付くので VoiceOver のダブルタップで閉じられる（閉じられない画面にならない）。予選の通知は「つづける」ボタンが VO で到達可。問題なし。
- e93bfaa「飛ばす」を消す条件：予選は `atEnd` と「つづける／閉じる」の表示条件が同一、決勝進出者は `.after` で「つづける」表示。出口は残る。問題なし。
- 753937d reduceMotion／ラベル：`withAnimation(reduceMotion ? nil : …)` は標準設定で見た目不変（ほか minimumScaleFactor は所見3）。問題なし。
- 22c05d8 / 8b2b788 札の背丈：offerPicker は HStack に `fixedSize(vertical)` があり、図鑑は LazyVGrid 内。縦に伸びすぎない。問題なし。
- 6b75cfc 決勝進出者の崩れ：swapAt の添字 count/2+count/4 は常に範囲内。問題なし。
- 6198329・01a3a37・8a59595・eb82897：余白だけ／DEBUG 限定／文言のみ。問題なし。
- 台詞・講評の文字列直し（f94a441・beb972a・36dac18・7b785e9・db92fd1）：配列の要素数は不変（置換のみ）で番号に依存する pick は崩れない。問題なし。
- 43fe0de・0b7b426：実測スクリプトの追加のみ（既存呼び手なし）。問題なし。

## §3 点検の限界
- ビルド・テスト・シミュレータ・VoiceOver 実機は未実施（机上のみ）。所見4・7 は実機で確認が要る。
- Swift のテスト（runCareer の dissolved 打ち切りの影響）は本点検では走らせていない。
