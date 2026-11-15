# 直近3コミットの見直し（2026-11-15・読むだけ・コード未変更）

- 要点1：**16a3b95f3 に実害のある回帰が1件**（高）。choose の差を weekDone の summary.state で取るが、その state は applyNetaWork の「前」の写し＝ネタ作り・改稿・ネタ見せの週に lastNetaGain（Beat2 のネタの伸び）が出なくなる。
- 要点2：6c137f431 は問題なし（二重呼び出し・二重加算の経路なし・state の意味も同じ）。a280a3496 は整合しているが、画面側の newNetaTitle が残る経路が低重で1件。
- 要点3：16a3b95f3 のその他の確認点（大会週・yearDone 先着・翌週頭・残留フラグ）は問題なし。

節構成：§1 6c137f431／§2 16a3b95f3／§3 a280a3496

## §1 6c137f431（夜逃げ・解散の年末で TrophyBook.onStage）
- 問題なし：再入（二重呼び出し）。onStage は `yearHistory.last?.year != runner.year` の guard の中。pump が同じ年末に再入しても、yearHistory.append が同じ guard 内にあるので2回目は入らない。
- 問題なし：中断セーブ復元。yearDone で保存された yearHistory には当年の行が入っている（saveNow は pump 後）ので、復元後に guard へ入っても onStage を再実行しない。init(restoring:) は yearDone で pump を呼ばず出来事の積み直しもしない。
- 問題なし：recordHanaWin の二重カウント。HANA決勝の結果は weekDone を経ない週にだけここで渡る（weekResults は begin で毎週空になる・WeekRunner.swift:190。解散・夜逃げの週は weekDone を返さず yearDone を返す・:465/:470）。weekDone 側と同じ週の結果が両方から渡る経路なし。
- 問題なし：state の意味。runner.state は applyWeekEnd／applyRiftWeekEnd 後（yearDone を返す時点）で、weekDone の summary.state も同じ週末処理後。onStage が見る stamina<30・money<0・compat は同じ意味。
- 低（補足・直さなくてよい）：トロフィー保存（UserDefaults）は即時だがセーブは saveNow 後。onStage 直後〜saveNow 前に落ちると、復元で再入して recordHanaWin が1回余分に数える窓がある。ただし yearDone 経路の pump 後すぐ saveNow のため実質無視できる。

## §2 16a3b95f3（choose の差を最初の weekDone の状態で取る）

### 2-1 【重さ：高（表示の回帰）】ネタ作りの週に lastNetaGain が消える
- 場所：GameSession.swift の choose（`phase = runner.resolveAction(action)` → `applyNetaWork(for:)` → `actedWeekEndState = nil; capturingActedWeek = true; pump()`）と、`let st = actedWeekEndState ?? self.state` 以降の `st.nextNetaID`／`st.netas`。
- 原因：weekDone の WeekSummary.state は resolveAction が返す時点の値コピー。ネタの新規・改稿・ライブ（applyNetaCreate/Revise/Live）は applyNetaWork が resolveAction の「後」に runner.state へ入れる。つまり actedWeekEndState（＝summary.state）にはネタの変化が入っていない。
- 手順：ネタ作り（家・喫茶店・ファミレス）またはネタ見せ会を選ぶ → 最初の weekDone の summary.state は applyNetaWork 前 → `st.nextNetaID > before.nextNetaID` が偽、`st.netas` の polish 差も 0 → lastNetaGain = nil → 獲得バーストでネタの伸びが出ない（変更前は pump 後の self.state で取れていた）。
- 直し方（案）：ネタの差だけは `self.state`（pump 後の runner.state 由来）で取る。`lastNetaGain` の2か所の `st` を `state` に戻す（ネタ以外は療養週に動かない：ネタの polish は週末処理で変わらない）。または actedWeekEndState に applyNetaWork 後の netas/nextNetaID を上書きして持つ。前者が最小。
- 補足：テストが通ったのは lastNetaGain を見るテストが無いため（要確認）。回帰テストは「ネタ作り週の choose 後に lastNetaGain が non-nil」。

### 2-2 問題なし：大会の週・年末
- 大会週は choose（自由行動）の pump ではなく decideTournament／advanceAuto の pump。そこでは capturingActedWeek=false のため actedWeekEndState に触れない。
- choose の pump が年末に当たる週（yearDone が weekDone なしで先に来る：夜逃げ・解散）は actedWeekEndState=nil のまま `?? self.state` に落ち、変更前と同じ値（runner.state）。悪化なし。
- 自由行動の後の weekDone に大会結果が混ざる経路はない（isStage の結果は大会週のみ）。

### 2-3 問題なし：残留・誤用
- actedWeekEndState は choose の pump 直前に必ず nil に戻され、読むのも同じ choose 内だけ。capturingActedWeek は pump 直後に false。choose 内に early return／throw は無く立ちっぱなしにならない。
- decideTournament 等の別 pump では capturing=false なので残った値が使われることはない。

### 2-4 問題なし：翌週頭・生活費・オファー
- 最初の weekDone は押した週の末で、翌週頭の自動処理（イベント抽選 evaluateChoiceEventFire・掛け合い）はその後の pump 側で state を変えない（UI 層の状態のみ）。
- 生活費は `livingCostDue(st, …)` と `st.money` が同じ週末後の state で整合。オファー（受諾）は resolveAction 内で処理済みで summary.state に含まれる。
- 低（補足）：体調ダウン週は summary.state が週末処理後の体力（療養へ入る前）。狙いどおり。

## §3 a280a3496（recallNeta で枠が埋まったら writeNewNeta=false）
- 問題なし：writeNewNeta を立てる所は beginNewWrite（WeekMainView 794/850）のみ、下ろす所は applyNetaWork 2か所・setWriteNeta・今回の recallNeta。recall 後に枠が埋まれば false になり、writeTargetID は writeNetaID／勝負ネタ→無ければ nil で、WeekMainView.writeTarget の「満杯なら activeNetas.last」と applyNetaWork の `state.netas.last` に合う。
- 問題なし：recallNeta の guard が `count < slots` のため「呼び戻し後に count == slots」のときだけ下ろす判定が働き、空きが残る時は「新しく書く」を維持（意図どおり）。writeNewNeta は保存・復元されない（セッション内のみ）ので復元との不整合なし。
- 低【重さ：低】画面側の `newNetaTitle`（WeekMainView.swift:141・`@State`）が残る経路：新ネタ名の入力欄を開いたまま（newNetaTitle != nil）手帳でネタを呼び戻して枠が満杯になると、writeTarget が nil（＝「新ネタ」表示）のまま。実際は末尾の改稿。手順：週メインで「ネタを書く→新しく書く」を開く→手帳→保管庫からネタを呼び戻して枠を埋める→週メインに戻る。直し方：枠が満杯になったら表示側で `newNetaTitle` を無視する（writeTarget の先頭を `session.activeNetas.count < slots` の時だけ nil にする）。頻度は低く、書く前に画面を閉じるのが普通。
