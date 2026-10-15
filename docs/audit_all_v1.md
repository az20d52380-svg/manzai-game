# 全体監査 v1（コード読みのみ・2026-10-16）

対象：ManzaiGame/Sources、GameCore/Sources（本体ブランチ）。コード・数値は変更していない。シミュレータ・swift test は未実行（読むだけ）。
「決めが要る」＝オーナー判断が要るか。要らない物は表示・修理として自走で直せる。

## §0 先に（重い順の要約）
- 重大 3 件：A-1（夜逃げの突然死・生活費14万で悪化した可能性が未再測）／A-2（休ませたネタは飽きが進まない抜け道）／B-1（正典の「督促」段が未実装＝借金の警告が画面に無い）
- 中 8 件・小 多数。D（DEBUG漏れ）は問題なし。

## §A バグの疑い

**A-1 [重大] 稽古偏重だと2〜5年目に突然「夜逃げ」で終わる／生活費14万で悪化の可能性が未測**
- GameCore/Sources/GameCore/GameEngine.swift:221（applyWeekEnd）／GameConfig.swift:`livingCost=140_000`・`bankruptLine=-1_000_000`
- 何が起きる：4週ごとに14万が引かれ、所持金が -100万 を割った週末で即キャリア終了。実測 `docs/stuck_and_exploit_check_v0.md` §1-2・§4 穴A は生活費10万時代の数字（無料稽古2:バイト1で66%、3:1で87%、バイト無し100%）。決定④お金L（バイト×0.8・生活費14万）の後に再測した記録が無い＝実際はもっと高い疑い。画面側も借金の警告が無い（B-1）。
- 直し方の案：①`exp_stuck_v0.py stuck` を現行 config で n=1000 再測（自走でできる）。②救済1回（肩代わり）または警告＋猶予（穴A案A1/A2）。
- 決めが要る：再測＝不要／救済や警告の仕様＝要る。

**A-2 [重大] ネタを「しまう」と飽きが進まない（飽きの抜け道）**
- GameCore/Sources/GameCore/WeekRunner.swift:122（年初の飽き加算は `s.netas`＝アクティブ枠だけを回す）／ManzaiGame/Sources/GameSession.swift:699・706（retireNeta／recallNeta）
- 何が起きる：決定①（案D・使った年の数だけ不利）の飽きは、年初に `state.netas` だけが数える。大会で使った後に保管庫へしまい、翌年に呼び戻すと `lastUsedTaikaiYear == year-1` の判定が飛ばされ、飽きが進まない。鉄板ネタを毎年使い回す対策（決定①の目的）が2タップで外れる。
- 直し方の案：年初の飽き加算を `archivedNetas` にも回す（乱数なし・golden非経路）。または retire/recall 時に判定する。
- 決めが要る：「しまって寝かせたら飽きが戻る」を許すかどうかは決定①で「戻らない」と決まっているので、直すだけでよい（不要）。

**A-3 【済 9b5fcaa】[中] 勝利演出の途中でアプリを閉じると優勝が消える**
- ManzaiGame/Sources/GameSession.swift:889-897（saveNow：`winFinale` なら保存を削除）
- 何が起きる：決勝に勝った直後の演出中（winFinale=true）に終了すると、セーブは消され、再起動は新規。優勝＝勇退エンディングを見ずに最初から。
- 直し方の案：優勝の位相では「年末S6の入口」で保存を残す（エンディング後に削除）。
- 決めが要る：不要。
- 目視確認（2026-10-15）：目視OK。MZ_SAVEMAKE=champ で優勝演出中に保存→terminate→再起動すると、決勝演出（頂グランプリ決勝・1位ボード）が出し直された（feedback_shots/audit_fix_check/a3.png）。

**A-4 【済 dcfa26d】[中] 復元時にバランス更新が一部だけ古いまま残る**
- WeekRunner.swift:537（`finalLine = snap.finalLine`）、保存済み `pendingSpec`（TournamentSpec の line/prize ごと保存）、`pendingOffer`
- 何が起きる：config は毎回新しいのに、決勝ライン・保留中の大会（ライン・賞金）・保留中のオファー（収入）は保存時の値で動く。今回のお金L（オファー×0.8）や知名度Gの更新をまたいだセーブは、その週だけ古い値。
- 直し方の案：復元時に `finalLine` を config から取り直す／pendingSpec を `calendar.tournament(inWeek:)` で引き直す。
- 決めが要る：不要（影響は更新直後の1週のみ）。

**A-5 【済 fb27941】[中] 復元後に前回の決勝の差（lastFinalMargin）などが空**
- GameSession.swift:195-213（restoring に lastFinalMargin／lastGains／lastDeltaWeek を戻していない）、SaveData に無い
- 何が起きる：年末画面（S6）で中断して再開すると、決勝の「あと◯点」の表示が出ない可能性。`yearStartState` が nil の旧セーブは `GameState(config:)`＝初期値に落ちるので、2年目以降だと「この年で育ったもの」の差分が過大に出る。
- 直し方の案：`weekResults` から margin を引き直す（986行と同じ手）。yearStartState nil の時は表示を出さない。
- 決めが要る：不要。
- 目視確認（2026-10-15）：目視OK（仕様どおり）。2年目の通常セーブでは年末画面に「この1年で育ったもの」が出る（a5_yearend.png）。年初状態が無い旧セーブ（yearStartState除去・2年目）では差分が過大にならないよう意図的に非表示（a5_yearend_old.png）。「旧セーブで出る」ではなく「出さない」が修正の設計。決勝の差は2年目の敗退年のため margin 無しで確認不可（コード側のみ）。

**A-6 【済 f68057d】[中] 新規フィールドの規約が人頼み（テスト網に無い）**
- GameCore/Sources/GameCore/GameState.swift:5-10（規約はコメントのみ）、GameCore/Tests に ManzaiGame 側の SaveData 復号テストが無い（CodableTests は GameState／Snapshot まで）
- 何が起きる：SaveData（GameSession.swift:842）に非Optional を足すと旧セーブが全部復号失敗→「壊れたセーブは退避して新規」（GameSession.swift:930）＝プレイヤーの進行が消える。気付く手段が無い。
- 直し方の案：旧版 SaveData の JSON 固定サンプルを fixtures に置き、復号できることをテストにする。
- 決めが要る：不要。

**A-7 [小] 体調ダウン判定が稽古では実質死んでいる**
- WeekRunner.swift（resolveAction）：体力<20 の稽古は先に休みへ差し替わり（staminaGate=20）、その後の injury 判定は `injuryThreshold=20` で `.train` を危険扱いする。同じ20なので稽古側は到達しない。キツいバイトだけが効く。
- 直し方の案：意図通りならコメントを直す。稽古でも出すなら threshold を gate より上に。
- 決めが要る：要る（意図の確認）。

**A-8 [小] 大会の保留中に年末（48週）を跨ぐ状態は無いが、`week>48` の処理は GameSession 側に専用テストが無い**
- WeekRunner.swift begin()（week > weeks）／GameSession.careerOver（790行）
- 最終年（10年目）の年末は careerOver で勇退エンディングへ。優勝しない10年目でも「勇退」と呼んでよいか（文言）は未確認。
- 直し方の案：10年目を `debugPlayToEnd`（MZ_SMOKE=3）で通す目視を常設に。
- 決めが要る：文言のみ要る。

**A-9 [小] 優勝の週は生活費を払わない**
- WeekRunner.swift（resolveAuto .final：優勝で即 `.yearDone`）／コメントで意図は明記（runYear と同一）。
- 何が起きる：47週目で優勝した年は、47週の生活費ぶん（47は4で割れないので実害なし）。48週が4の倍数なので最終週の生活費は決勝後に払われない年が出るが、優勝＝勇退なので影響なし。記録のみ。

**A-10 【済 9b119d1】[小] 療養週に銭湯の回数券が黙って減る**
- WeekRunner.swift proceed()（療養で `applyRest(.完全休養)`）→GameEngine.swift applyRest（sentoTickets 消費）
- プレイヤーが選んでいない休みで回数券が1回減る。直し方の案：療養週は回数券を使わない。決めが要る：要る（意図か）。

## §B 仕様と実装のずれ

**B-1 [重大] 正典v2の借金「督促（-50万・強制バイト／質入れ二択）」が実装も画面も無い**
- docs/canonical_v2_spec.md:30 ／ GameEngine.swift:221 は「生活苦」「夜逃げ」の2段だけ。grep で「督促」「質入れ」はソースに無い。画面は所持金が赤くなるだけ（WeekMainView.swift:923）。
- 何が起きる：A-1 と合わさり、プレイヤーは借金に気付かないまま夜逃げする。
- 直し方の案：①-50万で谷口が止める演出（強制せず勧める＝穴A案A2）②正典側を「2段」に書き直す。
- 決めが要る：要る（①か②）。

**B-2 【済 d6bc250】[中] START_HERE.md が古い**
- docs/START_HERE.md:11-28（「17件すべてgreen」「次にやること」）。現在は 126 件 green（AUTOPILOT 132行）。索引に canonical_v3 相当（経験点5通貨・お金L・知名度G）への導線が無く、正典は canonical_v2_spec.md のまま。
- 直し方の案：「いまの状態」を AUTOPILOT への1行に置換し、正典v2＋後続決定の差分表を1枚足す。
- 決めが要る：不要。

**B-3 [中] 決定④お金Lの数値は Config と一致、ただし周辺が旧スケールのまま**
- 一致：jobs 96,000／64,000／32,000（=120/80/40×0.8）、offerMoney 240,000・offerExp 120,000、livingCost 140,000（GameConfig.swift）。決定①（tiredCap=2・penalty=1）、決定②（fameOtherMult=0.6）も一致。
- 旧スケールのまま：ChoiceEventData／ChoiceEvent.swift の金額（+30,000／+150,000／-4,000 など：ChoiceEvent.swift:127,169,180,204）、`taniguchiShortJob` の金欠線 100,000（GameSession.swift:432）、`senpaiMeishi` 200,000（ChoiceEvent.swift:225）、`brokeDrinkingInvite` 50,000。生活費14万の後は「10万未満＝金欠」の意味が薄い（次の支払い前に14万要る）。
- 直し方の案：金欠線を `livingCost` 基準（例：livingCost 未満）にする。
- 決めが要る：要る（イベントの発火帯＝体感に効く）。

**B-4 【済 4c6ca71】[小] ショップの文言が config とずれる余地**
- ManzaiGame/Sources/ShopView.swift:136（"4回ぶん" が直書き。config.itemSentoTickets=4 と今は一致）。
- 直し方の案：`config.itemSentoTickets` から出す。決めが要る：不要。
- 目視確認（2026-10-15）：目視OK。銭湯の回数券が「休む4回ぶん」「4回ぶん」と設定値どおり（b4.png）。

**B-5 [小] 大会カレンダー表示と実装の食い違い候補**
- GameSession.swift:1062（DEBUG）の「第44週 決勝」と実体 47週（gpFinalWeek）。DEBUG用の見本ログのみで本番には出ない。
- 大会「若手限定賞」は careerYearAtMost(5)、他は 10：UI が年数条件を出しているか未確認。

**B-6 [小] 規律A（Python同期）の注記の古さ**
- GameConfig.swift 内コメント（offerRates の「20/50/80→10/30/55」）は経緯として残っているが、tools/sim_career.py の値との同期は `tools/check_golden_sync.py` で確認していない（本監査では未実行）。

## §C 文章

**C-1 [中] 「頂グランプリ／頂GP／GP」の表記ゆれ**
- 「頂GP決勝」（GameSession.swift:756,990）／「頂GP 決勝」（GameSession.swift:525・半角空白入り）／「GP決勝」（結果名・WeekRunner）／「これまでの頂グランプリ」（YearResultView.swift:108）／「頂 グランプリ」（3箇所・空白入り）／フォールバック「頂GP◯回戦」（GameSession.swift:519）。
- 直し方の案：正式名「頂グランプリ」と略称「GP」の使い分けを1つ決め、表示用の名前定数を一本化。内部名 "GP決勝" は結果判定で使うので変えない（別に表示名を持つ）。
- 決めが要る：要る（正式表記）。

**C-2 【済 5cc880a】[小] 空白・記号**
- WeekMainView.swift:278「経験点が残ってる ・ 能力アップで使おう」（「・」の前後に空白。他は詰める）。
- 直し方の案：「経験点が残ってる。能力アップで使おう」。決めが要る：不要。
- 目視確認（2026-10-15）：目視OK。MZ_UI=prestage で「経験点が残ってる。能力アップで使おう」（「・」なし）を確認（c2.png）。

**C-3 【済 4218fb2】[小] 講評データの重複文**
- GameCore/Sources/GameCore/JudgeTalk.swift:498/523（「後ろの席まで届いていた。{中}だけ、前の席止まりだった。」）、505/538（「磨かれた{入り}。…」）、507/527（「間の取り方が場面ごとに違う。…」）が2つのプールに同一文。210/329 の「粗を探す気で座った。粗がなかった。」も重複。
- 何が起きる：同じ決勝で別の審査員が同じ文を言う可能性。直し方の案：重複を別の言い回しにする（講評の採点ゲートに通す）。決めが要る：不要。

**C-4 [小] 古い数字・業界語・％・「笑」**
- 画面の日本語に「生活費10万」等の古い数字は無い（金額を直書きした表示文は賞金「◯万」のみで、config から計算）。DialogueData.swift:99・100 は「生活費の日が近い」「家賃の振り込みが近い」＝数字なし。
- ％表示：ManzaiGame/Sources に「％」の表示文は無し（オーナー決定どおり）。「笑」は表示文に無し（FinalsTalk.swift:5 の規約どおり）。
- 業界語（香盤表・前座・楽屋・ネタ見せ会・ネタおろし・鉄板・再演）：世界観の語として多数あり、ChoiceEventData／DialogueData に点在。オーナー決定は未確認（docs に「業界語」の方針文書は dialogue_clarity_audit_v0.md ほか）。
- 決めが要る：要る（方針が既に決まっていれば、grep で一覧を出して直す）。

**C-5 [小] 生活費がどの画面にも出ない**
- UI 全体（ShopView／WeekMainView／CalendarView）に「4週ごとに14万」の説明が無い。谷口の台詞（DialogueData.swift:99）だけ。
- 直し方の案：週メインの所持金の下に「次の支払い◯週後」を小さく出す（％は出さない）。決めが要る：要る（情報量）。

## §D DEBUG の漏れ
- 問題なし。MZ_ のフック（RootView／GameSession／FinalsPresentationView／NotebookView／TournamentResultView／WeekMainView）はすべて `#if DEBUG` の内側。`debugForcedComment` は `#else` で nil（FinalsPresentationView.swift:449-455）。🏆💪の導線は RootView.swift:216-254 の DEBUG 内。
- 小：`print("[save] ...")`（GameSession.swift:917・930）はリリースにも残る。害は小さいが `#if DEBUG` で包むとよい（決め：不要）。

## §E 遊びの穴
- 詰み：通常の遊び方では無い（`docs/stuck_and_exploit_check_v0.md` §1）。完全休養は無料で常に選べるので「何もできない週」は無い。ただし金欠の稽古偏重は夜逃げ（A-1）。実測は生活費10万時代＝再測が要る。
- 抜け道：実測では無し（同文書 §3）。コード読みで追加：
  - **E-1 [中]** ネタをしまって飽きを避ける（A-2）。
  - **E-2 [小]** 栄養ドリンク 3,000円×年6回＝体力+48（1あたり約375円）。無料の完全休養（+60）があるので強くないが、「稽古→回復」の週数が減る分は有利。`exp_items_v4.py` 系で効きは測定済みの範囲（money_balance_v1）。
  - **E-3 [小]** 稽古は体力20以上なら毎週選べる。ネタ作り（無料）連打の偏りは fun_audit_v0.md §3（稽古の偏り・空白最長12〜15週）で既知。
  - **E-4 [小]** 週次ランダムイベントは種類ごと1回制（9種）なので、`weeklyEventCap=15`（GameConfig.swift）には到達しない。3〜4年目でほぼ出尽くす。直し方の案：cap を 9 に揃えるか、年ごとに再抽選を許す。決めが要る：要る。
- 画面側のずれ：行動プレビュー previewState（GameSession.swift:281）は体力ゲート（体力<20 の稽古→休み）と「オファー無しの acceptOffer→休み」を再現しない。カードが約束した伸びと実際が違う週がある（小・直し方：resolveAction と共通の関数に寄せる／決め：不要）。

## §F テスト網の漏れ（A の補足）
- ManzaiGame 側（GameSession／SaveData／セーブの復号／startNextYear／careerOver）に自動テストが無い（GameCore/Tests のみ・126件）。
- GameCore 内で薄い所：GPエントリー費を払えない年（gpAlive=false 分岐）、飽き（tiredYears／netaTiredPenalty）の年初加算、体調ダウン抽選の境界（体力 20 ちょうど・0）、`entryFee` 不足の大会見送りは CareerLogic に1本ありGP側は無し、`growthEndYear=15` を超えた年のbudget。
- 直し方の案：上記を CoverageGapTests に足す（式・golden は触らない）。決めが要る：不要。
