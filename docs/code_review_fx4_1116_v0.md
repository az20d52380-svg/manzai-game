# コードレビュー fx4（11/16・読むだけ）
対象：Design/YoseGameParts・YoseMilestoneFX・YoseEffects・YoseRankUpOverlay。既存の code_review_1107e・2026-10-19k/l・2026-10-27b・1111_fixes を照合済み。

## 要点（3行）
1. 新規の実害は1件（中）：YoseRankUpOverlay の `try? Task.sleep` が取り消しを握りつぶし、取り消し後に触覚と onDismiss が走る。
2. 低・要確認が2件（items が空だと onDismiss が呼ばれない／タブバーの `indices` ForEach）。
3. YoseMilestoneFX・YoseGameParts のトースト・YoseEffects の Task は取り消し対策済みで、既出の指摘（1107e #4・#6）は再掲のみ。

## §1 件数
高 0／中 1／低 1／要確認 1（既出の再掲は別枠で2件）

## §2 指摘
| # | 重要度 | 場所 | 失敗の場面 | 直し方 |
|---|---|---|---|---|
| 1 | 中 | YoseRankUpOverlay.swift:287・296・304・306・310・316・320・326（`.task` は :114） | 親が overlay を外して `.task` が取り消されても `try? await Task.sleep` は即戻るだけ。`isDismissed` はタップ時しか立たないので `guard !isDismissed` を通り抜け、重い触覚2回と通知触覚が連続で鳴り、最後に `dismissImmediately()` → 0.12秒後に `onDismiss()` が余計に呼ばれる（親が既に閉じた後の二重呼び）。reduceMotion 側（:287-289）も同じで、取り消し後に即 dismiss する。現在の呼び元は DEBUG の YoseFXPreview.swift:18 だけだが、本編へつなぐ時に出る。1107e #3 を直した PassCelebration／BigSuccess と同種。 | 各 sleep の直後を `if isDismissed \|\| Task.isCancelled { return }` にする（:287 後は `guard !Task.isCancelled else { return }`）。:296・:311・:321 の guard も同様。 |
| 2 | 低（要確認） | YoseRankUpOverlay.swift:75-76（`if let main = primary`） | `items` が空だと中身が空で `.task`／onDismiss が一切走らず、呼び手が「onDismiss で状態を戻す」形だと表示フラグが残る（タップは何も遮らない）。 | 呼び手で空を弾くか、`else` で `Color.clear.task { onDismiss() }`。 |
| 3 | 低 | YoseGameParts.swift:80付近 `YoseFooterTabBar`（:164-172）・`YoseTopTabBar`（:130-142）の `ForEach(xxx.indices)` | 配列の長さが動的に変わると `items[idx]`／`tabs[idx]` が範囲外になる既知の SwiftUI の穴。今の呼び手は固定個数のため実害なし。 | `ForEach(Array(items.enumerated()), id: \.offset)`。 |

### 既出・再掲のみ（新規ではない）
- YoseMilestoneFX.swift:146 `finished` 後の連打で `onFinish` が複数回（1107e #6・低・呼び元で保険済み・本編の呼び手なし）。
- YoseEffects.swift:409-412 `frozen` が戻らない（1107e #4・低・使い回しの有無は未確認）。

## §3 問題なしと確かめた所
- YoseMilestoneFX：PassCelebration `run()` は取り消し・done の両方で return（:266・:274・:289）。reduceMotion は `snapToFinal()` で即終了。BigSuccessCutIn は reduceMotion でも1.2秒後に onFinish、取り消しなら呼ばない（:415・:444）。BigSuccess の全体に `.allowsHitTesting(false)`（:338）、装飾の紙吹雪・フラッシュ・斜光も同様で、見えない overlay が操作を塞ぐ所なし。
- YoseGameParts：トーストの `.task(id: m)` は `do/catch {}` で取り消し時に消さない（:265-270）。金額の浮き文字は `moneyFloatSeq` で古い asyncAfter を無効化（:118-124）。`.allowsHitTesting(false)`（:106）あり。
- YoseEffects：`yoseShake` の Task は最後に必ず 0 へ戻る（重なっても終端は 0）。YoseBurstParticles・NumberPop・StampBanner の asyncAfter は状態比較か冪等な代入のみ。スタンプ帯は `.allowsHitTesting(false)`（:603・:659）。
- YoseRankUpOverlay：二重 `onDismiss` は `isDismissed` ガードで防止、後光・紙吹雪・フラッシュは hit テストなし。onAppear での再始動は無い（`.task` のみ）。
