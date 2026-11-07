# コード点検 11/07e（音・演出・購入まわり。読み取りのみ。1107/b/c/d の項目は除く）

範囲：SoundManager／Juice／Design/YoseEffects・YoseYearTurnCurtain・YoseMilestoneFX・YoseRankUpOverlay・YoseGameParts／FinalistAnnounceView／StageScene／Store/StoreManager／MeetingKind。
観点：閉じた後も動くもの、二重実行・固まる経路、MZSpeed／視差を減らす、消音、範囲外・0除算・force unwrap、購入と復元。数式・GameCore・golden は対象外。

| # | ファイル:行 | 具体的に何が起きるか | 重さ | 直し方の案 |
|---|---|---|---|---|
| 1（済 e6c8e00） | Design/YoseEffects.swift:45-49 `YoseFX.onPlaySound`（どこにも代入なし）／YoseChampionCelebrationView.swift:485・516・528／YoseEffects.swift:494 | `YoseFX.sound()` は呼び先が空なので何も鳴らない。優勝演出（champion 画面）の衝撃・判子・賞金の音は出ない。THE HANA 決勝の通過（TournamentResultView.swift:~296 の showHanaChamp）は、この画面を使うのに `Sound.play(.fanfare)` などの呼び出しも無く（fanfare は FinalsPresentationView:1144 と YearResultView:86 だけ）、優勝の瞬間が無音になる。GP決勝は別経路で鳴る。 | 中 | `onPlaySound` を Sound.play に繋ぐ（stampHeavy→.taiko、championImpact→.don、prizeGet→.money など）か、champion 画面の入口で `Sound.play(.fanfare)` を1回鳴らす。HANA優勝の無音は実機未確認（コード上の推測）。 |
| 2（問題なしと実測 11/07：body を記録する一時テストで 0→0.9→0 を確認＝withAnimation の前に 0.9 が描かれる。直さない） | Juice.swift:211-214（ScreenFlashModifier）／YoseMilestoneFX.swift:272・412・427／YoseChampionCelebrationView.swift:477-479 など `x = 0.22; withAnimation { x = 0 }` の型 | 同じ処理の中で「値を上げる→すぐアニメで0へ」と書くと、SwiftUI は描画前の値(0)と最終値(0)の差しか見ないので、閃光が一度も見えない可能性がある。 | 低〜中（推測） | 目視（MZ_FX=pass／burst、判子の画面）で閃光が出るか確認。出ないなら上げた後に `DispatchQueue.main.async` か1フレーム待ってから0へ戻す。 |
| 3（済 e6c8e00） | YoseMilestoneFX.swift:260-295（PassCelebration）・412-445（BigSuccess） | 画面が閉じて Task が取り消されても `try? Task.sleep` は即戻るだけで、以降の `UIImpactFeedbackGenerator`（light／rigid／heavy）と `UINotification success` が一気に連続で鳴る。BigSuccess は最後に isCancelled を見て onFinish だけ止めるが、触覚は止まらない。RankUp（YoseRankUpOverlay:296-320）は isDismissed で止まるので問題なし。 | 低 | 各 sleep の後に `if Task.isCancelled { return }` を入れる（`done` と同じ位置）。 |
| 4 | YoseEffects.swift:409-412・376（YoseConfettiView の `frozen`） | `frozen` は 16.5 秒後に true になり、false に戻る所が無い。同じ View が `isActive` を false→true と切り替えて使い回されると、2回目は描画が止まったまま（紙吹雪が止まった1コマで固まる）。今の呼び出しは出す時に作る形が多く、使い回しは確認していない。 | 低（推測） | `.task(id: isActive)` にして先頭で `frozen = false`、`startDate = Date()` を入れる。 |
| 5 | FinalistAnnounceView.swift:110・198-201（`task` は onDisappear の cancel 後も非 nil） | 画面が一度消えて(例：上に NavigationStack で別画面が重なる)戻ると `start()` は `task == nil` でないので再開せず、取り消し済みの Task のまま ①の待ち画面で止まる。「飛ばす」で抜けられるので固まりはしない。TournamentResultView の overlay で使う今の形では onDisappear は閉じる時だけなので、現状は起きない。 | 低 | `.onDisappear { task?.cancel(); task = nil }`。 |
| 6 | YoseMilestoneFX.swift:146（`onTapGesture { if finished { onFinish() } ... }`） | `finished` が立った後に素早く2回タップすると onFinish が2回呼ばれる（`showPass = false; session.acknowledgeResult()`）。acknowledgeResult は pendingResult で弾くので週が2つ進むことは無い（GameSession.swift:968）。BigSuccess は hit テスト無しで二重にならない。 | 低 | 呼び出し側の保険で足りている。気になるなら `guard !closed` を持つ。 |
| 7 | YoseMilestoneFX.swift:146／FinalistAnnounceView.swift:109（`.onTapGesture` だけで閉じる画面） | PassCelebration は閉じる手段が画面全体のタップだけ（Button が無い）。VoiceOver で「つづける」相当を選べない可能性がある（onTapGesture が親コンテナの操作として出るかは未確認）。FinalistAnnounce は「つづける」Button があり問題なし。 | 低（未確認） | `.accessibilityAddTraits(.isButton)` と `.accessibilityLabel("つづける")` を足す。 |
| 8（済 e6c8e00） | SoundManager.swift:136-140 `stopBGM`／:63 `duckFactor` | `duck(0.3)` の後に duck(1) が来る前に stopBGM → 次の BGM が絞ったまま（duckFactor が残る）始まる。duck(1) を呼ぶ側（StageFrame:312・FinalsBroadcastIntro:394・FinalsPresentationView）は必ず通る作りなので今は起きにくい。画面を飛ばして閉じる経路があれば起きる（推測）。 | 低 | `stopBGM` 内で `duckFactor = 1` に戻す。 |
| 9 | SoundManager.swift:69-73・112-128（AVAudioSession） | 電話・Siri 等の割り込み後にセッションを再有効化する処理が無い。BGM は次の `playBGM` で鳴らし直す(19f §4)が、SE は割り込み後に鳴らない場合がある（実機で未確認・推測）。割り込み通知の監視は無し。 | 低（推測） | `AVAudioSession.interruptionNotification` で `.ended` 時に `setActive(true)` と BGM の再生を呼ぶ。 |
| 10（済 e6c8e00） | StoreManager.swift:97-104 `updateEntitlements` | 検証できなかった権利(`.unverified`)は無視して ownedIDs を作り直し、控え(store_owned_ids)も上書きする。一時的に検証に失敗した起動で広告なし(isAdFree)・黒紋付が外れ、再起動まで戻らない。 | 低〜中 | 空になる場合や前回より減る場合は控えを上書きしない（`.unverified` なら前回の控えを残す）。 |
| 11（済 e6c8e00） | StoreManager.swift:87-95 `handle`（Transaction.updates の払い戻し） | 取引の `revocationDate` が付いた更新（払い戻し）でも `ticketCounts` に当てはまれば `credit` を呼ぶ。台帳に無い取引ID（未付与のまま先に払い戻しが届く）なら、払い戻された券が付与される。先に付与済みなら txID で弾かれる。 | 低 | `tx.revocationDate == nil` の時だけ credit する。 |
| 12（済 e6c8e00） | StoreManager.swift:36-44 `refresh`／:49 | 商品取得が一度失敗(オフライン起動)すると `products` が空のまま、購入ボタンを押すと「商品が見つかりません」だけで再取得しない。画面を開き直すまで買えない。 | 低 | `purchase` の先頭で products が空なら `await refresh()` を1回呼ぶ。 |
| 13 | YoseGameParts.swift:262-266（`.task(id: m)` のトースト） | 同じ文言を表示中にもう一度同じ文言を入れると id が変わらず、1.8秒の計時が延びない（先の分で消える）。実害は短く消える程度。 | 低 | 必要なら message に連番を持たせる。 |

## 確かめて問題なしだった点
- 消音：`play` は vol_se ≦ 0.01 で鳴らさない。BGM は vol_bgm=0 で音量0のまま回る(鳴らないので問題なし)。AVAudioSession は `.ambient`＝マナースイッチに従い他アプリと混ざる。`hushSE(true)` は FinalsPresentationView の2か所とも Task の中で必ず false に戻す（MZSpeed.sleep 後。画面が閉じても Task は取り消されないので戻る）。
- フェード：Timer は `.common` で add、終了時と cancelFade で invalidate。同じ player のフェードは取り消してから張り直し＝Timer が残り続ける所は無い。0除算なし（steps は max(1,…)）。
- Juice：視差を減らすでは粒・集中線・揺れ・パンチが止まり、閃光は弱く0.5秒、EdgePulse が代わりに2回明滅。どれも完了コールバック無し＝固まらない。`colors` 空・count 0 でも落ちない。バースト終了後は TimelineView を破棄。
- 視差を減らす：YearTurnCurtain は即最終状態、RankUp は1.1秒後に dismiss、BigSuccess は1.2秒後に onFinish、PassCelebration は最終状態でタップ待ち、StageScene の呼吸 repeatForever は開始しない。DustField は paused。固まる所なし。
- MZSpeed：対象ファイルのどれも MZSpeed を使わず実時間。「はやい」で縮んで崩れる所は無い（FinalistAnnounce は「飛ばす」と タップ送りあり）。
- YearTurnCurtain：`hasTriggeredStart` で二重タップを弾く。`kanjiNumber`：n<0 は max(0)、20以上は数字の桁ごと(Int 変換は ?? 0)＝落ちない。pause の戻り値で取り消し時に触覚を止める。
- RankUp：`isDismissed` で二重 dismiss を弾く。ただし本編では未接続(Design/YoseFXPreview だけが使う)。items 空だと何も出ず onDismiss も呼ばれないので、本編接続する時は空を弾くこと。
- FinalistAnnounce：`swapAt` の添字は常に count 未満、`readOrder` が空でも for は回らず落ちない。skipAll で Task を取り消し、実行中の各段で isCancelled を見て抜ける。
- StageScene：DustField の period は size.height+40 で正（0除算なし）。force unwrap・配列直アクセスの危ない所なし。
- StoreManager：購入は取引ID で付与し finish の前に付与、`pending`／`userCancelled`／unknown は false を返し、非消耗は owns(id)、券は handle の戻りで判定。`AppStore.sync` の userCancelled は無言、他は文言を出す。起動時に sync を呼ばない。
- MeetingKind：`from(nil/不正値)` は高校の同級生。配列アクセスは DEBUG の debugForced だけで範囲確認あり。文言に実在名・関西弁なし。

## 未確認
- #1 の HANA 優勝の無音（実機で聞いていない）、#2 の閃光（目視していない）、#4 の使い回しの有無、#7 の VoiceOver の動き、#9 の割り込み後の SE。
- YoseChampionCelebrationView・FinalsBroadcastIntro・StageFrame は今回の対象外で、#1 #2 に関わる所だけ見た。
- 画面を背景に送って戻った時の BGM の続き(AVAudioPlayer と .ambient の挙動)は確かめていない。
