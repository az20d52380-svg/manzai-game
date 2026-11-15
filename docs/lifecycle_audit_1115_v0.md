# アプリの寿命（バックグラウンド・強制終了・復帰）点検 v0（11/15・読むだけ）

対象：ManzaiGame/Sources。コード・シミュレータは触っていない。実機・タップでの確認はしていない（読みだけ）。
結論：育成の主な操作は確定点ごとに saveNow が走っていて、「落とすと消える」実害のある穴は見つからなかった。指摘は低め3件・仕様確認1件。

## §1 指摘

### 1. 通知は「許可を聞くだけ」で予約も取り消しも無い（重さ：低／確信度：高）
- 場所：IntroFlow.swift:754-758（allow() が requestAuthorization だけ呼ぶ）。Sources 全体に UNUserNotificationCenter はここ1か所だけ（add／remove／getNotificationSettings 無し）。
- 手順：導入の最後で「許可」を押す→OSの許可ダイアログ→何も予約されない。拒否した人にも設定画面への案内は無い。
- 壊れる物：許可を取るのに送る通知が無い（審査・プライバシー説明とのずれ）。予約が無いので「取り消し漏れ」は起きない。
- 最小の直し：通知機能を入れない決定なら、許可画面（Stage.notif）ごと外す。入れるなら予約と取り消しの設計が別途必要。
- 既出：判断待ち（docs/decision_brief_2026-11-08.md:43「通知機能を入れるか」）。候補ブランチ無し。

### 2. 復帰（.active）で BGM を鳴らし直す処理が無い（重さ：低〜中／確信度：中・実機で要確認）
- 場所：RootView.swift:351-354（scenePhase は .background の保存だけ）、SoundManager.swift:75-95（鳴らし直しは AVAudioSession の割り込み終了通知＋shouldResume の時だけ）、SoundManager.swift:136-139（同じ曲を再度頼まれた時だけ !isPlaying を鳴らし直す）。
- 手順：決勝・結果画面の BGM 中にホームへ→戻る。OS が再生を止めていて割り込み終了通知が来ない場合（例：背景の音声モード無し・他アプリが音を取った後）、次に別画面が Sound.bgm を呼ぶまで無音。
- 壊れる物：BGM が戻らない（演出の途中では特に目立つ）。Timer ベースのフェード（SoundManager.swift:182）も背景中は進まないため、フェードアウト途中で戻ると中途半端な音量のまま。
- 最小の直し：RootView の onChange(of: scenePhase) に .active を足し、SoundManager に「currentBGM が有り !isPlaying なら音量を戻して play」を呼ぶ小関数を1つ。
- 既出：AUTOPILOT.md 149（電話・アラーム割り込み後の BGM、実機確認待ち）と同じ系統。.active 経路は項目に明記なし＝149 に追記する程度。候補ブランチ無し。

### 3. 保存のきっかけが .background だけで .inactive は拾わない（重さ：低／確信度：中）
- 場所：RootView.swift:353。
- 手順：アプリスイッチャーを開く（.inactive）→そのまま上へ払って強制終了。通常は .inactive→.background を経るので保存されるが、電話着信中・Face ID 等の .inactive のまま終了する経路では、直前の確定点以後の状態は失われる。
- 壊れる物：ただし saveNow は各確定点（choose／decideTournament／allocate／applyEventChoice／買い物／ネタ操作）で既に走るため、失われうるのは「確定点の間」の表示専用の状態だけ。実害は小さい。
- 最小の直し：`phase == .background` を `phase != .active` にする（saveNow は冪等）。
- 既出：無し（候補 career-end-save-candidate・save-safety-1110-bundle-cand はセーブの別論点）。

### 4. 日時依存の2か所（重さ：低／確信度：高・仕様確認）
- 衣装ガチャのログイン札：GachaState.swift:154-159。dayKey は端末の現在のカレンダー・タイムゾーンで決まり、「today > lastLoginDay」の文字列比較。端末の時計を未来にして受け取ると、戻した後は未来の日付が上回り続けて札がもらえなくなる（戻した時は拒否する作りなので意図どおりだが、未来に進めた人が詰まる）。バックグラウンド中に日付をまたいでも壊れはしない（開き直しで claimLogin が呼ばれる想定）。
- 通知許諾の再表示：IntroFlow.swift:749-754,762。7日後の再表示を Date().timeIntervalSince1970 で見る。時計を戻すと再表示が遅れるだけで害は小さい。
- 最小の直し：不要なら据え置き。直すなら lastLoginDay が今日より2日以上先なら無効として今日で上書き。
- 既出：無し。

### 5. chooseOffer は保存しない（重さ：低／確信度：中）
- 場所：GameSession.swift:456（runner.chooseOffer のみ。saveNow 無し）。
- 手順：オファーの札を選ぶ→（受ける前に）落とす→復帰で札の選び直し。直後の choose が保存するので、押し直せば同じ。失われる物は「どれを選んでいたか」の選択のみ。
- 最小の直し：不要（選び直しで済む）。気になるなら末尾に saveNow を足す（乱数非消費）。
- 既出：無し。

## §2 問題なしと確かめた主な所
- 保存の確定点：decideTournament(371)・choose(434)・allocate(528)・applyEventChoice(801)・dismissChoiceEvent(808)・ネタ名／選択／呼び戻し／引退(883-969)・buyItem／moveRoom／learnSkill(918-944)・advanceAuto(982)・acknowledgeResult(991)・勝利後の選択(1096, 1170, 1216)・年替わり(1295, 1303)・負債警告／裂け目ヒント(1295付近)。買い物と能力アップ（allocate）は直後に保存される。
- イベントを選んだ直後：applyEventChoice が末尾で保存。閉じる前に落としても pendingChoiceEvent は choiceApplied なら nil で保存＝選択の二重適用は起きない（GameSession.swift:1346）。
- 設定：@AppStorage（vol_bgm・vol_se・速度）は即時に UserDefaults へ。
- ガチャ：GachaStore.mutate が毎回 persist（UserDefaults＋iCloud）。引いた結果は同期保存でアプリを落としても残る。
- 優勝・最終年の区切り：セーブを消す timing は既に候補 career-end-save-candidate／AUTOPILOT 117 で検討済み（本点検では新規指摘なし）。
- 壊れたセーブ：退避キー manzai.save.v1.broken へ移す（loadedOrNew）。既出の候補 broken-save-notice-cand。
- Task.sleep・.task の演出（QualifierNoticeView・StageFrame・FinalsBroadcastIntro・WeekMainView）：背景中は OS が止め、復帰で残りの待ちから続くだけ。二重に進む作りは見当たらない（WeekMainView は .task(id: session.week) と gen カウンタで二重起動を防ぐ）。取り消し後の続きは cancelled_sleep_audit_1115（AUTOPILOT 443）で点検済み。
- 音：AVAudioSession の割り込み終了で鳴らし直す仕組みあり（SoundManager.swift:75-95）。同時 SE は 0.06 秒ガード付き。
- 時刻依存：ゲーム内の日程は週番号で進む（Date を使わない）。Date() の用途は SE 連打ガード・オファーの二度押し防止(0.4秒)・図鑑の初回日時・通知の再表示・ガチャのログイン日のみ＝バックグラウンド中の時間経過でゲームが壊れる所は無い。
- IntroFlow 中（started=false）は保存しない設計（RootView.swift:353 のガードと saveNow の注記どおり）。導入の途中で落とすと名前入力からやり直しだが、セーブが無い状態なので仕様。
