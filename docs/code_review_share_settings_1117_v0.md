# コード点検：ShareCard / FirstStageView / SettingsView（GlossaryView 含む）/ FinalistAnnounceView（2026-11-17・読み取り専用）
対象: ManzaiGame/Sources/ShareCard.swift, FirstStageView.swift, SettingsView.swift, FinalistAnnounceView.swift ＋ 呼び出し側（YearResultView.swift:64・EndingViews.swift:102・IntroFlow.swift:410/862・WeekMainView.swift:199・TournamentResultView.swift:53/289・GameSession.swift:1177/1478・FinalsPresentationView.swift:1405・YoseGameParts.swift:188）。
結論: 落ちる穴・乱数消費・女性形の男性語・共有カードへの実名/実在大会名は見つからず（§確認済み）。中1（設定の音量ゲージのドラッグが画面のスクロールを奪い、触れただけで音量が変わる恐れ・要確認）、低6（初舞台の波紋が出ない恐れ・VoiceOver・言葉のずれ・古いコメント）。高なし。

## 指摘
| # | 重さ | 場所 | 状態 → 結果 | 直し方の案 | 既知? |
|---|---|---|---|---|---|
| 1 | 中（要確認） | SettingsView.swift:196-204（volumeRow のゲージ上の `DragGesture(minimumDistance: 0)`）／:41（ScrollView） | ゲージ全体に最小移動0のドラッグを載せているため、**縦スクロールの指がゲージに触れた瞬間に音量が触れた位置の値へ飛ぶ**（onChanged は触れた時点から呼ばれる）。BGM を 100 に跳ねさせたり 0 にしたりして、スクロールも効かない可能性。SwiftUI のジェスチャ競合なので実機での確認が要る（推測） | `minimumDistance: 8` 程度にして縦ドラッグはスクロールへ渡す／ゲージの高さを広げ、タップ位置の反映は `onEnded` か minimumDistance>0 の時だけにする | 新規（1108c_screens §確認済みは「width が0にならない」のみ） |
| 2 | 低（要確認） | FirstStageView.swift:39-46 と :159-160 | `phase = .burst` と `withAnimation { ripple = true }` が**同じ同期処理内**。波紋の Circle は `warm` の時にだけ挿入されるので、挿入された時点で `ripple` はもう true（透明・9倍）＝**縮小0.3倍・不透明0.8からの広がりが描画されない**（出現と同時に終わった状態）。山吹の光・粒子・閃光・揺れは別経路で出るので、気づかれにくい。2周目以降の「とばす」後に戻る場合も `ripple` は true のまま | `ripple` を burst の1フレーム後に立てる（`await wait(0.02)` の後）／Circle を常に置き、opacity と scale だけ `warm` で変える／`ripple` を `.onAppear` で立てる | 新規 |
| 3 | 低 | SettingsView.swift:44-48・208（volumeRow の読み上げ） | ゲージ（YoseGauge）と数字「60」に VoiceOver の値ラベルが無い。−/＋ボタンは「BGMを下げる」と読むが、**いまの音量が読まれない**（数字は「六十」とだけ読まれ、何の数字か分からない）。ゲージのドラッグは VoiceOver では操作できない | 行に `.accessibilityElement(children: .contain)`、数字に `.accessibilityLabel("\(label)の音量 \(n)")`、ゲージは `.accessibilityHidden(true)`。または行全体に `.accessibilityAdjustableAction` | 新規 |
| 4 | 低 | SettingsView.swift:58-65（購入を復元・`store.lastMessage`） | 復元が終わっても、結果の一言（lastMessage）は Text が現れるだけで**読み上げ通知が無い**。VoiceOver ではボタンの文字が「復元しています…」→「購入を復元」に戻るだけ＝成功も失敗も分からない | `.onChange(of: store.lastMessage) { UIAccessibility.post(.announcement, …) }` | 新規（1108c_screens #2 は「消えない」件・直し済みの想定） |
| 5 | 低 | SettingsView.swift:163（「このキャリア」）・GlossaryView :307（各群の見出し） | `section()`（:134）は `.isHeader` を付けるが、careerSection の見出しと用語集の群の見出し（強さ／ネタ／暮らし…）には付いていない。VoiceOver の見出し移動で飛べない | `.accessibilityAddTraits(.isHeader)` を3か所の見出し Text に | 新規 |
| 6 | 低 | SettingsView.swift:16-17（コメント）・:31・:118 | 状態の注釈は「0=通常 1=確認1段目 2=確認2段目」だが、モーダルは1段しかない（`restartStep > 0` で同じ画面）。DEBUG の `MZ_STEP=2` も1段目と同じ。誤解の元 | コメントを「0=通常 1=確認中」に直す・`Bool` に替えてもよい | 新規（コメントのみ） |
| 7 | 低 | ShareCard.swift:59-63 | `.task(id:)` の id が変わって再生成する間は**前の画像が残る**（古いコンビ名・見出しの画像で共有できる一瞬がある）。`r.uiImage` が nil の時は何も出ず（ボタンも見えない）、再試行もしない＝原因が分からない。実害は小さい | `image = nil` を先に入れてから生成／nil の時は `hidden` のままで可だが、再試行（`.task` 内で1回やり直す）を足す | 一部既知（1107b #10 は id 追加で修正済み・この残りは新規） |
| 8 | 低 | FinalistAnnounceView.swift:111-112（onChange の読み上げ）／:239-242（skipAll） | `skipAll` は `called` と `stage` を**同時に**変える → 同じ caption（敗者復活の3行）の読み上げが2回出る。VoiceOver で「飛ばす」を押すと同じ文が連続で読まれる | `onChange(of: stage)` だけにして、`.read` 中の `called` だけ別に読む（または skipAll で announce を1回に） | 新規 |

## 既知の再掲（重複のため詳細は書かない）
- FinalistAnnounceView.swift:199（`start()` の `guard task == nil`）は onDisappear の cancel 後も task が非 nil のため、画面が一度消えて戻ると再開しない。→ **既知**（code_review_1107e #5）。この画面は `.overlay` で出しており、上に別画面が重なる経路は現状無い＝実害なし。
- FinalistAnnounceView.swift:55-58 自組の読み（漢字名・英字名は五十音の端に固定）→ **既知**（code_review_1108c_screens #6・1116_cands:49）。
- 共有カードのコンビ名が Names.show で相方名・一人称に置き換わる（`Text(combiName)`）→ **既知**（code_review_1108d #2・オーナー判断待ち）。
- YoseModal が VoiceOver のモーダルとして扱われない（SettingsView の解散確認も同じ）→ **既知**（code_review_2026-10-19l 1-2）。

## 確認済み（問題なし）
- 落ちる穴：
  - ShareCard：添字・Int 変換・除算なし。ImageRenderer は `.task`（MainActor）内で使用。`r.uiImage` は nil を `if let` で受ける。
  - FirstStageView：`UInt64(s * 1_000_000_000)` の s は定数（1.6/6.5/0.1…）で負にならない。添字・強制アンラップなし。
  - FinalistAnnounceView：`Int64(year &* 2654435761 &+ 17)` は溢れ演算子（`&*`・`&+`）でトラップしない。`swapAt(si, count/2 + count/4)` は count=15 で 10、count=16 で 12（範囲内）。`stride(from: count-1, through: 1, by: -1)` は count<2 でも空。`readOrder` が空でも `for i in 0..<0` は回らない。`last2` の `order.count - 2` が負でも比較のみ。`yearRoster` は npcNames 52件から自組名を除いて 9〜10件を取る（足りる）。`Self.yomi` のキー52件に重複なし（辞書リテラルの重複キーは実行時トラップだが該当なし）。yomi の表は `FinalsData.npcNames` の全名を含む（突き合わせ済み）。
  - SettingsView：`Int((v*100).rounded())` は v が NaN にならない限り安全。NaN が入る経路は `geo.size.width == 0` の除算だけだが、幅0のゲージには触れない＝到達しない。`ForEach(1..<10)` は固定範囲。`step` は 0〜1 に丸め。Glossary の `ForEach(g.rows, id: \.0)` は群ごとに語が重複しない（`Group.id` も重複なし）。`Self.groups.indices.contains(n)` の後に添字（DEBUG のみ）。
- 乱数：4ファイルとも GameCore の RNG・SeededRng を新規に消費しない。FinalistAnnounce の `nx()` は年から作るローカルの決定論シャッフルで、ゲーム内乱数とは別（再描画のたびに同じ並び）。`FinalsData.yearRoster` も UI 専用 PRNG（FinalsPresentationView.swift:1420）。
- 状況と文：
  - FinalistAnnounce の「敗者復活戦は決勝当日です」は準決勝敗退で必ず `revival=true`（WeekRunner.swift:277）なので、呼ばれなかった時の案内として合う。落選の年の他組数（10組）と決勝の名簿（`count: passed ? 9 : 10`）は同じ年シードで一致。
  - 「来年」「最終年」等の年依存の文は4ファイルに無い。共有カードの「結成N年目」は `session.year`（年末画面は同じ年の N年目）と一致。連覇は `yearHistory`（GameSession.swift:1478 で年末に追記済み）を見る＝当年を含んで数えられる。
  - 用語集の数値は `GameConfig()` から差している（生活費・夜逃げ線・決勝の週）。
- 女性コンビ：4ファイルに「俺・僕・男」等の固定語なし。FirstStageView は標準語の地の文（相方名・一人称を使わない）。FinalistAnnounce は「皆さん」。共有カードの文言は結果語だけ。
- セーブ→再開：4ファイルとも表示専用の `@State` のみで、保存対象の値を書かない。FirstStage は `Self.hasSeenIntro`（IntroFlow 側）で1周目だけ。設定の音量・速さは `@AppStorage`（UserDefaults）で端末に残る。
- 動き：
  - FirstStageView の `wait` は取り消されたら false を返し、各段で `guard` して抜ける。「とばす」「第1週へ」は `finished` で二度押しを弾く。VoiceOver 中は自動でツッコまない。reduceMotion は縮小・波紋を止める。
  - FinalistAnnounce は skipAll が task を取り消し、各 `pause` 後に `isCancelled` を見る。`skipStep` は `pause` の終わりで戻る。`withAnimation(reduceMotion ? nil : …)` で動き低減に対応。
- アクセシビリティ（問題なしの所）：ShareCardButton のダミー枠は `.accessibilityHidden(true)`。FirstStage の「ツッコむ」「とばす」にラベルあり・場面の変わり目は `UIAccessibility.post`。FinalistAnnounce のシルエットは `accessibilityHidden` で caption に一本化・「飛ばす」は最小高44。−/＋ボタンにラベルあり。
- 共有カード（実名・実在大会名）：入れる文字列は アプリ名「漫才王になろう」・`#漫才王になろう`・コンビ名（利用者入力）・見出し（「優勝」「N連覇」「決勝進出」・エンディング名8件）・detail（「結成N年目」「No.N　バッド／ビター…」）だけ。実在の大会名（M-1 等）・個人名・％は無し（Endings.swift:28-42 を確認）。「頂グランプリ」の名前も出さない。コンビ名の中身は利用者が決める＝ゲーム側の責任範囲外（置換の件は既知として上に）。最長タイトル「十五冊目のノート」（8字）は 72pt×0.4 まで縮む設定で収まる。
