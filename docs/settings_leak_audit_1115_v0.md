# 設定・端末配慮の効き漏れ点検（2026-11-15・読むだけ・コード変更なし）

## 0. どんな設定があるか（一覧）

| 設定 | 場所 | 効かせる口 | 保存 |
|---|---|---|---|
| BGM 音量 | SettingsView.swift:13 `vol_bgm`（既定0.6） | SoundEngine.bgmVolume（SoundManager.swift:100） | UserDefaults 直読み（再生のたび） |
| SE 音量 | SettingsView.swift:14 `vol_se`（既定0.8） | SoundEngine.play が毎回読む（L108） | 同上。0.01 以下は鳴らさない |
| 演出の速さ（ふつう/はやい） | SettingsView.swift:15,51 `anim_speed`（0/1） | MZSpeed.sleep（0.5倍）。使用は WeekMainView 16・FinalsPresentationView 11・FinalsBroadcastIntro 3・TournamentResultView 3・YearResultView 4 | `integer(forKey:)==1` だけ速い。それ以外は通常 |
| 視差を減らす（reduceMotion） | 端末設定 | `Theme.Motion.r()`（Theme.swift:206）／`@Environment(\.accessibilityReduceMotion)`（26ファイル） | 端末側 |
| 大きい文字 | 端末設定 | `Font.mzScaled`（上限1.35倍・Theme.swift:259）／YoseFont | 端末側 |
| 振動 | **アプリ内の設定なし**（端末のシステム設定のみ） | Haptics（Theme.swift:228）ほか | なし |

## 1. 指摘（件数 6：中0・低6）

### #1 週札・チップ・結果チップの「ばね＋拡大/移動」が reduceMotion でも動く（低・確信 高・既出なし）
- WeekMainView.swift:329（毎週の「第N週」札＝`withAnimation(Theme.Motion.emphSpring)`・出現は scale 0.82→1・L450）／WeekMainView.swift:1226-1228（バーストの上昇チップ：offset16＋scale0.7＋ばね＋遅延）／ChoiceEventOverlay.swift:162 と :327（効果チップの scale0.6→1 のばね）。
- 何が起きるか：「視差を減らす」オンでも、毎週1回の札と、バースト・イベントのチップが拡大して跳ねる。小さい動きだが、毎週必ず出る（#329）。同じ画面の他の動き（L1258・L631・L924）は `Theme.Motion.r`／`reduceMotion` で止めているので、ここだけ漏れている。
- 直し方：`Theme.Motion.emphSpring` を使う4か所を `reduceMotion ? nil : …`（`.delay` を付ける所は `reduceMotion ? nil : emphSpring.delay(..)`）に。札は transition も `reduceMotion` で `.opacity` のみにする。
- 補足：`Theme.Motion.appear/appearQuick/exit` を素で使う約20か所（NotebookView・WeekMainView L657-1015・NetaSelectionView・ChoiceEventOverlay L143/274/293）は短いフェード/開閉で、動きは小さい＝対象外扱い（低以下）。

### #2 「はやい」を素通りする演出の待ち（低〜中・確信 中・既出なし。B-13 final-silence とは別の場所）
- QualifierNoticeView.swift:218（通知が出るまで1.2秒）・:250（結果行の前の間 1.1秒/落選2.6秒）・:255（結果行の間 0.8/1.4秒）／StageFrame.swift:301,305（開演の客電→スポットで計1.0秒。初回は reduceMotion 時だけ短縮）。
- 何が起きるか：設定文「大会・結果の演出が速くなる」（SettingsView.swift:56）なのに、予選通知と開演は「はやい」でも変わらない（同じ大会演出の他画面は MZSpeed を通す）。
- 対象外にしてよい所：QualifierNotice :232（目で探す間＝読む時間）・:255 の結果行（読む行）・:250 の落選の無音（演出意図。縮めるかは B-13 と同じ「縮めない」判断になる）。FirstStageView の `wait()`（L167・初舞台は一度きりの導入で設定文の範囲外）・YoseRankUpOverlay の固定待ち（アニメ長と同期＝縮めない側が正しい）・YoseChampion/FinalsPresentation の「実時間のまま」コメント付き（描画時刻と同期）。
- 直し方：QualifierNoticeView:218 と StageFrame:301/305 を `MZSpeed.sleep` に。落選の無音（:250）は決める論点（「縮めない」なら今のままで良い）。

### #3 振動の設定がない／震わせる口が3系統に分かれている（低・確信 高・既出なし）
- 設定：SettingsView に振動のオン/オフが無い。端末の「システム触覚」設定頼み。ストア審査上は問題ないが、静かな場所で切りたい人がアプリ内では切れない（決めるのはオーナー）。
- 口の分裂：`Haptics`（Theme.swift:228・連打間引き付き・約32呼び出し）を通さず、`UIImpactFeedbackGenerator`／`UINotificationFeedbackGenerator` を直接呼ぶ所が約19か所。FinalsBroadcastIntro.swift:360,371,386／RentStatement.swift:140／YoseMilestoneFX.swift:267,276,290,421,428／YoseYearTurnCurtain.swift:377,388,399,417／YoseRankUpOverlay.swift:298,312,328／YoseMotion.swift:16、そして YoseFX.impact/notify（YoseEffects.swift:51-58）。
- 何が起きるか：今は設定が無いので「素通り」の実害は無いが、将来トグルを足す時に直接呼びが全部漏れる。0.08秒の間引きも効かない（連続で鳴る）。
- 直し方：オーナーが「振動オフ」を付けると決めた時に、`Haptics` に `enabled` ゲート（`UserDefaults "haptics_on"`）を1つ置き、直接呼びを `Haptics.confirm/rare/tick/soft` か新しい `Haptics.notify(_:)` に寄せる。付けないなら直し不要。

### #4 鳴っている最中の SE には音量変更が効かない（低・確信 高・実害ほぼ無し・既出なし）
- SoundManager.swift:108,117-121：SE の音量は `play` の瞬間に決まる。
- 何が起きるか：数秒続く SE（優勝 fanfare・拍手・大歓声）の最中に音量を変えても、その1回は鳴り切るまで旧音量。設定画面は週メインから開くので、長い SE と重なることはほぼ無い。
- 直し方：不要（やるなら `sePlayers` の全面に `volume` を再設定する `refreshSEVolume()`）。

### #5 BGM 音量スライダーが進行中のフェードに上書きされる（低・確信 高・**既出**）
- SoundManager.swift:167 `refreshBGMVolume` は進行中のフェードを取り消さず直書き。フェード（クロスフェード0.8秒・duck 0.2〜0.4秒）の最中に動かすと、フェードの終わりで旧音量に戻る。
- 既出：docs/sound_state_audit_1115_v0.md L50（低と記載・未修正）。候補ブランチ名では該当なし。
- 直し方：`refreshBGMVolume` で `cancelFade(p)` を呼んでから代入（1行）。

### #6 保存値の範囲外・型の想定外に弱い／文字サイズが起動時で固定（低・確信 中・既出なし）
- 音量：SoundManager.swift:100,103 は `object(forKey:) as? Double` をそのまま Float 化（0〜1 に丸めない）。UI のスライダーでは 0〜1 以外は作れないので、壊れたバックアップ・手編集の時だけ（音量が1を超える/負/NaN）。直し：`min(max(v, 0), 1)`（NaN は既定値）を両ゲッターに。
- 演出の速さ：MZSpeed.swift:8 は `==1` だけ速い＝2以上は「ふつう」扱いで安全。Picker は tag 0/1 だけなので、範囲外の値だと選択なし表示になる程度（実害なし）。
- 文字サイズ：YoseTokens.swift の役割トークン（`static let bannerTitle = gothic(26)` ほか約11個）は `Font.mzScaled`（`UIFontMetrics` 参照）を**最初に使われた時の1回だけ**評価する。アプリ起動後に端末の文字サイズを変えても、再起動まで反映されない（動的に拡大する View は反映される）。直し：`static var`（計算プロパティ）にする。上限1.35倍（Theme.swift:259）はアクセシビリティ最大サイズでも1.35倍止まり＝設計の判断で、大きい文字の崩れは AUTOPILOT 137（accessibility-large でオファー札が舞台を覆う・中）に既出。

## 2. 問題なしと確かめた主な所

- **音の入口は一本**：AVAudioPlayer は SoundManager.swift だけ（grep で他に無し）。`AudioServicesPlaySystemSound`・`AVAudioEngine`・`sensoryFeedback` も無し。全 SE が `vol_se` を毎回読む。ボタンの押下音も `Sound.play` 経由（Theme.swift:297）で音量・0オフに従う。
- **SE を 0 にした時**：`vol <= 0.01` で早期 return（SoundManager.swift:109）＝鳴らない。スライダーを動かした試し鳴らしも同じ口。
- **BGM 音量の即時反映**：SettingsView.swift:36 `onChange(of: bgm)` → `Sound.shared.refreshBGMVolume()`。duck 中は `duckFactor` を掛けるので絞りも壊れない。同曲の再指定（playBGM L132）・電話後の再開（L90）も `bgmVolume×duckFactor` を読み直す。
- **サイレントスイッチ**：`.ambient`（SoundManager.swift:67）でマナーに従う。割り込み後の BGM 再開は shouldResume のみ。
- **reduceMotion**：永遠に繰り返す動き（`repeatForever` 7か所：FinalsBroadcastIntro 67/465・WeekMainView 1736・StageFrame 388・StageScene 232・TalkParts 45・YoseComponents 334）は全部 `Theme.Motion.r` または `guard !reduceMotion`。紙吹雪・火花の Canvas（Juice 36/125・YoseEffects 77/253/294/353・YoseRankUpOverlay・YoseChampionCelebration・YoseMilestoneFX・YoseYearTurnCurtain）は全て reduceMotion で止め絵に切り替え（`snapToFinal`／即スキップ）。判子（YoseMotion:8・YoseEffects:485）・数値バウンス（YoseMotion:23,56）・金額フロート（YoseGameParts:106）・ボタン押下（Theme.swift:290・沈みを止めて色で代替）も対応。`withAnimation` 199件中、`Motion.r`／reduceMotion を通らないのは約25件で、#1 の4か所以外は短いフェード・色だけ・reduceMotion 分岐の内側（FinalsPresentationView:280 は `!reduceMotion` の中）。
- **MZSpeed の「縮めない」コメント付き**：WeekMainView:320（退場の長さ不変）・:344（読む時間）・:1314（待ちの上限）・:1536（読む時間）・YoseChampionCelebrationView:795/900/1008・FinalsPresentationView:1454/1489（実時間と描画が同期）は意図どおり。MZSpeed.sleep の38か所は決勝・結果・週の演出で一貫。DEBUG の `MZ_*` フック内の素の sleep（RootView・SettingsView・AbilityUpView・NetaSelectionView）は製品に影響しない。
- **読み込み**：`vol_*` の既定値は SettingsView と SoundEngine で0.6/0.8に一致（コメントどおり）。MZSpeed はアクセスのたびに UserDefaults を読むので途中変更にも追従（進行中の sleep は開始時の値のまま＝許容）。
- **候補ブランチ**：`git branch -r | grep cand` に本論点専用の候補は無し。近いのは `button-press-se-cand`（C-14・ボタン音＋振動・実機で聞いてから）と `yose-sound-wire-cand`（YoseFX.sound の口が未接続＝AUTOPILOT 158・設定の問題ではなく音の配線）と `tv-fatigue-display-candidate`（大きい文字で帯が狭まる・AUTOPILOT 137）。decision_brief は B-13（final-silence）と C-14 のみ該当。
