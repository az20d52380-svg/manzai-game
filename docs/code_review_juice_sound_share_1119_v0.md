# コード点検 11/19：Juice / SoundManager / ShareCard（読むだけ・コード未変更）

## 要点3行
1. 新規の指摘は6件（中2・低4）。落ちる穴（添字外・強制アンラップ・0除算・NaN）は実質なし。
2. 一番重いのは #1「振動のオフ設定が無い」（設定画面に振動の項目が無く、Haptics は常に鳴る）と、#2「アプリが裏に回って戻った時に BGM を鳴らし直す所が無い」。
3. 直し案はすべて表示・音・振動のみ（GameCore・乱数・数値は触れない）。使われていない部品は0（Juice の6部品・ShareCardView/Button とも呼び出しあり）。

## 節構成
§1 指摘（#1〜#6）／§2 既出（重ねない）／§3 問題なしの所

## §1 指摘

### #1【中】振動（Haptics）を切る設定が無い
- 場所：ManzaiGame/Sources/Theme.swift:228-242（enum Haptics）、Design/YoseEffects.swift:51-58（YoseFX.impact/notify）、SettingsView.swift:13-14（vol_bgm/vol_se だけ）
- 何が起きるか：音量スライダーは BGM/SE だけ。振動は Haptics・YoseFX が `UIImpactFeedbackGenerator` を直接鳴らし、設定でも「視差を減らす」でも止まらない（grep：SettingsView に haptic/振動の語なし）。マナーモード・静かな場所向けの逃げ道が無い。`Haptics.confirm/rare` は連打制限（last）も通らない。
- 直し案：
```swift
// Theme.swift Haptics に共通口を足し、各 generator 呼び出し前に通す
private static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics_on") as? Bool ?? true }
static func fire(_ s: UIImpactFeedbackGenerator.FeedbackStyle, _ i: CGFloat) { guard enabled else { return }; ... }
// confirm/rare/denied の2発目/YoseFX.impact/notify にも `guard enabled`
// SettingsView に Toggle("振動", isOn: $hapticsOn)  // @AppStorage("haptics_on")
```
- 表示のみか：はい（端末の振動だけ。ゲーム数値に無関係）。ただし設定項目の追加はオーナー判断（決めるのはオーナー）。

### #2【中】バックグラウンドから戻った時に BGM を再開する所が無い
- 場所：SoundManager.swift:75-79（interruptionNotification のみ購読）／RootView.swift:360-364（scenePhase は saveNow だけ）
- 何が起きるか：project.yml に UIBackgroundModes(audio) は無い。ホームに出て戻ると AVAudioPlayer は止まったままのことがあり（割り込み通知が来ない経路：通知センター・ロック・他アプリ切替）、`.shouldResume` 付きの終了通知も来なければ、決勝・結果画面（bgm() を最初の1回しか呼ばない画面）は戻った後ずっと無音になる。実機で要確認。
- 直し案：RootView の `onChange(of: scenePhase)` に `if phase == .active { Sound.resumeIfNeeded() }` を足し、SoundEngine に既存 `resumeBGMAfterInterruption()` を呼ぶ公開口を作る。
```swift
// SoundEngine
func resumeIfNeeded() { resumeBGMAfterInterruption() }   // currentBGM が nil なら何もしない既存ガードあり
```
- 表示のみか：はい（音のみ）。

### #3【低】ParticleBurst の count が負・色の配列が空
- 場所：Juice.swift:50（`for i in 0..<count`）・:43（colors 空はガード済み）
- 何が起きるか：count に0未満を渡すと範囲の生成で実行時エラー（0..<負）。現状の呼び出し（22/30/44）は固定値なので出ない。将来、枚数を式で渡す時の地雷。
- 直し案：`for i in 0..<max(0, count)`
- 表示のみか：はい。

### #4【低】EdgePulse（視差を減らす時の代替演出）の点滅が約4回/秒
- 場所：Juice.swift:283-290（0.08s点灯＋0.14s保持＋0.1s消灯＋0.14s保持を2回＝約0.9秒に2回）
- 何が起きるか：2回の明滅は1秒内で3回以下なので光過敏の基準には収まるが、縁12ptの朱が不透明0.85で全周に出る。「視差を減らす」を入れる人は光や動きに敏感な率が高いので、強さを下げる余地あり。さらに `.easeOut/.easeIn` は Theme.Motion.r を通っていない（ここは意図的に動かす代替なので問題なし）。
- 直し案：不透明0.85→0.5、lineWidth 12→8、または1回にする。
- 表示のみか：はい。

### #5【低】SE の「0.06秒以内は捨てる」が種類ごと固定
- 場所：SoundManager.swift:106-113
- 何が起きるか：同じ SE を意図して2連続で鳴らす場面（例：`Haptics.denied` に合わせた deny の二連、拍手の重ね）で2発目が黙って落ちる。意図した二連の有無は呼び出し側 grep で未確認（`Sound.play(.deny)` は2箇所のみ・二連ではない）。実害は今のところ見つからない。
- 直し案：必要になった時に `play(_ se:, force: Bool = false)` を足す。今は直さなくてよい。
- 表示のみか：はい。

### #6【低】SE の音量が 0.01 以下で全断・BGM は 0 でも再生を続ける
- 場所：SoundManager.swift:110（SE）／:150・:167（BGM は volume=0 のまま play）
- 何が起きるか：BGM を0にしても AVAudioPlayer はループ再生を続ける（デコード分の電池を少し使う）。音は出ないので表示への影響なし。
- 直し案：`refreshBGMVolume` で bgmVolume<=0.01 なら `pause()`、戻したら `play()`（currentBGM が非nil の時だけ）。優先度は低い。
- 表示のみか：はい（音のみ）。

## §2 既出（同じ指摘は再掲しない）
- BGM が割り込みのあと戻らない：1108b #1／2026-10-19f §4／1107e #9（済・SoundManager.swift:75-96）。`.shouldResume` が付かない場合の取りこぼし：nss_1116 #2（未対応・#2 はこれとは別経路＝割り込み通知が来ない場合）
- フェード Timer の `.common` 化：2026-10-19f §5（済）／stopBGM の duckFactor 持ち越し：1107e #8（済）
- 音量の既定値の不一致：2026-10-19f §1（済）／ルート変更（ヘッドホン抜き）・secondaryAudioShouldBeSilencedHint 未使用：1108b（未対応）
- ParticleBurst/SpeedLines の Task を取り消さない：misc5_1116 低-1（害なしと判断）／Punch の連続変化：misc5 低-2（`gen` で済）／EdgePulse の並行ループ：misc5 低-3、abilityup_misc_1117 #9（要確認のまま）／ScreenFlash の描画順：1107e #2（実測で問題なし）
- ShareCard：ImageRenderer と task の id：1107b #10-11／画像が前の物のまま：share_settings_1117 #7（済）／名前の置換（Names.show）：1108d／ダミー枠を読み上げから外す：1116_night

## §3 問題なしの所
- 落ちる穴：Juice の割り算は `t / life`（定数）・`fi/24`・`(1-p)` だけで 0除算なし。`jhash` の sin は有限値で NaN にならない。ShakeEffect は `rounded(.down)` で p が範囲内のみ処理。SoundManager の `steps = max(1, …)`、`pool.count < 3` の添字なし、強制アンラップなし（`if let / guard let` のみ）、ShareCard にも強制アンラップ・添字なし。
- 視差を減らす：ParticleBurst・SpeedLines・Punch・Shake は guard で完全停止、Flash は最大0.12・0.5秒に弱める、アニメは Theme.Motion.r 経由。EdgePulse は逆に減らす時だけ動く。
- VoiceOver：ParticleBurst・SpeedLinesBurst は View と Canvas の両方が `accessibilityHidden(true)`。Flash/EdgePulse の色の覆いは中身がなく読まれない。ShareCardButton のダミー枠も非表示。ShareLink には「共有」ラベルあり。
- 大きい文字：ShareCardView は画像用の固定サイズ（720×720・意図どおり）で文字サイズ設定に左右されない。見出し・名前は minimumScaleFactor 0.4＋lineLimit で切れ対策済。ボタン側は `YoseFont.gothic`（mzScaled）で追従。
- 音の二重再生・止め忘れ：SE は面3つのプール再利用、BGM は同曲なら音量だけ追従、別曲は旧曲を0.5秒でフェードアウトして stop。`hushSE` は Task が必ず戻すので固着しない（FinalsPresentationView:364-387）。タイトル戻し・エンディングで stopBGM 済（RootView:354/369）。
- 使われていない部品：なし。呼び出し数（Juice/SoundManager 自身を除く）：ParticleBurst 7・SpeedLinesBurst 1・punch 5・screenFlash 4・screenShake 4・edgePulse 1・ShareCardButton 2・ShareCardView は ShareCardButton 内で使用・Sound.duck/hushSE 10・stopBGM 5・refreshBGMVolume 2。
- 乱数・数値：Juice は sin ハッシュの決定論、SoundManager の `Float.random` は音程±3%の表示専用で GameCore の RandomSource とは無関係。
