# 遅れて走る処理の静的点検（2026-11-08 v0）

**結論**
1. 実害あり 1件：`Design/YoseChampionCelebrationView.swift:475-520`（優勝演出の asyncAfter 5本）。下の「進む」ボタンは演出の途中でも `onFinish` を直接呼び、画面が消えた後も `isCompleted` が false のままなので、決勝 → エンディングの画面で優勝の音・触覚が遅れて鳴る。
2. 条件付き 8件（閉じ方次第で onDismiss／onDone の二重呼び出しや、他画面の通知表示が起きる）。残りは見た目のフラグだけ、または世代番号・Task.isCancelled・`.task` で守られていて安全。
3. 過去に直した「支払い画面・年の幕間・演出の途中閉じ」（code_review_2026-10-19b §1-1／§1-3、19k §3、19l 1-3、1107d/1107e）と重なる所は「既に直し済み」と書いた。同じ型の取り漏れは上記1件。

対象：ManzaiGame/Sources の `asyncAfter`／`Timer`（Timer.scheduledTimer・Timer.publish は 0件）／`Task.sleep`／`.delay()`。読むだけ・コード変更なし。`.delay()` は withAnimation／.animation の修飾で、状態を書き換える遅延ではない（SwiftUI が管理するので除外）。

## 表（実害あり・条件付き）

| ファイル:行 | 形 | 取り消し | 閉じた後の影響 | 分類 | 直すなら |
|---|---|---|---|---|---|
| Design/YoseChampionCelebrationView.swift:475,489,498,509,520 | asyncAfter×5（0.28〜1.15s） | `guard !isCompleted` のみ。進むボタン（:441）が onFinish を直接呼ぶ＝途中で閉じても isCompleted は false のまま | 画面が消えた後に championImpact／stampHeavy／prizeGet の音と触覚が鳴り、`phase`／`shakeTrigger` が書き換わる | **実害あり** | onFinish を呼ぶ前に `isCompleted = true`（ボタンを handleScreenTap 経由にする）か、`.task` + Task.isCancelled に置き換える |
| WeekMainView.swift:327 | `Task{ MZSpeed.sleep 2s; maybeShowDebtNotice() }`（.onChange 内・保持なし） | なし（phase が freeAction かの guard のみ） | 週が変わった2秒後に、別画面に進んでいても通知が出る／`session.clearInjuryNotice()` が走る。週送りを連打すると Task が積み重なる | 条件付き | `.task(id: session.week)` に移す |
| StageFrame.swift:301-312（StageCeremony） | `.task` 内の sleep の後 `guard !done` → finish() | 取り消されても done が false なので、sleep が即戻り → finish() → onDone() が走る | 開演の儀が親に外されると onDone が余計に呼ばれる。TournamentResultView は beginReveal が1回ガード、FinalsPresentationView は `ceremonyDone = true` のみ＝実害は小 | 条件付き | `guard !done, !Task.isCancelled` |
| Design/YoseRankUpOverlay.swift:296-330 | `.task` の runSequence ＋ asyncAfter(0.12) で onDismiss | 途中の guard は `isDismissed` のみ（Task.isCancelled なし） | 取り消されると触覚が一気に鳴り、dismissImmediately → onDismiss。使用箇所は YoseFXPreview（DEBUG の目視）だけ | 条件付き（本番未使用） | 各 sleep 後に `Task.isCancelled` を見る。本番で使う時に直す |
| IntroFlow.swift:687 | asyncAfter 0.45s で onDecide(名前…) | `decided` で二重押しは防ぐが、閉じても取り消しなし | 0.45秒以内に戻る／閉じると、画面を離れた後に onDecide が走り、決定が進む | 条件付き（0.45秒の窓） | `.task` に移すか onDisappear で `cancelled` を立てて見る |
| ComboKindPickerView.swift:39 | asyncAfter 0.3s で onSelect(kind) | `picked` で二重は防ぐ。取り消しなし | 同上（0.3秒の窓で戻ると形が選ばれたまま進む） | 条件付き（0.3秒の窓） | 同上 |
| AbilityUpView.swift:463-470 | Task{ sleep(0.45s); finishConfirm() }（保持なし） | `confirmFinished` で二重は防ぐ。画面の外し方に対する取り消しなし | 余韻中に別経路で閉じられると onClose が二重／遅れて呼ばれうる。余韻中は全面タップでも finishConfirm に行くので窓は狭い | 条件付き | Task を保持して onDisappear で cancel |
| QualifierNoticeView.swift:221-261 | `task = Task{…}` | `.onDisappear { task?.cancel() }` あり。chat 枝の 900ms 後（:232）は `isCancelled` を見ず `msgs = 1` | 状態のみ（音は鳴らさない）。音のある所は19b §1-3で直し済み | 安全寄り（残りは見た目のみ） | :232 の後に isCancelled を足すと完全 |
| QualifierNoticeView.swift:212-213 | DEBUG の `MZ_OPEN` 用 Task | なし | DEBUG のみ | DEBUG のみ（対象外） | 不要 |

## 表（安全・取り消しあり／見た目だけ）

| ファイル:行 | 形 | 取り消し／影響 | 分類 |
|---|---|---|---|
| RentStatement.swift:129-141 | `.task` + isCancelled ×4 | 既に直し済み（19b §1-1） | 安全 |
| FirstStageView.swift:167 | `wait()` が取り消しで false | 既に直し済み（1107d #1） | 安全 |
| Design/YoseMilestoneFX.swift:265-292, 414-443 | `.task` + done/isCancelled | 既に直し済み（1107e #3・19k §1・§2）。:283/:285/:292 は見た目のみ | 安全 |
| TournamentResultView.swift:355-361 | asyncAfter 0.09s で Haptics.rigid | 触覚1発のみ・直後に isCancelled を確認。窓が 0.09秒 | 安全寄り |
| TournamentResultView.swift:260 | Task 0.8s で `nextArmed = true` | 状態フラグのみ | 安全 |
| FinalistAnnounceView.swift:203-232 | pause() が isCancelled を各所で確認 | 取り消しあり | 安全 |
| StageViews.swift:248, AbilityUpView.swift:76,89,94, YoseGameParts.swift:265 | `.task` / `.task(id:)` | 画面が消えると取り消し。YoseGameParts:265 は `message = nil` のみ | 安全 |
| WeekMainView.swift:308,327(.task(id: toast)),1285 | `.task` 内の sleep → `presentRent()`／`toast = nil` | `presentRent` が `!Task.isCancelled` で止める | 安全 |
| Design/YoseGameParts.swift:118-124, CalendarView.swift:177 | asyncAfter + 世代番号（moneyFloatSeq／toastToken） | 世代番号で最新だけ反映 | 安全 |
| Juice.swift:107,163 / Design/YoseEffects.swift:166 | Task／asyncAfter + 世代番号（burstSeq／burstStart） | 世代番号 | 安全 |
| Juice.swift:185,282 | Task で punched／on の戻し | 見た目のみ | 安全 |
| Design/YoseMotion.swift:34,81, YoseEffects.swift:211,596 | asyncAfter 0.08〜0.14s で bump／isPopping／stampReady を戻す | 見た目のみ（0.1秒級） | 安全 |
| Theme.swift:242 | asyncAfter 0.06s で触覚の二連目 | 触覚1発・窓が極小 | 安全 |
| S6bView.swift:135, NetaStage.swift:48, AbilityUpView.swift:296-297, WeekMainView.swift:913,1600 | Task で見た目のフラグ（counted／glow／flash／offerArmed／yearEndArmed） | 状態フラグのみ・他画面を書き換えない | 安全 |
| ChoiceEventOverlay.swift:94,339 | Task で scrollToLast／`footerReady = true` | 見た目のみ | 安全 |
| FinalsPresentationView.swift:1453,1488, YoseChampionCelebrationView.swift:792,897,1005 | `.task` で `frozen = true` | `.task` が取り消されるだけ | 安全 |
| SettingsView.swift:35, NetaSelectionView.swift:57, RootView.swift:224,456, Design/YoseFXPreview.swift:48,51 | DEBUG 専用（MZ_QUIT／MZ_NETA_PICK／MZ_UI／MZ_SOAK／プレビュー） | 本番に入らない | 対象外 |
| Design/YoseRankUpOverlay.swift:332 | asyncAfter 0.12s で onDismiss | 上の RankUp の行に含む | （上に記載） |

## 件数
- 実害あり 1／条件付き 8（うち本番未使用・DEBUGのみ 2）／安全 約20グループ（既に直し済みは RentStatement・FirstStageView・YoseMilestoneFX・QualifierNotice の音）／対象外（DEBUG）4グループ。
- 直す優先順：①YoseChampionCelebrationView の進むボタン → ②WeekMainView:327 → ③IntroFlow:687／ComboKindPickerView:39 → ④StageCeremony。
