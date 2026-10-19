# コード点検 2026-10-19e（IntroFlow・AbilityUpView・CalendarView・EndingViews/EndingFlowView・SettingsView・RootView・ShopView の通読・4回目）

読み取り専用。件数：5件（確度 高 1・中 4）。既出（-19・b・c・d）は除いた。

## §1 確度 高

1. **IntroFlow.swift:586〜（「結成する！」の `.disabled(name.isEmpty)`）と :637 `decide()`** — 空白だけの名前で押しても何も起きない
   - 手順：コンビ名欄にスペースだけ（または全角スペース）を入れる → `name.isEmpty` は false なのでボタンは押せる色・朱の案内文も消える → 押すと `decide()` が trim して空になり `guard` で黙って戻る。画面は無反応。
   - 直し案：`.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)` と案内文の条件も同じ trim 後の判定にそろえる。
   - 確度：高

## §2 確度 中

2. **IntroFlow.swift:642 `decide()` の `asyncAfter(0.45)`** — 二重に onDecide が走る
   - 手順：名前を入れて「結成する！」を押した直後（0.45秒以内）にキーボードの「完了」（`.onSubmit(decide)`）またはもう一度ボタンを押す → `onDecide` が2回呼ばれ、RootView が `GameSession(seed: .random…)` を2回作って差し替える（1回目の seed は捨てられる）。0.45秒の間は名前欄も編集でき、発火時の値（編集後）が使われる。実害は小さい（乱数の seed が入れ替わるだけ）。
   - 直し案：`@State private var decided = false` を足し、`decide()` 冒頭で `guard !decided`・立てる。
   - 確度：中

3. **CalendarView.swift:160〜162 `showToast`** — 先のトーストの消去タイマーが後のトーストを早く消す
   - 手順：過去週を長押し（トースト表示）→ 1秒後に別の過去週を長押し → 最初の `asyncAfter(1.6)` が 0.6 秒後に発火し、2つ目のトーストが短く消える。
   - 直し案：`toastToken = UUID()` を持ち、発火時に同じ token の時だけ `toast = nil`（または Task を保持して cancel）。
   - 確度：中

4. **AbilityUpView.swift:432〜435 `confirm()`** — 「確定」の二重タップで同じ割り振りを2回適用しうる
   - 手順：＋を押して `taps` を積む → 「確定」を同じフレームで2回タップ → `allocate(taps)` が `taps` を空にしないまま `onClose()`（親の `showAllocation=false` は次の描画まで反映されない）→ 2回目の `allocate` が同じ taps で `pourStep` を再度回す。経験点に余りがあれば、押していない段まで余計に消費して能力が上がる（足りなければ pourStep が何もしないので無害）。
   - 直し案：`confirm()` で `let t = taps; taps.removeAll(); if !t.isEmpty { session.allocate(t) }; onClose()` の順にする。
   - 確度：中

5. **ShopView.swift:171〜183 `buy`/`undo` ＋ GameSession.swift:835〜863 `buyItem`/`replayShopVisit`** — 買い物・「戻す」が保存されない（`saveNow()` なし）
   - 手順：お店で買う（または戻す）→ とじる → 次の行動（週送り）の前にアプリがクラッシュ／強制終了（バックグラウンド経由でない落ち方）→ 再起動で買う前（戻す前）の状態に巻き戻る。`moveRoom`・`learnSkill`・`allocate` は保存するが、買い物だけ保存しない。通常の終了は scenePhase の `.background` で保存されるので影響は限定的。
   - 直し案：`buyItem` の成功後と `replayShopVisit` の末尾に `saveNow()`（乱数非消費・golden 不変）。
   - 確度：中

## §3 見たが問題なかった所

- 新周回（もう一度／やめてタイトルへ）：`returnToTitle()` と `onChange(of: abandoned)` はどちらも `GameSession()` を作り直し、その init で `Names.set(nil,nil)` が呼ばれて名前の static が戻る。`showEnding`・`yearTurn` も出口で nil/false。前の周の状態の残りは見つからなかった。
- 年の幕間「◯年目へ」の二重タップ：`startNextYear()` が `guard finished, !careerOver, let o = outcome` で守られ、1回目で `finished=false` になるので2年進みはしない。
- EndingFlowView：`recorded` で onAppear の二重記録を防止。`cards.isEmpty`（#7）は `Color.clear` で守られ範囲外なし。図鑑の読み返しは `replay=true` で記録しない。`ReminiscencePlayer` は `cards[safe:] ?? cards[0]` で、空配列は呼び側で除外済み。
- DEBUG 限定の漏れ：IntroFlow・AbilityUpView・EndingViews・SettingsView・RootView・Endings の `ProcessInfo` 参照はすべて `#if DEBUG` 内（`#if`/`#endif` の数も一致）。本編への漏れなし。
- AbilityUpView の `.task` 内 `Task.sleep` は、閉じた後に `hint = …` を立てるがビューは破棄済みで実害なし。`plusTap` の `Task` も同様（bumped/flash を触るだけ）。
- ShopView の「戻す」：`visitStart.room` を引っ越し時に更新しているため、引っ越し後に戻しても部屋は巻き戻らない（-19 §1-1 の直しが効いている）。`roomRents`（3要素）と `roomNames`（3要素）の長さは一致。
- CalendarView：`gpRoundNames[i]` は範囲チェック済み。週数 48 固定のグリッドは `config.weeks = 48` と一致。

## 直した所（10/19 自走・ビルド OK）
- §1〜§5 すべて直し案どおり（空白だけの名前・二重の結成・トーストの消去・確定の二度押し・お店の保存）。タップでの確認は未。
