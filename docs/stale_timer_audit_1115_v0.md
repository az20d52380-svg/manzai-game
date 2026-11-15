# 古い時計の上書き監査（2026-11-15 v0）

対象: ManzaiGame/Sources 全体（読むだけ・未変更）。型＝投げっぱなしの `Task { sleep → @State 書き }`／`asyncAfter` が、待ちの間に別経路で変わった状態を上書きする。
結論: 実害のある「確定フラグを早く消す／別の値を上書き」型は **見つからず**。残るのは見た目だけの低（8件）。offerArmed と同型で唯一「確認フラグ」なのは yearEndArmed。

## §1 指摘

### 1. AbilityUpView.swift:296-297 plusTap の bumped／flash（低・確信 高）
- 手順: 能力の＋を連打。行Aを t=0 に押す（flash=A、250ms後に nil の時計が走る）→ 行Bを t=0.2s に押す（flash=B）→ t=0.25s に A の時計が flash=nil を書く。bumped も同様（100ms の時計が次のタップの bump を縮める）。
- 症状: 連打中、2打目以降の山吹の光・拡大が0.05s程度で消える（光がちらつく）。値（taps）は壊れない。
- 直し: `@State flashGen` を足し、タップごとに +1、`let g = flashGen` を取って時計側で `if flashGen == g` のときだけ nil（bumped も同じ番号で可）。

### 2. WeekMainView.swift:1601-1607 yearEndArmed（低・確信 低＝今は到達困難）
- offerArmed（2026-11-15 修正済）と同じ型で番号なし。手順: 「年末へ」を押して arm（時計A=3.0s）→ 実行で false → 3秒以内に同じタイルがまた出て再 arm → 時計Aが再 arm を 3.0s に早消し。
- 実行（fastForwardToYearEnd）後は画面が年末へ進みタイルが消えるため、再 arm が3秒以内に起きる経路は見つからず。
- 直し: offerArmGen と同じく `yearEndArmGen` を足して `if yearEndArmGen == gen`。予防の統一（1分）。

### 3. WeekMainView.swift:1435・330 toast の同文再設定（低・確信 中）
- `.task(id: toast)` は文字列が同じだと再起動しない。手順: 「お金が足りない。」を t=0 に出す→ t=1.3s に同じカードをまた押して showToast（同文）→ 時計は t=0 起点のまま 1.4s で消える（2回目は0.1sしか見えない）。
- 直し: `toastSeq += 1` を showToast に足し、`.task(id: toastSeq)` に変える（toast を nil にするのは今の do/catch のまま）。

### 4. WeekMainView.swift:1510-1513 maybeShowLastYouthNotice の遅延トースト（低・確信 中）
- toast が出ている間に年初の週になると 4.5s 待ち、その間に出た別のトースト（例: 「もう一度押すと…」の arm トースト）を、待ち終わりに無条件で上書きする。取り消しもされない。
- 直し: 待ち後に `if toast == nil` を再確認するか、待ち終わりに Task.isCancelled／週一致（session.year == cap）を見る。

### 5. NetaStage.swift:48（低・確信 高）
- 仕上がりが0.9s以内に2段上がると、最初の時計が2回目の glow を早く消す。実際は1画面で連続昇段は稀。直し: 世代番号。

### 6. 見た目だけの同型（低・確信 高・直さなくてよい）
- Juice.swift:185 PunchModifier（140ms）、Design/YoseMotion.swift:34・81（bump 80ms）、Design/YoseEffects.swift:211（isPopping 140ms）、:596（stampReady）: 値が短間隔に2回変わると前の時計が後の跳ねを縮める。数十msで目立たない。
- WeekMainView.swift:1391 gaugeFlash: 体力ゾーンが0.6s以内に2回悪化すると明滅Taskが2本重なり点滅がずれる（終端は必ず false）。

## §2 問題なしと確かめた主な所
- offerArmed(WeekMainView:920): offerArmGen で修正済、確定時(887・923)の false も整合。
- 世代・token で守られている: Juice.swift:106（burstSeq）・:162（seq）、YoseGameParts.swift:118-124（moneyFloatSeq）、CalendarView.swift:177（toastToken）、YoseEffects.swift:166（burstStart==start）、YoseChampionCelebrationView（isCompleted/isGone ガード）、YoseRankUpOverlay:325（isDismissed）。
- 保持して cancel している: QualifierNoticeView（task を open/pickOpen で cancel し isCancelled を確認。チャットの msgs=1 は選択肢が msgs>=1 で出るため pickOpen と競合しない）、FirstStageView（start→press で cancel）、FinalsPresentationView（holdingSeventh ガード:346・495、voteTailTask は onDisappear で cancel）。
- 多重実行ガード: ComboKindPickerView:39（picked）、IntroFlow:693（decided）、AbilityUpView.finishConfirm（confirmFinished）、GachaView.run（busy）、ChoiceEventOverlay.armFooterIfNeeded（footerReady ガード＋choose で再 arm、旧時計は発火済みで競合なし）。
- tapOrQueue（WeekMainView:1288）: burstHold は presentRent まで保持（defer）、run 内でも pulledID/burstHold/pendingChoiceEvent を再確認、3秒上限で捨てる＝古い押下は実行されない。
- 同じ通知を呼ぶ複数 Task（onAppear 0.7s・week 2s・pendingChoiceEvent 0.5s・burstHold 0.3/0.6s → maybeShowDebtNotice 等）: 各関数が debtNotice/rent/showEvent/burstHold と1回きりのマーカーで再判定するため二重表示なし。
- TournamentResultView:260 nextArmed: revealedRest は1回だけ true になり、0.8s 時計と競合しない。S6bView:135 counted は true にしか書かない。YoseEffects shake(:264)・Juice:279 は重なっても最終値が固定（0／false）。
- .task / .task(id:) 系・DEBUG／MZ_* フック（SettingsView:35、NetaSelectionView:57、WeekMainView:108-113、YoseFXPreview、RootView:242・soakLoop）は対象外。GachaStore:25・StoreManager は購読で時計ではない。
