# キャリア最後の年末でセーブが先に消える件：案（v0）

材料づくりのみ（コードは変えていない）。出所：docs/code_review_2026-10-19i.md §1／AUTOPILOT キュー117。決めるのはオーナー。

## §1 今の流れ
キャリアの区切り（優勝＝勇退・夜逃げ・解散・10年満了）は `GameSession.careerOver`（GameSession.swift:978）で判定。年末に入ると `finished=true`（優勝だけは先に `winFinale`、「次へ」の `acknowledgeWin` :955 で `finished=true`）になり、その直後の `saveNow()`（:1116）が `guard !abandoned, !(finished && careerOver)` に当たって **セーブを削除**する（:1122）。区切りでない年末は年末画面用にセーブを残し、復元 init（:228〜）は `phase=.yearDone` から `finished=true`（優勝は `winFinale=true`）を作り直す＝この復元の道は「区切りの年末」でも通せる形になっている。RootView は `finished` で年末リザルト（YearResultView）を出し、「エンディングへ」（`onEnding`）で `showEnding=true` → EndingFlowView（RootView:358〜）。図鑑の記録は EndingFlowView の `onAppear`（EndingViews.swift:51、`replay`/`record=false` では書かない、`recorded` で再入防止）でだけ `EndingBook.record`（Endings.swift:204）が呼ばれる。回数は「その id の既存レコードがあれば `count += 1`、無ければ count=1 で初回日付を作る」＝呼ぶたびに +1（べき等ではない）。結果、年末リザルトで「エンディングへ」を押す前に落ちると、セーブは無く、図鑑にも載らず、周が無言で消える。起きるのは区切りの年末で落ちた時だけ。

## §2 案

### A：セーブを消すのをエンディングに入った時まで遅らせる
- 変える所：GameSession.swift（`saveNow` の削除条件から `finished && careerOver` を外し、「エンディング入場済み」フラグ `careerClosed` で消す／`clearSaveForEnding()` を足す）、RootView.swift（`showEnding=true` にする所と `returnToTitle`／YearResultView の `onRestart`＝エンディング無し（endingID=nil）の出口でも消す）。復元 init はほぼ変更不要（`.yearDone` から `finished` を作る道が既にある）。
- 旧セーブ互換：問題なし。フィールド追加なし（フラグは非保存でよい）。旧版が区切りの年末で作ったセーブは元々存在しない。
- 危険：①`clearSave` 後に scenePhase(.background) の `saveNow()` が走ると、条件を外した分セーブを書き直してしまう→フラグでガード必須。②消し忘れ：エンディング無しの出口（endingID=nil、夜逃げ等で `onEnding` が nil）で消さないとゾンビセーブが残り、起動のたびに年末画面が出る。③区切りの年末の復元で優勝は `winFinale` から出直し（演出をもう一度見る）。④落ちる窓は「エンディング入場〜図鑑記録」の間だけに縮む（同じ瞬間に消去と記録をするので整合）。DEBUG の自動走行（soak・MZ_ENDING）は書かない既存ガードのまま。
- 手間：中（実装 30〜60 行・出口の漏れ確認・復元の目視／スモーク追加）。

### B：年末の時点で図鑑に記録し、エンディング画面の記録は二重にしない
- 変える所：GameSession.swift（`finished && careerOver` になる3か所＝:254 付近の通常、`acknowledgeWin`、夜逃げ・解散の終端で `EndingBook.record` を呼び、非保存の `endingRecorded` を立てる）、EndingViews.swift（onAppear の記録を `session.endingRecorded` なら飛ばす）。セーブ削除は今のまま。
- 旧セーブ互換：問題なし（保存形式は変えない）。
- 危険：①`record` は呼ぶたび +1 なので、フラグを取りこぼすと二重カウント（3か所の入口に漏れが出やすい）。②周そのもの（キャリアの続き）は救われない。記録だけ残る＝「エンディングを見ていないのに図鑑に載る」「年末リザルトで『やめる』を押しても載る」という意味の変化が出る。③`Names.partner` が年末時点の名前になる（現行と同じはず）。
- 手間：小〜中（20〜40 行・テストはカウントの二重化確認が要る）。

### C：今のまま
- 変える所：なし。旧セーブ互換：該当なし。
- 危険：区切りの年末で落ちると周と図鑑記録が無言で消える（コード点検 §1 の実害）。ただし頻度は低い（区切りの年末の一画面で、押す前に落ちた時だけ）。
- 手間：なし。

## §3 推奨
**A**。理由：図鑑の記録だけでなく周そのものも救え（B は記録しか救えず、見ていないエンディングが載る意味の変化もある）、復元 init が既に「年末画面を出し直す」道を持つので追加の経路が少ない。注意点は「`careerClosed` フラグで background の再書き込みを止める」「エンディング無しの出口でも必ず消す」の2点。B は手間が小さい代わりに二重カウントの危険がある。落ちる確率が低いなら C のままも妥当（その場合は点検 §1 を「許容」と記録）。

## 候補（10/26）
- 案A をブランチ `claude/career-end-save-candidate`（9ebb441）に実装。GameSession.saveNow の削除条件を `careerClosed` に替え、closeCareer() を RootView の onEnding と returnToTitle（年末で区切った時）で呼ぶ。テスト：区切りの年末でセーブが残る・復元すると同じ結末へ進める・閉じた後は書き戻さない。既存テスト SessionGap1025f の「優勝後はセーブが消える」を案Aの仕様に合わせた。
