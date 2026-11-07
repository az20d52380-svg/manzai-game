# コード点検 11/08b（実機の割り込みと端末の状態：音声・ライフサイクル・通知・課金。読み取りのみ）

範囲：SoundManager.swift、RootView.swift の scenePhase、各画面の Task.sleep／asyncAfter、IntroFlow の通知許可、StoreManager／GachaView／GachaStore。
既出：code_review_1107e #9、2026-10-19f §4・§5・§6、2026-10-19d。重複は「既出」と書く。シミュレータ・実機は使っていない（実機でしか確かめられないものは明記）。

## 指摘（高 0／中 1／低 4）

1. **【中】電話・Siri・アラーム等の割り込みで止まった BGM が、`playBGM` の同曲分岐を通らない長い画面では、割り込みが終わっても戻らない**
   - 場所：SoundManager.swift:69-73（セッション設定）・:105-108（同曲分岐）。`interruptionNotification` の購読は全ソースに無い（grep で確認済み）。
   - 手順：決勝の番組（FinalsPresentationView。`Sound.bgm(.finals)` は onAppear の1回だけ :241）または結果画面（TournamentResultView :321）の最中に電話が来て切れる → AVAudioPlayer は停止したまま、`Sound.bgm` は次に別の画面が呼ぶまで来ない → その画面の残り（決勝は数分あり得る）が無音。
   - 結果：音だけ消える。ゲーム状態は壊れない。次に `Sound.bgm(.daily)` 等が来る画面（WeekMainView.onAppear :318）で戻る＝19f §4 で直った分はここ。
   - 既出：1107e #9 と 19f §4 の「同曲分岐で再開」は対応済み。今回は「その分岐に届かない画面」の残り。直し案：`AVAudioSession.interruptionNotification` の `.ended`（`shouldResume` を見て）で `setActive(true)` ＋ `bgmPlayer?.play()`。
   - 確かさ：購読が無いことはコードで確認済み。割り込み後に AVAudioPlayer が止まったままかどうかと戻り方は実機のみ（推測）。重さ：中。

2. **【低】イヤホン・Bluetooth を抜いた時（routeChange）の扱いが無い**
   - 場所：SoundManager.swift 全体（`routeChangeNotification` の購読なし。grep 確認済み）。
   - 手順：イヤホンで BGM 再生中に抜く → 音はスピーカーへ移る。AVAudioPlayer が自動で止まるかは OS 任せ。止まった場合は #1 と同じで次の `bgm()` まで戻らない。
   - 結果：電車内で突然スピーカーから大音量が出る（再生が続く場合）。マナーモード時は `.ambient` なので鳴らない。
   - 確かさ：推測（実機のみ）。重さ：低（出るなら恥ずかしさの方。`oldDeviceUnavailable` で一時停止する程度の保険）。

3. **【低】他アプリの音楽が鳴っていても BGM を重ねて鳴らす（意図どおりだが切る手段が設定の BGM スライダーのみ）**
   - 場所：SoundManager.swift:71 `.ambient`。`secondaryAudioShouldBeSilencedHint` は未使用（確認済み）。
   - 手順：Spotify 等を流したまま起動 → 曲と BGM が同時に鳴る。ambient は他アプリを止めない仕様。
   - 結果：好みの問題。起動時に他の音が鳴っていれば BGM を自動で絞る案もある（決めるのはオーナー）。
   - 確かさ：コードで確認済み。重さ：低。

4. **【低】決勝の祝賀演出（YoseChampionCelebrationView :475-520）の `asyncAfter` が、バックグラウンドから戻った瞬間にまとめて鳴る可能性**
   - 場所：Design/YoseChampionCelebrationView.swift:475・489・498・509・520（0.28〜1.15秒の時刻指定で効果音・触覚）。
   - 手順：優勝の演出が始まった直後（1秒以内）にホームへ → 戻る。
   - 結果：既に過ぎた時刻の処理が戻った時に連続で実行され、効果音・触覚が一度に重なる。演出の1秒以内の窓だけ。状態は壊れない。
   - 確かさ：推測（asyncAfter が端末の一時停止中に時間を数えるかは実機で確認が必要）。重さ：低。

5. **【低】通知の許可を求めるだけで、通知は何も送らない・受け取る処理も無い**
   - 場所：IntroFlow.swift:751（`requestAuthorization` のみ。`UNNotificationRequest`・`UNUserNotificationCenterDelegate`・`didReceive` は全ソースに無い。grep 確認済み）。
   - 確認できたこと：許可を拒否した後の分岐は存在しない（結果を捨てている）。`asked = true` は押した時点で立つので再表示されない＝問題なし。通知から起動する遷移は存在しない＝該当なし。
   - 注意点：何も送らないのに許可を求める作りは、審査で理由を聞かれる可能性がある（将来通知を入れる前提か、ダイアログごと外すかはオーナーの判断）。
   - 確かさ：コードで確認済み。重さ：低。

## 問題なしと確かめた項目
- **消音スイッチ**：`.ambient` ＝ マナースイッチに従い、他アプリの音と混ざる（SoundManager.swift:71）。SE は vol_se≦0.01 または seHushed で早期 return（:78 付近）。
- **バックグラウンド再生**：project.yml に UIBackgroundModes が無い（grep 確認済み）。ホームへ戻ると OS が音を止める＝「音だけ鳴り続ける」は起きない（実機で再確認する余地はあるが設計上は正しい）。
- **フェード Timer**：`.common` モードで登録、プレイヤーごとに取り消す（SoundManager.swift:153-170）。画面のスクロール中でも止まらない（19f §5 で対応済み）。
- **割り込み中の SE**：`play()` は `!isPlaying` の面を再利用し `currentTime=0` から鳴らす。止まった面が残って詰まることはない（コード確認済み。実機の鳴り方は未確認）。
- **セーブ**：RootView.swift:331 の `.background` で `saveNow()`。各入力確定点でも保存されるので、強制終了（スワイプ終了も `.background` を通る）・演出の途中でも直前の確定点まで戻るだけ。`.inactive`（着信画面・コントロールセンター）では保存しないが、確定点保存があるので実害なし。
- **演出の続き方（Task.sleep／.task）**：多くが `.task`／`onDisappear` で取り消される（19d で確認済み）。Task.sleep は連鎖の各段が自分の長さだけ待つので、戻った時に演出が丸ごと飛ぶことはない（段単位で進むだけ・推測を含む）。重複起動は onAppear の `dataCache == nil` ガード（FinalsPresentationView :226）などで防いでいる。
- **3秒の「押し直し待ち」フラグ**（WeekMainView :913・:1600）：背景に行っても無害。
- **課金の途中でバックグラウンド・強制終了**：`StoreManager.shared` を起動時から作り `Transaction.updates` を聞く（ManzaiGameApp.swift:10）。券は `handle()` 内で `credit`（取引IDで二重付与なし・GachaStore.mutate が即 persist）→ `finish`。購入後の抽選前に落ちても `paidPending` が残り、GachaView の `.task`（:69）と `run(nil)` で未開封分を回せる。GachaView の `Task` は画面を閉じても動き続けるが、状態は GachaStore に書かれるだけで無害。
- **広告**：広告 SDK のコードは無い（`isAdFree` の所有判定のみ）。割り込みの確認対象なし。

## 実機でしか確かめられないもの
- #1 の割り込み後の BGM の戻り方、#2 の抜いた時の挙動、#4 のバックグラウンド復帰時の時刻処理。
- ホームへ戻って数分後に戻った時の BGM（ambient かつ背景モードなしでの再生状態）。
