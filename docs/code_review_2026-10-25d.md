# コード点検 10/25d（本番で落ちうる所）

対象: `ManzaiGame/Sources/*.swift`（48本）＋ `GameCore/Sources`（計76ファイル・約26,000行）。`#if DEBUG` 内・debug* 関数・MZ_ 環境変数フック・Tests は除外。読むだけでコードは未修正。

## 結論
確度 高 は 0 件。確度 中 は 1 件（保存データと更新後の日程表がずれた場合のみ）。残りは前提で守られている。

候補（除外後）: 強制アンラップ 3、`precondition` 1、添字 65、`Int(Double)` 64、剰余・割り算 18、Range 約215（うち変数の端を持つもの約15を精読）。合計 約 365。

## §1 確度 高（0 件）
なし。

## §2 確度 中（1 件）
- **GameCore/WeekRunner.swift:221 `cal.gpRounds[gpStage]`**（と GameSession.swift:676 の `runner.gpRoundsPassed..<cal.gpRounds.count`）。
  - 落ちる状態: 保存した `gpStage`（`WeekRunnerSnapshot` に入っている）が、アプリ更新で GP の回戦数 `calendar.gpRounds.count` を減らした後の値より大きいとき。
  - 通常は `isGPAlive`（`gpStage < count`）で守られている。ただし 676 は `isGPAlive` が真のときだけ通るので安全。221 は `.round` に入る前の判定が 343 行の `gpStage < count` に依存している。更新で回戦数を減らす変更をしない限り起きない。
  - 直し案: `WeekRunner(restoring:)` で `gpStage = min(snap.gpStage, config.calendar.gpRounds.count)` に丸める（`gpAlive` は保存値のまま）。もしくは 221 を `guard cal.gpRounds.indices.contains(gpStage)` にする。

## §3 確度 低（前提で守られている）
- `!` 3件: TournamentResultView.swift:49 `results.last!`（`pump()` の `!big.isEmpty` で非空が保証・コメントあり）／GameEngine.swift:272 `second == nil || second!`（直前の nil 判定で短絡）／JudgeTalk.swift:142 `vocab[nil]!`（`nil:` キーが辞書リテラルに必ずある）。
- `precondition(year >= 1)`（WeekRunner.swift:119）: 呼び出しは `year: 1` と `year + 1` だけ。保存から戻す経路（`init(restoring:)`）は通らない。
- 添字: 剰余の添字は `((x % n) + n) % n` か、`mix()`（`UInt64 % Int.max` で非負）で負にならない。`min(x, count - 1)` でクランプしている（GameSession.swift:595・GameEngine.swift:231）。`ForEach(0..<7)` や `0..<4` の固定個数は、審査員が7人固定（`JudgeScore` を `zip(specs, ints)` で作る）・`voteOrder` が7票固定で合う。`d.voteOrder[revealVotes]` は `revealVotes < 7` の分岐内（FinalsPresentationView.swift:370-373）。`banterBox` は呼び出し側で `!lines.isEmpty` を確認済み。`ShopView` の `roomRents[i]` は `roomNames`（3つ）と同数（既定値 3 つ）。
- `Int(Double)`: 代表例は `Int(x.rounded())`（体力・知名度・完成度）。値は有限（能力は clamp 済み）。`Int(seconds / 0.05)` や `Int(sec * 20)` は定数の秒だけ。`Int(s.fame)` も有限。
- ゼロ除算: `/ count`・`% count` はすべて配列の定数リテラルか `guard count > 0`（DialogueData.swift:25）の後。RentStatement の `sum` は定数表の合計 14。`YoseComponents.swift:272` は `total > 0` を確認済み。RadarChart の `/ cap` は cap が 0 でも Double なので NaN/∞ になるだけで落ちない。
- Range: `1...n` や `0..<n` で n が変数のものは、n が定数か非負（`FinalsPresentationView.swift:859` の `4..<min(7, count)` は judges が7人固定）。`rng.uniform(in: -b ... b)`（GameEngine.swift:243）は `b = 5 + 15 * (1 - メンタル/100)` で、メンタルが 133 を超えると負の幅になるが、能力は上限（cap）で止まるので届かない。

## §4 見た範囲
- grep: `!` の後が `.` `)` `,` 空白・行末、`)!`・`]!`、`try!`、`as!`、`fatalError`、`precondition`、`.first!`・`.last!`、`[0]`・`[i]`・`[idx]`・`[index]`・`[...Index]`・`[count - 1]`、`Int(…)`（Double 演算を含むもの）、`/`・`%` + count/total/sum、`..<` `...`。`#if DEBUG` ブロックと debug 関数・MZ_ 行は機械的に除外（`try!` が1件、GameSession.swift:1741 の旧セーブ試験で DEBUG 内）。
- 前後数行を読んだ所: FinalsPresentationView（審査員・票・出順）・FinalsBroadcastIntro・WeekRunner（restoring・gpStage・chooseOffer）・GameSession（upcomingStages・loadedOrNew・イベント抽選）・JudgeTalk・DialogueData・NetaCatalog・ShopView・RentStatement・Theme・TournamentResultView・NetaStage・Sound/Animation 系の steps。
- 見ていない: 約215件の Range のうち両端が定数のもの（精読せず）、`Int(Double)` のうち値の出所が状態（`GameState`）の NaN になる経路（`GameEngine` の式を全部は追っていない）、保存データが壊れた（手で編集した）場合のその他の添字（`loadedOrNew` は JSON デコードに失敗すると退避して新規に戻る）。
