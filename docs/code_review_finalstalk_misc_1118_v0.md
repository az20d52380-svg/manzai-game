# コード点検：FinalsTalk / NetaStage / WaIcons / FontLoader / ManzaiGameApp（2026-11-18・読むだけ）

結論：落ちる穴・乱数消費・DEBUG フックの漏れは見つからなかった。指摘は「大トリ order==10 固定（既知）」「WaIcons が死んだコード（既知）」「NetaStageBadge の VoiceOver ラベル（要確認）」など軽いものだけ。
対象：ManzaiGame/Sources の5ファイル＋呼び出し側（FinalsPresentationView.swift・RootView.swift・Theme.swift）と GameCore/JudgeTalk.swift の選び方部分を grep→必要行だけ確認。

過去の点検の確認：docs/code_review_misc5_1116_v0.md（FinalsTalk）、code_review_unaudited_1116_v0.md（WaIcons）、code_review_unreviewed_1115_v0.md（FontLoader）、code_review_1108b_device_events.md（ManzaiGameApp の StoreManager）、code_review_1116_night_v0.md（NetaStage の二度押し・世代番号）。

## 指摘

| # | 重さ | 場所 file:line | 状態→結果 | 直し方の案 | 既知? |
|---|---|---|---|---|---|
| 1 | 低 | FinalsTalk.swift:17-22（呼び側 FinalsPresentationView.swift:578） | `call(order:name:)` は order==10 を「大トリ」固定。組数が10以外になると最終組に出ない／別の組に出る。現状は画面も「全10組」固定（同:536）なので今は食い違わない | 組数が可変になる時だけ `total` を引数に足す（表示のみ・数値不変） | 既知（misc5 要確認-2） |
| 2 | 低 | WaIcons.swift:6 | `WaIcon` は Sources 内のどこからも呼ばれない（今回の grep でも0件）＝死んだコード。使う場合は accessibilityLabel / accessibilityHidden も未設定 | 使う予定が無ければ削除。使うなら装飾として `.accessibilityHidden(true)` | 既知（unaudited_1116） |
| 3 | 要確認 | NetaStage.swift:39 | `NetaStageBadge` の HStack に `.accessibilityLabel` だけを付け、`.accessibilityElement(children:)` を指定していない。VoiceOver で「仕上がり ◯◯」が子の Text と二重に読まれる／ラベルが子へ伝わる可能性（実機の VoiceOver 未確認の推測） | `.accessibilityElement(children: .ignore)` を足してから label を付ける | 未（新規） |
| 4 | 低 | NetaStage.swift:44-51 | 段が上がった光は色の変化だけで、VoiceOver には伝わらない。reduceMotion 時は `Theme.Motion.r` が nil を返すため即座に光って約0.9秒後に即消える（点滅が残る）。動きとしては小さい | reduceMotion 時は光らせず、必要なら段の上がりをアナウンスに回す | 未（新規） |
| 5 | 低 | NetaStage.swift:51 | 光を消す Task は取り消さず、世代番号で上書きだけ防いでいる。画面が消えた後も `glow` を更新するが、View が無いので無害 | 対応不要（`.task(id:)` 化は任意） | 既知（stale_timer_audit_1115 #5・1116_night） |
| 6 | 低 | FontLoader.swift:27-29 | `isAvailable` は Bold の登録だけで判定。Black/ExtraBold/Medium のどれかだけ読み込み失敗でも `Font.maru`（Theme.swift:267-277）は丸ゴに落ちず、`.custom` の見つからない名前でシステム標準書体になる。また `maru` を呼ぶたびに UIFont 検索が走る（描画の度）。4ファイルの実在は 1115 に mdls で確認済みで、現状は発生しない | 4名すべてを確認する static let にして1回だけ評価 | 一部既知（unreviewed_1115 は実在のみ確認） |
| 7 | 要確認 | FinalsPresentationView.swift:781-818 | 講評の文は `salt`（点・年・出順・i）と `judgeScene`（`s`・選択中ネタ等）の純関数。再描画で変わるのは `judgeScene` の入力（`s` やネタ選択）が決勝中に変わる場合だけ。決勝表示中に変わらないかは未確認 | `commentPicks` を beat 開始時に1回だけ作って保持（表示のみ） | 未（新規・推測） |

## 確認済み（問題なし）

- ①落ちる穴：`FinalsMC.askJudge` は `split.first ?? Substring(judge)` で空名でも落ちない。`NetaStage.index` は NaN でも 3 になるだけで添字は 0...3 に収まる。`JudgeTalk.mix` は `UInt64(bitPattern:)` と `% UInt64(Int.max)` で負の salt でも安全。`pick`/`fill` は空配列を弾いてから剰余を取る。WaIcons の図形は固定値で除算なし。
- ②乱数：FinalsTalk は JudgeTalk（salt の混ぜ＝RandomSource を使わない）への委譲だけ。UI は GameCore の RNG を消費しない。
- ③状況と文：FinalsTalk 内の司会文に「来年」「俺・僕・男」は無し（「今年の頂グランプリ」は決勝当年の文で最終年でも成立）。講評の「俺」は審査員の台詞で、コンビの性別とは無関係。
- ④セーブ→再開：`NetaStage.lastSeen` はメモリのみで、再開直後は prev が nil のため光らない（意図どおり）。周の切り替え時は RootView.swift:355・370 でリセット済み。
- ⑦実名：司会「鳴海 ジョー」・「頂グランプリ」は架空名。実在の大会名・芸人名は5ファイルに無い。
- ⑧起動・DEBUG：ManzaiGameApp.swift には環境変数フックなし。RootView の MZ_SMOKE/MZ_UI/MZ_ENDING/MZ_BG 系と FinalsPresentationView の MZ_PICKUP は `#if DEBUG` の内側（RootView.swift:15-24 等、FinalsPresentationView.swift:772-778 で確認）。FontLoader は登録失敗を `continue` で無害にし、`registered` で二重登録を防ぐ。`StoreManager.shared` の起動時生成は 1108b で確認済み。
- ⑤二度押し：5ファイルにボタンなし。
