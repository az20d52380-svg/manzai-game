# コード点検 misc3（FinalsBroadcastIntro / CalendarView / SettingsView）2026-11-16

## §1 要約
- 高0／中0／低3／要確認2。コードは変更していない（読むだけ）。
- 一番重いのは低-1：決勝導入で「審査員席」→「ファイナリスト」に切り替わる最初の1フレームだけ、前の場面の step=7 が残り、10組のうち7組が点灯して見え、すぐ消える（確信度 中）。
- タイマー・Task の取り消し、境界値、配列の範囲、取り返しのつかない操作の確認、`//` の後ろに消えた修飾子は問題なし（§3）。

## §2 指摘
| # | 重さ | 確信度 | ファイル:行 | 起きる条件 | 直し方の案 |
|---|---|---|---|---|---|
| 低-1 | 低 | 中 | FinalsBroadcastIntro.swift:58,329-331（`.task(id: stage)` と `run` 冒頭の `step = 0`）・:252-275（finalistsView は `step > i` で点灯） | 審査員席（step が 7 まで進む）が終わり／タップで `stage = .finalists` になった直後。`step` のリセットは task 本体の先頭＝最初の描画の後なので、1フレーム 7 組が「on」で描かれ、`.animation(value: step)` のばねで消える。vtr→title（step=3 は title で使わない）・title→judges（title の run が step=0 に戻している）は影響なし | `advanceStage()` で `stage` を替える同じ場所で `step = 0` も入れる（または各場面の View を `.id(stage)` で作り直し、`step` を場面ごとの @State にする） |
| 低-2 | 低 | 中 | FinalsBroadcastIntro.swift:57,137-170（ルートの `onTapGesture`・`accessibilityAction` なし）・:260-276（未点灯の組は opacity 0 のまま読み上げ対象） | VoiceOver 中。導入は自動で進むので止まりはしないが、(a) 終盤の場面で先へ進める操作が無い（同じ作りの FinalsBroadcastEnding:283 には `.accessibilityAction { finish() }` がある）、(b) 点灯前の10組の名前と「あなた」が、まだ見えていないのに全部読まれる | ルートに `.accessibilityAction(named: "次へ") { advanceStage() }` を足す。finalists の各札に `.accessibilityHidden(!on)` |
| 低-3 | 低 | 中 | CalendarView.swift:89-120（`cell`）・:117-119 | VoiceOver 中。現在週の印（金の栞＝図形だけ）は読まれず、過去週の判子は「稽」など一字だけ読まれる。週ごとの内容は長押し（0.3秒）のトーストでしか分からない。年サマリに「第N週」はあるので現在週は分かるが、表のどのマスかは分からない | セルに `.accessibilityElement(children: .ignore)` ＋ ラベル「第w週・4月第n週・稽古／大会名／今週」。`accessibilityAction` で長押しと同じ文を出す |

## §要確認
- 要確認-1：FinalsBroadcastIntro.swift:58-68。`.task(id:)` と `.onAppear`（`short` と `stage = startStage` を設定）の実行順。task が先に走ると、2回目以降でも最初の場面（vtr）だけフル尺（3行・長い待ち）になる。SwiftUI の実装順に依存＝実機で「2回目の決勝の煽りV」が短縮されているかを見れば分かる（シミュレータが空くまで確かめない）。直すなら `short` を `@State` の初期値で決める（`init` 内で UserDefaults を読む）。
- 要確認-2：SettingsView.swift:174-178。確認モーダルの取りやめボタンが「やめる」で、コメント（:170）の「取りやめは『もどる』」と食い違う。「解散する／やめる」は「やめる＝何を？」と読める。文言の決定はオーナー（docs/proposal_settings_restart_v0.md と settings_text_score_1110_v0.md に当たる節が無いか未確認）。なお `restartStep = 2`（コメントの「確認2段目」）はどこにも無く、確認は1段（その後に DisbandFarewellView）。取り返しのつかない操作の確認漏れではない（セーブは別れ画面の完了後 abandonRun で消える：WeekMainView.swift:199-205・GameSession.swift:1048）。

## §既知
- 煽りV・タイトル・審査員・ファイナリストの Task 取り消し後の1回の余計な処理：code_review_1108g #2（済）。
- 古い場面の末尾が1場面飛ばす：code_review_1108g #1（済・`advanceStage(from:)`）。
- 日程表の過ぎた大会週の塗り・凡例の文・長押し文との食い違い：calendar_audit_1115_v0.md 中-2、code_review_1108／1107c（済）。
- 設定の既定音量のそろえ：code_review_2026-10-19f §1（済）。

## §3 見て問題なしの所
- CalendarView：トーストの消去は token で比較（二重発火なし）／`ForEach(0..<12)×(0..<4)` は定数で、`row*4+col+1` は 1〜48／`monthLabel` は row0=4月〜row11=3月で正しい／`categoryLog[w]` は辞書の添字（範囲外なし）／第1週・第48週・第47週（GP 決勝 `gpFinalWeek`）の境界で塗りが崩れる所なし／`tournamentName` の `gpRoundNames[i]` は `i < count` ガードあり。補足：`weeks` プロパティは未使用で、格子は 48 週固定（config.weeks が 48 以外になる予定は無い）。
- SettingsView：`vol_bgm`／`vol_se`／`anim_speed` は @AppStorage と SoundManager・MZSpeed が同じキー・同じ既定（0.6／0.8／0）／`onChange` は UserDefaults 書き込み後に走るので試し鳴らし・BGM 反映は新しい値／`step` は 0〜1 に丸め／購入の復元は `restoring` で二重押し防止／Task は DEBUG の MZ_QUIT だけ／`GlossaryView` の ForEach は `id` 付きの固定配列（減る画面ではない）／「−」「＋」の VoiceOver 名は「BGMを下げる」などで見た目と一致。
- FinalsBroadcastIntro：`judges[min(step,7)-1]`・`parts[0]` は範囲内／finalists が空でも `0..<0`／`stage.next` が nil で `finish()`、`done` ガードで二重発火なし／`onDisappear` で BGM の絞りを戻す／「スキップ」ボタンの VoiceOver 名「スキップ」は見た目（スキップ ▶▶）と矛盾せず／FinalsBroadcastEnding は VoiceOver 中は自動で閉じない。
- 同じ行の `//` コメントの後ろに書かれて消えている修飾子：3ファイルとも該当なし（grep で確認）。
