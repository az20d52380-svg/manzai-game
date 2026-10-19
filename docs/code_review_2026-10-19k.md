# コード点検 10回目（2026-10-19k）

件数：4件（高 1 / 中 3）。読み取りのみ・コードは未変更。
対象：StageScene・Juice・FinalsTalk・NetaCatalog・TalkParts・RadarChart・Design/YoseEffects・YoseMilestoneFX・YoseRankUpOverlay（全9ファイル読了）。
問題なしと確認：RadarChart（cap は min(上限, 30以上のzoom)＝0にならずNaNなし）、NetaCatalog（審査員名は FinalsPresentationView の specs と完全一致・autoKata/autoName は負数でも安全）、Juice（colors空はガード済み・Task は seq 照合で上書き事故なし）、StageScene/TalkParts/FinalsTalk（範囲外・空配列・ゼロ除算なし）。

## 所見

### 1. 高：視差効果オフで「ハマった夜」の帯が画面に残り続ける
- Sources/Design/YoseMilestoneFX.swift:412（呼び元 Sources/TournamentResultView.swift:267・304）
- 手順：設定で「視差効果を減らす」ON → 本番で burst==true の回戦 → showBurstCutIn=true → `run()` が reduceMotion 分岐で `bandIn = true` などを立てて **onFinish() を呼ばずに return**。帯が出っぱなしで showBurstCutIn が false に戻らない（再発火もしない）。
- 直し案：reduceMotion 分岐を `... popped = true; try? await Task.sleep(約0.9s); onFinish(); return` にする。
- 確度：高

### 2. 中：YoseBurstParticles が一度爆ぜたあと毎秒60回の再描画を止めない
- Sources/Design/YoseEffects.swift:106・160-164
- 手順：任意の判子・練習大成功・年替わり・ランクアップで trigger を +1 → `burstStart` が設定される → 以後 `paused: burstStart == nil` が二度と true にならず、TimelineView が画面が消えるまで 60fps で Canvas を回す（Juice.swift の ParticleBurst は終了後に nil へ戻す作りで、こちらだけ漏れている）。
- 直し案：爆ぜ終わり（duration+0.1秒後、seq 照合つきの Task）で `burstStart = nil` に戻す。
- 確度：高

### 3. 中：画面が閉じられて Task が取り消されると、演出が一瞬で最後まで走り onFinish/onDismiss と触覚が余計に鳴る
- Sources/Design/YoseMilestoneFX.swift:259-294（PassCelebration）・411-439（BigSuccessCutIn）、Sources/Design/YoseRankUpOverlay.swift:280-323
- 手順：演出の途中で親が画面ごと外す（例：BigSuccessCutIn 中に結果画面を離れる／タップスキップ以外で消える）→ `.task` が取り消され `try? await Task.sleep` が即返る → 残りの処理（触覚×数回・onFinish()/dismissImmediately→onDismiss）が連続で走る。RankUp は isDismissed ガードがあるが、親が外しただけの時は未設定なので onDismiss が二重に呼ばれ得る（現状 RankUp は DEBUG の FXPreview のみ接続）。
- 直し案：各 sleep の後に `if Task.isCancelled { return }` を入れる（`try?` を `guard (try? await ...) != nil else { return }` に）。
- 確度：中（親が途中で外す経路があるかは実機で未確認）

### 4. 中：視差効果オフでも大きく動く演出部品が残っている
- Sources/Design/YoseEffects.swift:480（YoseAnimatedHanko の 2.35倍→1.0 のバネ）、:583-588（YoseCutInBanner の端から端へのスライド）、:204-210（YoseNumberPop の 1.24倍の跳ね）
- 手順：視差効果オフで YoseChampionCelebrationView 等から YoseAnimatedHanko / yoseNumberPop が使われる → 揺れ・バーストは止まるが拡縮とスライドは通常どおり動く。YoseCutInBanner は現在どこからも呼ばれていない（死にコード寄り）。
- 直し案：`@Environment(\.accessibilityReduceMotion)` を読み、オンなら scale を 1 固定・アニメ nil・スライドは opacity のみにする。
- 確度：中（使用箇所は YoseChampionCelebrationView のみ確認）

## 付記（バグではない）
- YoseConfettiView の `frozen` は再アクティブ化で戻らないが、全呼び出し元が `if revealed/badgeLanded { ... }` で作り直すため実害なし。
- YosePassCelebrationView の `shownPower` は画面に出していない（数字非表示の仕様）ため GameCore との食い違いは起きない。
- DEBUG 漏れ：なし（YoseFXPreview は本編側から呼ばれていない）。

## 扱い（10/19 自走・ビルド OK）
- §1・§2・§3 直した（§3 は bc96de0）。§4（動きを減らす設定で印の拡縮が止まらない）は軽微＝そのまま（次に演出を触る時にまとめて）。
