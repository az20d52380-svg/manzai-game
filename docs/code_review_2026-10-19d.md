# コード点検 2026-10-19d（TournamentResultView・FinalsPresentationView・NotebookView・ShopView・YearResultView の通読・3回目）

**件数：3件（確度 高 1・中 2）。** 19・19b・19c に無い物だけ。コードは変えていない。
**節構成**：§1 確度 高／§2 確度 中／§3 見たが問題なかった所

## §1 確度 高

1. **決勝の「ネタ」の場面を0.8秒以内にタップで送ると、次の採点の場面で「大歓声」が鳴る**
   - FinalsPresentationView.swift:615-621（performBeat の `.onAppear`）。`Task { sleep 0.8s; Sound.play(.cheerBig) }` を投げっぱなしにしている。`.task(id: autoKey)`（:271）は場面が変わると取り消されるが、この Task は別物で取り消されない。
   - 手順：決勝で出番くじ〜先の組を送って「ネタ」の場面に入る→0.8秒以内にタップ（advance → goNext で `.open`）→採点画面の頭で cheerBig が鳴る（初回の扉演出は3.35秒あるので、早く送る人ほど当たる）。
   - 直し案：`.task { try? await Task.sleep(0.8s); if !Task.isCancelled { Sound.play(.cheerBig) } }` に替える（`.onAppear` の Task をやめて `.task` に）。
   - 確度 高（音だけ・状態は壊れない）。

## §2 確度 中

2. **結果画面の「次へ 進む」／通過の祝い／山場の最終ページを素早く2回タップすると、週が1つ飛ぶ**
   - TournamentResultView.swift:164-165（次へ ボタン）・:272（showPass の閉じ）・:556（山場の最終ページ `onTapGesture`）→ GameSession.swift:896 `acknowledgeResult()`。ここに `pendingResult != nil` の検査が無く、`runner.begin()`（WeekRunner.swift:155）は呼ぶたびに `week += 1` する（冪等でない）。
   - 手順：結果画面で「次へ 進む ▶」を、画面が入れ替わる前（1フレーム〜遷移中）に2回タップ→1回目で次の週へ進み、2回目がもう一度 begin() を呼んで1週ぶんを飛ばす（次の週の大会結果が pendingResult に出ていれば、それも見ずに閉じる）。
   - 直し案：`acknowledgeResult()` の先頭に `guard pendingResult != nil else { return }`。
   - 確度 中（遷移の速さ次第。ガードが無いこと自体は確実）。
   - 補足：:557 の山場ページは `onTapGesture` に `Sound.play(.cursor)` も付いており、2回目で音も鳴る。

3. **年の結果画面で、表示から0.4秒以内に「◯年目へ ▶」を押すと、遅れて優勝ファンファーレ・判の音が鳴る**
   - YearResultView.swift:64-69。`DispatchQueue.main.asyncAfter(0.4)` は画面が消えても取り消されない（`stampIn = true`・`Haptics.confirm()`・優勝年なら `confettiFire += 1; Sound.play(.fanfare)`）。
   - 手順：優勝の年の結果画面が出た直後に主ボタンを押す→次の年の週画面で、遅れてファンファーレが鳴る。
   - 直し案：`.task { try? await Task.sleep(0.4s); if Task.isCancelled { return } ...同じ処理 }` に替える。
   - 確度 中（ボタンが画面下で、押すのが0.4秒内になるのは稀。窓は短い）。

## §3 見たが問題なかった所
- TournamentResultView の開示列：`revealTask` は `onDisappear` で取り消し、`runReveal`／`runFanVoices`／`pause` の各 sleep の後に `isCancelled` を見て戻る。`beginReveal` は `revealTask == nil` で二重起動しない。`finishReveal` 後に判の音が遅れて鳴ることも無い。
- FinalsBroadcastEnding の出口（`finish()` に `done` ガード）・YosePassCelebrationView（`done` ガード）：二度呼びにならない。FinalsPresentationView の `showEnding` の出口も上記の `done` で冪等。
- FinalsPresentationView の自動送り `.task(id: autoKey)`：`beat == .perform` と `isCancelled` を見てから goNext するので、手動タップとの二重送りは起きない。決着後の残り札の Task（:404）・溜めの Task（:357/:376）は `holdingSeventh` が立つ間 advance／長押しが効かないので、途中で場面が進まない。
- 長押し早送り（fastForwardBeat）：`holdingSeventh` で守られ、場面は飛ばさない。`revealVotes = 7` の時の決着音は `before < 4` で1回だけ。
- 配列の範囲外・強制アンラップ：`d.entries[shown - 1]` は全て `shown >= 1` を確認済み（:325/:326/:467/:600/:972）。`voteOrder[revealVotes]` は `revealVotes < 7` の枝の中。`summary.results.last!`（TournamentResultView:45）は GameSession.pump の `!big.isEmpty` で保証済み（コメント通り）。`roomRents[i]` は部屋名と同数。
- DEBUG 限定：これら5ファイルの `environment[`／`MZ_*` は全て `#if DEBUG` の中（`debugForceFanReport` は #else で false）。
- お店：`canBuy` が disabled を決め、`buyItem` が false なら `purchases` に積まない。連打で二重に買えるのは在庫・金額が `canBuy` と `applyItemPurchase` の両方で検査されるので不可。「戻す」は起点（visitStart）から買い直すだけで、引っ越しは起点の部屋も更新済み（19 §1-1）。買い物は即セーブしないが、RootView の scenePhase(.background) 保存が拾う。
- NotebookView：改名は `renameNeta` が空文字を弾く。型変更・しまう・勝負ネタは各々 saveNow 済み。戦績の通算賞金は log（その年の分・万）＋yearHistory の円÷10000 で単位が揃い、年が明けると log は空になる（GameSession.swift:987）ので二重計上しない（年の途中で ノートは開けるが、yearDone〜次年開始の間は開けない）。
