# コード点検 1108g

## 対象
`git diff b8a630a8..HEAD -- ManzaiGame/Sources GameCore/Sources`（GameCore は差分なし。ManzaiGame の4ファイル）
- FinalsBroadcastIntro.swift（0807c13c：タップ後の二重進行のキャンセル）
- CalendarView.swift（57bf59a2：過ぎた大会週の塗りの純関数化）
- RootView.swift（8b98e14a/89c50838：MZ_HANAIDX・MZ_UI=gacha_rates）
- Store/StoreIDs.swift（dab478de：コメントのみ）

## 指摘一覧
| 番号 | 重さ | 内容 | file:line | 起きる場面 |
|---|---|---|---|---|
| 1 | 低（済 c3282822） | 場面切替の瞬間の競合で、キャンセル前の古いタスクが先に再開すると、まだ二重進行が起こりうる | FinalsBroadcastIntro.swift:57-58,352-385,389 | 古い場面の待ちが明ける瞬間にタップした時（極まれ） |
| 2 | 低（済 c3282822） | キャンセル後も、待ちの直後の処理（ハプティクス・step 代入）が1回走る | FinalsBroadcastIntro.swift:361,377-380 | .title で 0.2秒待ちの途中、.finalists の自分の登場待ちの途中でタップした時 |
| 3 | 低（済 c3282822） | MZ_HANAIDX が負数だと配列の範囲外で落ちる（DEBUG のみ） | RootView.swift:63 | MZ_HANAIDX=-1 を渡した時（目視の操作ミスのみ） |

DEBUG の漏れ：なし。`gacha_rates`（RootView.swift:58）と MZ_HANAIDX（:63）はどちらも `#if DEBUG`（:33〜:85）の内側で、リリースには入らない。

## 各指摘と直し案
1. タップは onTapGesture で stage を同期的に書き換えるが、古い `.task(id:)` のキャンセルは次の描画で行われる。その前に古い場面の末尾の待ちが明けて再開すると、`Task.isCancelled` がまだ false で `advanceStage()` が走り、1場面飛ぶ。今回の guard で通常のタップは防げるが、この窓は残る。直し案：`run(_ s:)` の末尾で `guard stage == s else { return }` を併用する（advanceStage 側を `advanceStage(from: s)` にして stage が一致する時だけ進める形が最も確実）。
2. `pause` は `try?` でキャンセルを飲み込むため、待ちの直後のコードが走る。.title の `Haptics.rare()` が古い場面で1回余計に鳴る。.finalists の `if isSelf { await pause }` の後は guard なしで `step = i + 1` が走るので、新しい場面の `step = 0`（:337）より後に再開すると step が古い値で上書きされうる。害は小さい。直し案：`pause` 直後にも `guard !Task.isCancelled else { return }` を置く（または pause を throws にして `try await` に統一）。
3. `min(idx, count - 1)` の下側が無い。直し案：`max(0, min(...))`。DEBUG のみなので放置でも可。

## 問題なしと確認した点
- 純関数 `paintsPastTournamentWeek` は元のインライン3行と同じ順序（年数切れ→推薦制→HANA 判定）・同じ結果。呼び出し側は未来週の分岐の後で、過ぎた週のみ使用。テスト PastWeekPaint1108Tests.swift あり。
- 既存の guard（.vtr のループ・.title の 0.15秒後・.judges/.finalists のループ先頭）と今回の末尾 guard で、通常のタップ後の二重進行は止まる。最終場面（.finalists）の `advanceStage()` → `finish()` も `done` で二重呼びを防いでいる。
- StoreIDs はコメントの金額のみの変更で、挙動の差なし。
