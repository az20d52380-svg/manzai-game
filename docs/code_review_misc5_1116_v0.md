# コードレビュー misc5（2026-11-16）

対象: Juice.swift / FinalsTalk.swift / CommandData.swift / FirstStageView.swift / Store/AdProvider.swift（読むだけ・未編集）

## 要点(3行)
- クラッシュ・ゲーム数値に触る不具合は無し。指摘は 中2・低4・要確認2 の計8件。
- 最重要は FirstStageView の onAppear 再実行（pressed が true のまま ready で固まる恐れ）と、ScreenFlashModifier の閃光が出ない可能性。
- Task の取り消し握りつぶしによる状態書き換えは FirstStageView では対策済み。Juice 側は未キャンセルだが害は小さい。

## §1 件数
| 重大度 | 件数 |
|---|---|
| 高 | 0 |
| 中 | 2 |
| 低 | 4 |
| 要確認 | 2 |

## §2 指摘

### 中-1 FirstStageView.swift:80,134-142 onAppear が再実行されると進行が壊れる
- 状況: `.onAppear { start() }` に再入ガードが無い。上に sheet や overlay が乗って閉じる、タブ切替などで onAppear が再度呼ばれると、`onDisappear` で cancel 済みの task を捨てて start() がやり直しになる。
- 失敗シナリオ: 1) burst 以降の途中で再表示されると phase が .ready に巻き戻る。2) `pressed` は true のままなので、press() の `guard phase == .ready, !pressed` で弾かれ、「ツッコむ！」を押しても何も起きない。6.5秒後の自動 press() も弾かれる。3) 画面は ready で固まり、onSkip が無い初回（IntroFlow.swift:862）は出られない。
- 修正案: start() 冒頭に `guard phase == .enter, task == nil else { return }` を置く。onDisappear は cancel だけでなく、再開させない方針なら finished 相当のフラグを立てる。

### 中-2 FirstStageView.swift:70-75,110-114 「とばす」が finished を立てない
- 状況: 「第1週へ」は `finished` で二重実行を防ぐが、「とばす」は task を cancel して onSkip() を呼ぶだけで finished を立てない。
- 失敗シナリオ: onSkip が遷移アニメーション付き（ほかの画面でも transition(.opacity) 0.4s 級）の場合、遷移中にまだ表示されている「第1週へ」や、とばすの連打で onSkip/onComplete が二重に走る。GameSession を2回作る恐れ（コメント111行目の想定事故と同じ型）。現状 bitter 到達前は「第1週へ」が出ないので実害は「とばす」連打に限る。
- 修正案: とばすのクロージャにも `guard !finished else { return }; finished = true` を入れる。

### 低-1 Juice.swift:106-109,162-166 ParticleBurst / SpeedLinesBurst の Task が取り消されない
- 状況: 非構造化 `Task { try? await Task.sleep ... }` を保持も cancel もしない。
- 失敗シナリオ: ビューが消えた後も life 秒だけ Task が生き、消えた @State を書く。SwiftUI の State は安全に捨てられるので実害は無い。連続 trigger は seq 比較で正しく無視される。
- 修正案: 実害が無いので優先度は低い。直すなら `.task(id: trigger)` に寄せ、cancel 時は何もしない（`guard !Task.isCancelled`）。

### 低-2 Juice.swift:184-187 PunchModifier の連続変化でちらつく
- 状況: 値が 140ms 以内に連続変化すると、1回目の Task が2回目の punched=true の直後に false へ戻す。
- 失敗シナリオ: 数字が連続で増える場面（FinalsPresentationView.swift:1036 の count など）で、2回目の跳ねが途中で引っ込む。見た目だけ。
- 修正案: Task を @State に保持し、新しい変化の時に前の Task を cancel。sleep 後は `guard !Task.isCancelled`。

### 低-3 Juice.swift:279-286 EdgePulseModifier 並行ループ
- 状況: Task を保持しないため、trigger が連続すると2本のループが並走し、on の true/false が交錯する。最後は必ず on=false になるので固着はしない。
- 修正案: Task を保持して再入時に cancel。reduceMotion が途中で切り替わっても終端が false になるよう defer で `on = false`。

### 低-4 Store/AdProvider.swift:33-44 completion のスレッド
- 状況: AdGate は @MainActor だが、provider に渡す completion クロージャは MainActor 隔離されていない。実 SDK がバックグラウンドから呼ぶと、呼び先（画面遷移）が非メインで走る恐れ。`fired` も排他が無い。
- 現状: どの画面にもつないでいないので未発火。実 SDK を足す時に顕在化する。
- 修正案: `{ Task { @MainActor in guard !fired ... } }` に包むか、completion を `@MainActor @Sendable` にする。

### 要確認-1 Juice.swift:211-215 ScreenFlashModifier の閃光が出ない可能性
- 状況: onChange 内で `opacity = strength`（非アニメ）の直後に `withAnimation { opacity = 0 }` を同じトランザクションで実行している。レンダリングは最終値 0 だけを見るため、0→0 で何も描かれない可能性がある（既知のパターン）。
- 確認方法: 目視（MZ_UI=firststage など flash を使う画面で閃光が見えるか）。既に見えていれば問題なし。見えない場合は、strength を先に代入→次のランループ（`DispatchQueue.main.async` か短い Task.yield）後にアニメで 0 へ戻す。
- 備考: reduceMotion 側（0.12）も同じ経路。

### 要確認-2 FinalsTalk.swift:17-22 「大トリ」が order==10 固定
- 状況: 組数が 10 でない大会設定では「大トリ」が出ない、または最終組で出ない。FinalsPresentationView.swift:578 は d.order だけを渡している。
- 確認方法: 決勝の組数が常に10かを GameCore 側の設定で確認。可変なら `call(order:total:name:)` に変更（表示専用で数値は不変）。

## §3 問題なしと確かめた所
- FirstStageView.wait(): `Task.isCancelled` を sleep 後に判定して false を返し、呼び側が guard で抜ける＝取り消しを握りつぶさない（code_review_1107d #1 の対策が有効）。press() 内で自分自身（start の task）を cancel して新 task に差し替える流れも、旧 task は次の wait で抜けるので安全。
- 「ツッコむ」「とばす」ボタンは accessibilityLabel あり。VoiceOver 中は自動 press しない。phase 変化は announcement で読み上げ。装飾（ParticleBurst / SpeedLinesBurst / WaveformView）は accessibilityHidden。
- ParticleBurst: `colors.isEmpty` を弾いているので `i % colors.count` の 0 除算なし。life は固定値で sleep の UInt64 変換に負数は入らない。burstSeq/seq で古い Task が新しいバーストを消さない。
- ScreenShake: animatableData の小数部で進行を出し、整数点では identity。phase の加算で壊れない。
- CommandData.swift: `config.trainings[t]` / `jobs[j]` / `rests[r]` はすべて guard 経由の compactMap で添字外・強制アンラップ無し。`restCosts[r] ?? 0` も安全。`extraCards` の `fatigued` は未使用だが害なし。新しい行動や数値は足しておらず、WeekAction への写像だけ（GameCore/golden 不変）。
- FinalsTalk.swift: `judge.split(separator:).first ?? Substring(judge)` で空名でも落ちない。JudgeTalk への委譲のみで数値は触らない。
- AdProvider.swift: isAdFree なら provider を呼ばず先へ進む。二重 completion は `fired` で1回に抑制。
- Juice.swift 全体が View 層のみで、GameCore の RandomSource・数値には触れない（決定論ハッシュ）。
