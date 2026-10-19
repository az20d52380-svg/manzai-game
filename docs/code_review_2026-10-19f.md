# コード点検 2026-10-19f（通知・ネタ帳の操作・NetaSelectionView・StageFrame・Sound/Haptics・UserDefaults 利用・scenePhase の通読・5回目）

**件数：7件（確度 高 3／中 4）。** 読み取りだけ・コードは変えていない。既出（19〜19e）は除いた。

## §1 確度 高

1. **設定の BGM 既定値と実際の音量が食い違う**（SettingsView.swift:13 と SoundManager.swift:79）
   - 手順：新規インストール → 設定を開く。BGM スライダーは 0.7 の位置に出るが、`@AppStorage` の既定値は書き込まれず、SoundEngine は `vol_bgm` 未保存なら 0.6 で鳴らす。スライダーに触るまで見た目より小さい音。
   - 直し案：既定値を1か所の定数（0.6 か 0.7）にして両方で使う。
2. **決勝の1本目と2本目に同じネタを選べて、「2本目が無い」減点を避けられる**（NetaSelectionView.swift:28-31 の `activeNetas` 全件表示／StageViews.swift:309-314／GameEngine.swift:271）
   - 手順：決勝入口で1本目・2本目に同じ高完成度ネタを選ぶ。エンジンは2本目の完成度しか見ない（`second.polish < netaSecondMinPolish` だけ）ので `netaSecondPenalty` を毎回免れる。
   - 直し案：2本目の候補から1本目の id を除く（選択時に同じ id なら相手側を nil にする）。
3. **ネタをしまっても `selectedNetaID2` が残り、戻すと黙って2本目に復活する／年をまたいでも消えない**（WeekRunner.swift:499-503 `applyNetaRetire` は `selectedNetaID` しか消さない。`selectedNetaID2` を nil にする所は全体に無い）
   - 手順：決勝で2本目に A を選ぶ → 翌年、ネタ帳で A を「しまう」→「出す」。2本目は選んでいないのに A が選択済みで出る（前年の選択が残る）。しまっている間は id が宙に浮いてセーブにも残る。
   - 直し案：`applyNetaRetire` で `selectedNetaID2 == id` なら nil に。年の切り替えでも ID2 を nil にする（UI 層で `selectNeta2(nil)`）。

## §2 確度 中

4. **BGM が通話・Siri・アラームの割り込みのあと戻らない**（SoundManager.swift:105-108 `playBGM` の同曲分岐／割り込み通知の購読なし）
   - 手順：育成画面で BGM 再生中に電話が来て切れる → AVAudioPlayer は割り込みで停止したまま。`WeekMainView.onAppear` の `Sound.bgm(.daily)` は同曲なので音量を直すだけで再生し直さず、別の曲に変わるまで無音。
   - 直し案：同曲分岐で `if !p.isPlaying { p.play() }`（`currentTime` はそのまま）。
5. **フェードが Timer の既定モードで、スクロール中は止まる**（SoundManager.swift:147 `Timer.scheduledTimer`）
   - 手順：結果画面などでスクロールを指で押さえたまま画面遷移の BGM 切替が起きる → 新曲は音量0のまま、旧曲は音量が下がらず鳴り続け、離すまで二重／無音になる。
   - 直し案：`RunLoop.main.add(timer, forMode: .common)`。
6. **`stopBGM` の呼び出し元が無く、エンディングやタイトルに戻っても決勝・緊張の BGM が鳴り続ける**（SoundManager.swift:117 定義のみ。`returnToTitle` RootView.swift:313 は止めない）
   - 手順：優勝 → エンディング → タイトルへ。finals BGM がタイトル・導入の間ずっと続き、次に育成画面に入るまで切れない（初回起動時は無音なので一貫しない）。
   - 直し案：`returnToTitle()` と `abandoned` の onChange で `Sound.stopBGM()`。
7. **「新しく書く」「別のネタに替える」で手で選んだ勝負ネタが黙って外れる**（WeekMainView.swift:728, 745, 796。`selectNeta` が「書く対象」と「本番にかける勝負ネタ」を兼ねている）
   - 手順：ネタ帳で A を「勝負ネタにする」→ 週の行動でネタ作りを選び「新しく書く」（`selectNeta(nil)`）。A の「真剣勝負」印が消え、書いたネタ（または `ensureStageNetaDefault` の最高完成度）に置き換わる。大会入口で気づかないと別のネタで出る。
   - 直し案：書く対象を別の `@State` で持ち、`selectedNetaID` は大会用の選択にだけ使う（最低でも書く前の選択を覚えて戻す）。

## §3 見たが問題なかった所
- **通知**：`UNUserNotificationCenter` は IntroFlow.swift:710 の許可要求だけ。通知の登録・取り消しは本体に一つも無く、`NotificationPromptView` は導線から外してある（IntroFlow.swift:773）ので、重複して積もる・取り消し漏れ・許可なしの扱いは起きない。実装する時に再点検（「大会の開演前にお知らせ」の文言は今のところ空約束だが画面に出ない）。
- **scenePhase**：RootView.swift:302 の `.background` で `saveNow`。`started` のときだけ。エンディング後はセーブ削除側に倒れる。問題なし。
- **ネタの id**：改名・型替え・しまう・出すは id 検索（`firstIndex(where:)`）で添字渡しではないので別のネタを消す／選ぶことはない。`recallNeta` の満杯判定（`state.netas.count`）と UI の `slotsFull` も同じ値。
- **NetaPickRow／netaCard**：`ForEach` は `Identifiable`（id）で、選択中判定も id 比較。範囲外・強制アンラップなし（`cur!` は `cur == nil ||` の後ろで安全）。
- **EndingBook.record**：`recorded` の `@State` で onAppear の二重記録を防いでいる。デコード失敗は空辞書に倒れ、クラッシュしない。
- **DEBUG の漏れ**：`debugSelfTest`・`MZ_*` 参照・`StageFramePreview`・`debugButton` はすべて `#if DEBUG` の中。本編側に露出なし。
- **StageCeremony／FinalsBroadcastIntro／FinalsPresentationView の duck/hushSE**：非構造化 Task は必ず `hushSE(false)`・`duck(1)` まで走り、`finish()` も復帰する。画面が途中で消えると duck が残る経路は理屈上あるが、現状の呼び出し順では確認できず（未報告）。
- **SE プール**：空き面の再利用と最大3面。音量0で早期 return。問題なし。
- **FinalsSeen.first／OneTimeHint**：副作用つきだが `body` の外（onAppear／関数内）でしか呼ばれていない。

## 直した所（10/19 自走・ビルド OK）
- §1〜§6 を直した。§2・§3 はアプリ側（GameSession の選択と NetaPickRow の候補）で整えた＝GameCore・golden は不変。
- 未対応：§7「新しく書く」で勝負ネタが外れる（書く対象と大会のネタを分けるかは作りの判断）→ AUTOPILOT キュー114。年の切り替えで2本目を消すかも同じ判断に含める。
