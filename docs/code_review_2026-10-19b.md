# コード点検 2026-10-19b（2026-10-18 以降の ManzaiGame/Sources・GameCore/Sources 差分）

**件数：8件（確度 高 4・中 4）。** 前回 code_review_2026-10-19.md（§1〜§3）に無い物だけ。コードは変えていない。

**節構成**：§1 確度 高／§2 確度 中／§3 見たが問題なかった所

## §1 確度 高

1. **月末の支払い画面をタップで早送りしても、お金の音と（足りない時は）警告の振動が後から鳴る**
   - RentStatement.swift:122-137（`.task` 内の `try? await Task.sleep`）＋ WeekMainView.swift `presentRent`（`RentStatementView(...) { rent = nil }`）
   - 手順：月末の週に支払い画面が出る → 明細が出ている途中でタップ → `rent = nil` でビューが消え `.task` がキャンセルされる。`try?` がキャンセルを握りつぶすので sleep は即座に返り、残りが最後まで走る＝`Sound.play(.money)`（:131）と、足りない時の `.warning` 振動、`onDone()` の二度呼びが、画面を閉じた直後に出る。
   - 直し案：各 sleep の後に `if Task.isCancelled { return }` を入れる（:125-137 の4か所）。
   - 確度：高（Swift の仕様どおり）。

2. **先輩の誘い（週末に来る札）が、その週に出るはずだった一回きり・時期限定の出来事を黙って飛ばす**
   - GameSession.swift:509-514（`evaluateChoiceEventFire` の `inviteWaiting` 分岐が `return`）。呼び出しは :1222 の「freeAction になった時に1回」だけ。
   - 手順：週末に誘いが立つ（確率4%/週）→ 次の自由週の頭で、`justLostRehearsal`（`justLostStage` は行動で失効）・`preTournamentEve`（`m.week - week == 1` ぴったりの週だけ）・`justPassedFork`（`justPassedStage` は行動で失効）などの確定発火が成立していても、誘いの札が先に立って `return`。誘いを閉じても同じ週の再判定は無い＝その出来事は二度と出ない（フラグ `didFire…` も立たないので「出ていない」ことに誰も気づかない）。
   - 直し案：誘いは他の確定発火が無い週にだけ出す（`inviteWaiting` 分岐を else の末尾＝週次抽選の前へ移し、成立した確定発火があればそちらを先に出して誘いは次の自由週へ持ち越す）。
   - 確度：高（流れは読んで確認。発生頻度は低い）。

3. **予選の知らせ（トーク画面）で、最後の「やった……」の後の成功音が、画面を閉じた後に鳴ることがある**
   - QualifierNoticeView.swift:233-239（`pickOpen` の Task。ループの最後の sleep の後に isCancelled を見ずに `Sound.play(.success)`）
   - 手順：準々決勝で通過 → 返信が全部出て「つづける」が現れた直後（最後の吹き出しから0.8秒以内）に「つづける」をタップ → `finish()` が task をキャンセル → sleep が即返り、ループを抜けて `if passed { Sound.play(.success) }` が次の画面で鳴る。
   - 直し案：ループの後（:239 の前）に `if Task.isCancelled { return }`。
   - 確度：高（音だけ・害は小さい）。

4. **用語集の「生活費」が固定の14万円のまま＝部屋・特技「やりくり上手」で実額と食い違う**
   - SettingsView.swift:227（`GameConfig().livingCost / 10_000`）。実際の引き落としは `GameEngine.livingCostDue`（部屋の上乗せ＋やりくり上手の×0.95）。
   - 手順：タワーマンションに引っ越す（上乗せ15万円）→ 設定 → 用語集の「所持金と生活費」には「14万円」と出るが、実際は29万円引かれる。
   - 直し案：`GameEngine.livingCostDue(session.state, …)` を渡して文を作る（またはあえて「基本は14万円。部屋によって増える」と書く）。GlossaryView が session を持たないなら後者。
   - 確度：高（ずれること自体）。

## §2 確度 中

5. **オフラインで起動すると、設定画面の「購入」欄に何もしていないのに「商品情報を取得できませんでした」が出続ける**
   - StoreManager.swift:41（`refresh()` の catch で `lastMessage` を立てる。消す所が無い）＋ SettingsView.swift:47
   - 手順：機内モードで起動 → 設定を開く（`StoreManager.shared` が初めて作られ、init の `Task { await refresh() }` が失敗）→ 購入欄の下に赤字ではない説明文が常に出る。購入UIはまだ無いので、押す物の無い警告になる。「復元」を押してキャンセルした時も「通信状況を…」と出て、実際はキャンセルでも同じ文になる（:78）。
   - 直し案：`refresh()` の失敗では `lastMessage` を立てない（購入・復元を押した時の失敗だけ立てる）／`restore()` は `AppStore.sync()` の `StoreKitError.userCancelled` を除く。
   - 確度：中（実機の挙動は未確認）。

6. **StoreManager が設定画面か衣装着用まで作られない＝`Transaction.updates` を起動時に聞いていない**
   - StoreManager.swift:21-26（init で updates を購読）＋ 使用箇所は SettingsView.swift:17 と Store/StageOutfit.swift:27 のみ（StageOutfit は standard 以外の時だけ触る）
   - 手順：今は購入UIが無く `purchase()` の呼び手も無いので実害なし。購入UIを足した後、承認待ち（ask to buy）や他端末の購入が、設定を開くまで finish されない。
   - 直し案：アプリ起動時（App の init か RootView の `.task`）に `_ = StoreManager.shared` を一度触る。
   - 確度：中（購入UI追加時に起きる）。

7. **オファーの「テレビ慣れ」（センス・表現 −0.5）が、画面のどこにも出ない**
   - CommandData.swift:136（`fatigued` を受け取るが未使用）／WeekMainView.swift:145（`session.offerFatigued` を渡している）／:1039（`row` の札は効果ピルを出さない）／offerPickCard（名前・収入・一言のみ）
   - 手順：直近6週に4回オファーを受けた後、5回目を受けると能力が下がる。しかし帯（row）にも札にも効果ピルが無く、谷口の一言も ff5e6ae で外した＝プレイヤーは理由なく能力が減るのを見る（previewState には載せたが表示先が無い）。
   - 直し案：オファー帯に `fatigued` の時だけ「センス・表現 −」の小さな一行を足す（谷口の台詞は使わず、地の文か効果ピルで）。または未使用の引数と `offerFatigued` を消し、意図して隠すと決める。
   - 確度：中（オーナーが一言を外したのは確かだが、効果の表示まで外す意図かは不明）。

8. **WeekHint の体調ダウン警告線が 50.0 の直書き（`GameConfig.injuryThreshold` と別管理）**
   - WeekHint.swift:29（`injuryWarn = 50.0`）／:34 と :36 に同じ `if i.money < 0` が2回（:36 は到達しない）
   - 手順：いまは両方50で一致。injuryThreshold を調整（この数日で 20→50 に動いた）すると、「無理すると倒れるで」が出る線だけ古いまま残る。
   - 直し案：`Input` に `injuryThreshold` を足して `config.injuryThreshold` を渡す。:36 は削除。
   - 確度：中（今は食い違わない）。

## §3 見たが問題なかった所

- 強制アンラップ・`as!`・`try!`・配列の範囲外：新規差分（658fff0^..HEAD）に無し。`config.gpLossCompat[gpStage]`（count 検査あり）・`roomHeals[room]`（count 検査あり）・`ShopView.roomNames[min(max(room,0),count-1)]`・`NetaStage.names[idx]`（0〜3）は安全。
- DEBUG 限定のはずの物：`environment[` / `MZ_*` の参照は全て `#if DEBUG` の中（MZ_COSTUME、MZ_QUAL_LONG、MZ_FANREPORT、MZ_PICKUP、MZ_FIN、MZ_OPEN、MZ_HOLD_AT 等）。`debugUntilOffer` / `debugAdvanceToTournamentEntry` / `debugUntilInjury` も DEBUG 内。本編に漏れていない。
- FinalistAnnounceView：skipAll は task をキャンセルしてから stage を直接 `.after` にする。run() の各 sleep 後に isCancelled を見ており、音の取りこぼしは無い。`arr.swapAt(si, count/2 + count/4)` は 15/16 件で 10/12 番目＝範囲内。
- onFinish の二度呼び（飛ばす／つづけるの連打）：呼び先は `qualDone = true` / `announceDone = true` で冪等。
- 体調ダウンの知らせ：StageViews（入口）と WeekMainView（自由週）の両方に出口があり、`clearInjuryNotice` で1回だけ。条件が合わない週は次の機会に持ち越されるだけで失われない。
- 部屋・やりくり上手の支払い額：`livingCostDue` に一本化済みで、WeekHint・RentStatement・用語ヒント（livingHint）・GameSession.lastLivingPaid は一致（用語集 SettingsView だけ §1-4）。
- オファー札の選び：`chooseOffer` は範囲外 index を無視。`offerPick` は週替わりで 0 に戻る。スナップショットの `offerChoices` は名前で config の札に差し替えるので保存形式が変わっても落ちない。
- 特技を覚える確認ダイアログ：連打しても二度目は `canLearn` が false で費用は二重に引かれない。
- 軽い体裁（バグではない）：GameEngine.swift:173 の `@discardableResult` は次の doc コメントをはさんで `livingCostDue` に付いており、`moveRoom` には付いていない（呼び手は戻り値を使っているので警告も出ない）。
