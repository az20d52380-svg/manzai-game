# 決勝演出・舞台まわりの点検（finals_stage_audit_1115_v0）

- 要点1：新規は3件（中0・低3）。落ちる所・遅延コールバックの閉じた後の暴走・透明で押せるボタンは見つからなかった。
- 要点2：一番目立つのは低-1「出順10番（大トリ）の年に、後の組がいないのに主ボタンが『後の組を見る ▶』と出る」。他2件は無反応の窓（低-2）と、優勝の夜に使われない結果画面の死んだコード（低-3）。
- 要点3：既出と重なる物（観戦帯の文言・コンビ名の1字Text・稽古場の衣装固定・決勝演出の二度タップ・敗者復活の組数）は再掲せず、§問題なし一覧に出所だけ書いた。読むだけ・コードは直していない。

対象：FinalsPresentationView.swift（全体）・FinalsTalk.swift・StageScene.swift・StageFrame.swift と、それらが読む GameSession の値（winFinale・watchingFinal・lastFinalMargin・pendingResult・reachedFinalViaRevival・firstShow）。

## §1 指摘

### 低-1 出順10番（大トリ）の年、自組がボードに入った直後の主ボタンが「後の組を見る ▶」のまま（後の組はいない）
- 場所：FinalsPresentationView.swift:316（advanceLabel の `.board`）。関連：同 :359-361（advance の `.board where !boardAuto`）、:340〜（boardBeat の `done`）。
- 手順：出順が10番になるまでやり直す（1/10 の確率）。7審査員の講評のあと順位ボードへ進むと、自組が入った瞬間（`boardAuto == false`）の主ボタンは `!boardAuto ? "後の組を見る ▶"` になる。出順10番だと `shown == d.entries.count` で、押しても組は増えず（`if shown < d.entries.count { stepBoard() }` を通らない）、司会の「最終決戦に進むのは、この3組です！」に切り替わるだけ。次のボタンはその時点で「最終決戦へ 進む ▶」。
- 既出か：新規。docs/finals_screen_text_score_1110_v0.md・ui_copy_consistency_1026_v0.md は文言を一覧で採点しているが「後の組を見る」を○にしており、出順10番の場合は見ていない。advance 側のコメントに「大トリなら確定へ」とあるので、押した結果の動きは意図どおりで、ボタンの文言だけが合っていない。
- 直し方の案：
  ①`!boardAuto` の文言を `shown < d.entries.count ? "後の組を見る ▶" : "最終決戦へ 進む ▶"` にする（1行・表示のみ）。推奨：同じ分岐が次の行に既にあり、直す所が最小。
  ②出順10番の時は `goNext` で `boardAuto = true` にして、自組の入りの札を飛ばして確定の画面へ直行させる。流れが変わるのでオーナー判断が要る。

### 低-2 見えているのに効かないボタンの窓（押しても無反応・音も振動も出ない）
- 場所：FinalsPresentationView.swift:174（主ボタン）・:1014（最終決戦のインラインボタン）。止めている所＝:339 `guard !holdingSeventh`。窓の長さは :362-367（7人目の前0.6秒）・:381-389（王手の次の決着札の溜め0.35／0.9秒）・:409-417（決着後の残り札を自動で開く約1.1秒＋0.38秒×残り枚数）。
- 手順：採点で6人開いた後に「審査員の得点をめくる（7/7）▶」を押すと0.6秒、ボタンは見えたままで押し直しても何も起きない。最終決戦で4票目が出たあと、残り札が自動で開く約2秒の間は「次の審査員札をめくる（4/7）▶」が出続け、押しても無反応（`YoseButtonStyle(.primary, silent: true)` で押下音も無い）。
- 影響：ゲームは止まらない（自動で進む）が、「壊れた？」と連打したくなる。連打しても二重に進まないのは guard のおかげで安全（良い点）。
- 既出か：double_tap_audit_1115 #6 は「送りの二度タップで札が1枚飛ぶ」で別件。この窓の見た目は未指摘。
- 直し方の案：
  ①`holdingSeventh` の間は主ボタンとインラインボタンに `.disabled(holdingSeventh)` を付ける（見た目が薄くなり、効かないことが分かる）。推奨：1行ずつで済み、状態の流れも変わらない。
  ②決着後の自動開票中だけ、ボタン文言を「開票中…」にする。①と併用可。

### 低-3 優勝の夜は結果画面（resultBeat）に入らない＝金屏風の最明部（.winner）・舞台の二人・谷口の耳打ちが実機で出ない（未確認：意図の確認）
- 場所：FinalsPresentationView.swift:454-457（goNext が `nextBeat == .result && d.champion && !spectator` で `showChamp = true; return`、`beat` は `.duel` のまま）。影響を受ける物：:98（stageMode の `.result: d.champion ? .winner`）・:106（stagePerformers の `beat == .result && !spectator`）・:1097-1104（resultBeat の優勝側、谷口「……また、勝ったんだね」「……本当に、勝ったんだね」）。
- 手順：自組が優勝する年に、最終決戦の「優勝発表へ ▶」を押す → すぐ YoseChampionCelebrationView → 閉じると番組エンディング → `finishResult` → `acknowledgeWin`。resultBeat は一度も描かれない。DEBUG の `MZ_FIN=win` でだけ見える。
- 見え方：優勝の夜の舞台は最終決戦のままの `.judging` 暗めの金屏風で、`.winner`（最明部・光条）にならない。耳打ちの台詞（「また勝ったんだね」の連覇分岐）は優勝祝いの全画面側の `partnerLine`（session.repeatWinLine）が担うので、台詞の欠けは無い。
- 既出か：goNext のコメントに「結果発表の画面は挟まない」とあり意図的。ただし stageMode `.winner` などが死んだコードになっていることと、見えない画面に連覇の分岐が2か所（resultBeat と repeatWinLine）ある点は未指摘。
- 直し方の案：
  ①死んだ側（resultBeat の優勝分岐・stageMode の `.winner`）に「優勝の夜は通らない（DEBUG専用）」とコメントを足して放置する。推奨：実害が無く、通常の優勝画面が既に仕上がっているため。
  ②優勝の全画面の下の舞台を `.winner` に切り替える（`showChamp` を stageMode の条件に足す）。金屏風の最明部が優勝の瞬間にも出る。見た目の変更なのでオーナー判断。

## §2 問題なし一覧（確かめて問題が無かった所・既出の所）

表示と実データ
- 組数：決勝は常に10組（観客版＝他10組、自組あり＝他9組＋自組）。「／ 全10組」（:539）は固定でも一致。敗者復活を通ると他組が9組になる件は gp_final_audit_1115 #4（既出）。
- 点：自組の7審査員の点は50〜99に収めてから合計Sに合わせて補正（:1253-1262）。7×99=693≧最大668・7×50=350≦最小560でループは必ず終わる。「／700」は上限693なので誤りではない。
- 順位：他組の合計は自組の上に rank-1 組・下に残りを置き、同点は重複回避（:1274-1279）。上方向の繰り上げでも最大 668+22=690＋数点で700は超えない（確認済み）。
- 最終決戦の票：勝者が4票未満の時は最終補正で4票以上にし、4票目で決着の演出（:396）と一致（:1352-1362）。自組が優勝＝4票以上、負け＝3票以下かつ首位でない（:1328-1348）。勝者の添字が 0..<3 の範囲外になる経路は無い。
- 15年目（GameConfig.careerYears）：画面は「結成\(session.year)年目」を出すだけで年数の上限に依らない。
- 旧セーブで margin が nil の時：優勝＝仮に6、負け＝-12 として順位を決める（:1203-1214）。惜敗側（-4以上）に入らず「1本目で敗退」の見せ方になる。値の読み出しは pendingResult → lastFinalMargin の順で、復元後も weekResults から引き直す（GameSession.swift:290）。
- 女コンビ（THE HANA）：HANA の決勝は結果名が「GP決勝」ではない別名のため、RootView:429 の分岐（`r.name == "GP決勝"`）で FinalsPresentationView には来ない（hana_audit_1115 の範囲）。

落ちうる所
- 配列の添字：`d.entries[shown - 1]` は shown が1以上かつ entries 数以下の時だけ（:330-331・:606・:968）。`d.voteOrder[i]` は 0..<7 で、voteOrder は常に7件（:1370）。`d.judges[i]` は常に7件。`commentPicks` は空なら `[]`、`picks.indices.contains(i)` で守っている。
- 強制アンラップ：`cands.max {…}!`（:1349）は cands が常に3件（selfIdx==nil）か2件で空にならない。0割りは無し。
- 乱数：`SeededRng.int` は範囲が空にならない呼び方のみ。

二度押し・中断・閉じた後の遅延
- 二度押し：`holdingSeventh` の guard が7人目前・王手・決着後の自動開票・長押しの早送りを止めている（:339・:441）。`acknowledgeResult` は `pendingResult != nil` で、`finishWatchingFinal` は `watchingFinal` で、二重呼びを止めている。`acknowledgeWin` は二度呼ばれても `winFinale=false／finished=true／saveNow` の再実行だけで害なし。
- 遅延コールバック：Task.sleep はすべて `.task`（取り消される）か、`voteTailTask`（onDisappear で cancel）。取り消しなしの `Task {}` は :362・:381 の2か所で、どちらも0.35〜0.9秒後に `hushSE(false)` と1枚めくり。この間に画面が閉じる経路は無い（閉じるのは結果の最後のボタンだけ）ので、実害の経路は見つからなかった。asyncAfter・Timer は無し。
- 中断復元：優勝の夜は yearDone＋`winAcknowledged != true` で `winFinale` に戻り、決勝演出を頭から出し直す（GameSession.swift:293-297・設計どおり）。負けの夜は pendingResult が保存・復元される。観客版は `didWatchFinal` で二度出ない。
- 透明で押せるボタン：`opacity(lotRevealed ? 1 : 0)`（:576）は司会の吹き出しだけでボタンではない。StageFrame の FlipCard の `front/back.opacity` はボタンを含まない。StageFrame 本体は `allowsHitTesting(false)`。
- 開演の儀・番組導入：overlay は `onTapGesture` の後ろに付いているので、タップは儀の `finish` だけに届き `advance` へ抜けない。儀の `done` と取り消しの扱い（abandon）は cancelled_sleep_audit_1115 #1 で済み。

既出（再掲しない）
- 観戦帯「予選敗退のため」：docs/finals_screen_text_score_1110_v0.md 既出・候補ブランチ claude/finals-screen-text-fix-cand（オーナー判断待ち）。
- コンビ名・相方名の縦書き1字Text（「俺」の字が置き換わる・谷口が化ける）：name_substitution_audit_1115 #1、AUTOPILOT 461 の候補で対応中。決勝では StageMakuri（StageFrame.swift:473）・出番札（FinalsPresentationView.swift:552-557）・票札（:1063）が該当。
- 稽古場（StageScene.swift:74,76）の衣装が `StageOutfit.standard` 固定：costume_audit_1115 #1。決勝の舞台（StageFrame.swift:135）は `StageOutfit.current` を毎回引くので問題なし。
- 決勝演出の送りの二度タップで審査員札が1枚飛ぶ：double_tap_audit_1115 #6。番組導入の最初の場面を飛ばす件：qualifier_finals_intro_audit_1115 低-3。
- 敗者復活→優勝の年の t21・lossStreak・決勝後の夜逃げ：gp_final_audit_1115 #1〜#3。講評の文が大会の種類を知らない件：result_screen_audit_1115 #2。

意図どおりと判断（直さなくてよい）
- 最低点の審査員への「少し辛めでした」は、7人の中の相対比較（最高点との差が小さい年でも出る）。司会の言い回しとして問題なし。
- 観客版で FinalsSeen の「duel／ending」の初回フルを使い切る件：観客版は決勝の全場面を実際に見るので、初回フルの印を消費するのは自然（出番くじだけは観客版に無いので :554 で消費を避けている）。
- `UIScreen.main.bounds.width` で札の幅を決める（:858）：iPad のスプリットビューでは画面全体の幅が使われるが、iPhone 専用なら無関係（iPad 対応の有無は未確認のため指摘のみ）。
