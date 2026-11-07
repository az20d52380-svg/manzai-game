# コード点検 11/07d（今日のコミット全体・読み取りのみ。1107/b/c の項目は除く）

範囲：89325d6 の親..HEAD の ManzaiGame/Sources（GameCore/Sources は今日の差分なし）。
読んだ所：Meta.swift 全体／GachaState・GachaStore・StageOutfit・GachaView 全体／StoreManager 差分／FirstStageView 全体／GameSession・IntroFlow・TournamentResultView・CalendarView・NotebookView・QualifierNoticeView・StageViews・YearResultView・EndingViews・WeekMainView・SettingsView・ShopView・RootView の差分。

| # | ファイル:行 | 具体的に何が起きるか | 重さ | 直し方の案 |
|---|---|---|---|---|
| 1 | FirstStageView.swift:149〜153 `wait`（`try? await Task.sleep`）と :134〜139 `start()`／:141 `press()` | `wait` は取り消されても例外を握りつぶして即戻る。2周目以降の「とばす ▶」（:84 で `task?.cancel()`）や画面が閉じた時の `onDisappear` で start 側の Task が取り消されると、待ちが飛んで `phase = .ready` → `press()` が呼ばれる（`pressed` はまだ false）。`press()` は取り消されていない新しい Task を作るので、画面が第1週に移った後も約8秒間、`.don`・`.cheerBig`・`.taiko`・`.applauseSmall` と触覚が鳴り続ける。確かめた事：コードの流れ。実機で音が出るかは未確認。 | 中 | `wait` を `try await` にして取り消しで抜ける／各段の前に `guard !Task.isCancelled`。`press()` の頭にも `guard !Task.isCancelled`。 |
| 2 | GachaState.swift:180〜193 `merged`（`loginStamps`/`lastLoginDay` は max、`freeTickets` は「回数が多い側」） | 同じ回数の2台で片方が7枚目の札を取って無料券+1・札0に戻った後に合流すると、札は max で6に戻り、無料券は同点時に自分側（self）が残る。self が古い側なら取った無料1回が消え、新しい側なら札6が残って翌日の7枚目でもう1回もらえる（二重取り）。確かめた事：コード上の組み合わせ。実際に iCloud でこの順になる頻度は未確認。 | 低 | 札と無料券を同じ「新しい側」から丸ごと採る（`lastLoginDay` の新しい側の `loginStamps`・`freeTickets` を使う）。式・乱数には触れない。 |

## 確かめて問題なしだった点
- 周回の記録（Meta.swift）：`fastestWinYear` の `Int.max` 比較、`hanaWins` が nil の旧データ、`CareerRecords` の欠けたキー（Optional）はいずれも読み込めて落ちない。
- GameSession の pump：`.weekDone` は `acknowledgeResult` が `phase` を進めてから再入するので、トロフィーの判定・六冠の数え（smallEntered/smallWon）は二重に積まれない。`.yearDone` の `onYearEnd` は再入しても award が冪等。連覇の記録は `didRecordChampion` で一度だけ。
- 大会結果の経験点の行：`decideTournament`／`advanceAuto` のどちらの経路でも `lastResultExpDelta` を更新している（HANA 動画審査も `tournamentDecision` 経由）。古い増分が残る経路は見つからなかった。
- StageOutfit.current の `MainActor.assumeIsolated`：呼び出しは StageFrame の body と GachaView の @State 初期値だけ（どちらも main）。
- 旧セーブ：`YearRecord.hanaReach` は Optional で欠けても読める。GameCore に今日の差分はなく SaveData の形は変わらない。
- 購入：`StoreManager.handle` は取引IDで付与し finish の前に付与＝取りこぼし・二重付与は台帳で防がれる。
- DEBUG 漏れ：新規の `MZ_TROPHIES`・`MZ_COSTUME` は `#if DEBUG` 内。TournamentResultView の `MZ_UI`（result_done 等）と RootView の目視 case は環境変数が無ければ動かず、挙動に影響しない（既存と同じ作り）。

## 未確認
- `GameSession.hanaReach(log:)`：出来事ログの行の実際の書式（「THE HANA 1回戦 通過」の語順）を確かめていない。w[1] が結果語でないと年表の1行が崩れる可能性。
- t15/t16（体力・所持金の条件）は `summary.state`（週末処理後）で判定している。条件の意味どおりかは設計意図を未確認。
- 中断復帰した年は smallEntered/smallWon が 0 から数え直し（コメントどおりの仕様）。六冠が取りにくくなるだけで壊れはしない。
- `ShareCard` の ImageRenderer と `.task` の件は 1107b #10・#11 の続きなので扱っていない。
- WeekMainView の差分のうち MZSpeed 置換以外は上記の数行のみ確認。大会入口（StageViews）の動画審査の分岐は文言のみで、動作の追跡はしていない。

## 対応（11/07 定期の回・親）
- 直した：#1（待ちが取り消されたら、その先の音・振動・画面の変化を止める）。音が実機で止まることは未確認（試験は通した）。
- 未対応：#2（ガチャの保存の合流＝課金まわりで形式に触るのでオーナー確認の後。code_review_1107b の #2〜#4 と同じ扱い）。
