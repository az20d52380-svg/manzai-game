# コード点検 2026-10-19h（FinalsPresentationView.swift 通読・7回目）

**件数：3件（確度 高 2・中 1）。** 19d・review_today_fixes_1019 に載った物は除く。コードは変えていない。
**節構成**：§1 確度 高／§2 確度 中／§3 見たが問題なかった所

## §1 確度 高

1. **出番くじの心拍（ドクン×4）が、番組導入・開演の儀の「裏」で先に終わってしまう**
   - FinalsPresentationView.swift:574（`lotBeat` の `.task { await runLot() }`）・:578-596。自動送りの `.task(id: autoKey)`（:271）は `guard ceremonyDone` で待つが、`runLot` には待ちが無い。`beat` の初期値が `.lot` で、`body` の Group は導入オーバーレイ（:211-225）の下で `lotBeat` を描くため、画面が出た瞬間に走り出す。
   - 手順：決勝に入る→煽りV〜タイトル〜審査員席〜進出組〜開演の儀（数秒〜十数秒）を見ている間に、裏で心拍4拍（約2.8秒）が終わり `lotRevealed = true`・`Haptics.rare()`。儀が終わった時には出順が出た後で、「くじの結果を見る」の溜めは見られない。初回専用の `FinalsSeen.first("lot")` も裏で消費される。導入中に触覚だけが鳴る。
   - 直し案：`runLot` の頭で `while !ceremonyDone { try? await Task.sleep(0.1s); if Task.isCancelled { return } }`、または `.task(id: ceremonyDone)` にして `guard ceremonyDone`。
   - 確度 高（導入が1秒未満に終わる設定でない限り必ず起きる。音は鳴らないが演出の段が飛ぶ）。

2. **7審査員の「合計」が、他の画面の自組の合計（`d.total`）と食い違うことがある（高得点の優勝夜）**
   - FinalsPresentationView.swift:1249-1254（FinalsData.init）と :831（openBeat）。審査員点は「Σ = total」に補正した**後**で `max(50, min(99, ...))` に丸めるため、いずれかが99超になると Σ < total。openBeat の合計箱は `d.judges.reduce` の和（:831）を数える一方、講評の木札・暫定席・nowCard・最終ボードは `d.total` を使う。
   - 手順：自組が優勝する夜（total は 632〜668 を乱数で選ぶ。655 付近以上で base≒94〜95）。白波（bias +2）等の raw が 99.5 を超えて99に頭打ち→7人目を開いた合計が例えば「665 / 700」。直後の講評では「668点」、暫定席・ボードでも668点。
   - 直し案：clamp 後に再度 Σ を total に合わせる（99未満の人へ配る）か、`total = d.total` を openBeat の `RollingNumberText` に使い、clamp を補正の前に移す。
   - 確度 高（コード上は確実。起きる頻度は total の高い優勝夜に偏る＝中程度）。

## §2 確度 中

3. **観客モードの開始時に、一瞬だけ出番くじの Task が走り、初回専用の「フル」フラグ(`FinalsSeen "lot"`)を消費する**
   - FinalsPresentationView.swift:239-243（onAppear で `beat = .board`）・:574-580。初期の `@State beat = .lot` で最初の1フレームは `lotBeat` が作られ、その `.task { runLot }` が起動する。onAppear で `.board` に変わって取り消されても、`runLot` の先頭（:580 `FinalsSeen.first("lot")`）は取り消し検査より前に動く。
   - 手順：一度も決勝に出ていないキャリアで、予選敗退の年の第47週に観客として決勝を観る→`finals_bc_seen_lot` が true になる→翌年以降に初めて自組が決勝に出た時、出番くじが「初回フル」ではなく短縮の1拍になる。
   - 直し案：`beat` の初期値を観客かどうかで決める（`init` で `_beat = State(initialValue: spectator ? .board : .lot)`）、または `runLot` の最初に `guard !spectator, beat == .lot`。
   - 確度 中（タスク開始と取り消しの前後関係はタイミング次第。「FinalsSeen を先に消費」する経路があること自体は確実）。

## §3 見たが問題なかった所
- 溜め／残り札の Task（:357/:376/:405）：`holdingSeventh` が立つ間は `advance`／`fastForwardBeat` がともに弾くので、二重に進まない。`hushSE(true)` と `hushSE(false)` は必ず対で呼ばれる（途中で抜ける分岐なし）。
- 決着の判定：`voteOrder`（7票・勝者は4票以上）で `winCount == 4` は勝者でのみ起き、他組は最大3票。早送りでも `before < 4` で決着の一打は1回。
- 自組が最終決戦に残る/残らない：`selfDuelIndex` が nil の年（4位以下・観客）は `winner` の候補が3組、残る年で負けの夜は自組を除く2組。`champion` なら必ず `rank ≤ 3`＝`selfIdx` あり。`lastFinalMargin` は年替わりで nil に戻る（GameSession:999）ので前年の値は混ざらない。
- 配列：`d.entries[shown - 1]`・`voteOrder[i]`（7要素）・`judges[0..<7]`・`orders[i]`（npc 9 or 10 と一致）はすべて範囲内。強制アンラップは無し。
- 観客版と出場版：観客は `shown = 0`／`boardAuto = true` で開始し先の組・ネタ・採点を通らない。`champion` は `!spectator &&` 付き、`finishResult` は観客→`onFinishSpectating`、優勝→`acknowledgeWin`、負け→`acknowledgeResult`。
- 優勝の夜：`goNext` は `beat` を `.duel` のまま `showChamp` へ（`.result` の画面は挟まない）。その上のオーバーレイがタップを受けるので二重に進まない。
- BGM：`Sound.bgm(.finals)` は onAppear の1回。出た先の週画面が `.daily` に戻す（WeekMainView:308）。

## 直した所（10/19 自走・ビルド OK・目視は未）
- §1：先に 50〜99 に収めてから、50〜99 の中でだけ合計に合わせる（乱数は使わない＝出る点の並びは従来と同じ乱数から）。§2：くじは ceremonyDone の後（.task(id:)）。§3：観客版は runLot を走らせない。
- 決勝の盤面まで出す目視フックが無い（MZ_UI=ending は優勝後の S6b）＝タップできる回で優勝夜の7人の和と合計を確認する。
