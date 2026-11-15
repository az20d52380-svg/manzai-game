# 音の状態が戻らない不具合の監査（2026-11-15・読むだけ・v0）

対象：ManzaiGame/Sources 全体（Sound.* の呼び出しは SoundManager 以外で 8 ファイル・約 15 箇所）。確認は読解のみ（実機・sim なし）。

## 先に押さえた SoundManager の仕組み（SoundManager.swift）
- duck は「数」を数えない。`duckFactor` を上書きするだけ（L153-157）。二重に絞っても、最後の duck(1) 一発で戻る＝「二重に絞ると戻らない」は起きない。逆に、片方の restore が別の絞りを早く解く方向のずれはあり得る。
- `duckFactor` は bgm の切替（playBGM）で保たれ、リセットされるのは stopBGM だけ（L163）。つまり絞ったまま画面が消えると、次の曲（.daily など）も小さい音量で始まる（`bgmVolume * duckFactor`・L137/150）。duck を呼んだ側が必ず戻す責務がある。
- 同じ曲の bgm 再指定は、音量を設定どおり×duckFactor に直し、止まっていたら鳴らし直すだけ（L136-138）。曲は変わらない。
- BGM だけが numberOfLoops=-1 のループ音。SE にループは無く、stop 手段も無い（全部 AVAudioPlayer のプール・L108-131）。

## §1 指摘

### 1. 抜けの本命：番組導入 FinalsBroadcastIntro は絞りを finish() でしか戻さない（重さ：低〜中／確信：中）
- 場所：FinalsBroadcastIntro.swift L340（`.vtr` 開始で duck(0.3)）／戻しは L409（finish 内）だけ。`.task(id: stage)`（L58）は場面が変わるたび取り消されるが、取り消し時の復帰は無い。onDisappear も無い。
- 手順：決勝の夜、導入の最中に画面ごと消える経路があると（導入が finish を通らず親が外れる：例 FinalsPresentationView の分岐が別の枝へ切り替わる・デバッグ MZ_UI 直行など。通常のタップ／スキップは finish を通るので安全）、duckFactor=0.3 が残る。
- 起きること：次に鳴る曲（.tension／.daily）が 3 割の音量で始まり、stopBGM（returnToTitle）まで小さいまま。
- 最小の直し：FinalsBroadcastIntro の body に `.onDisappear { if !done { Sound.duck(1, over: 0.2) } }` を足す（StageCeremony.abandon と同型）。
- 補足（設計の確認事項）：絞りは vtr の頭で 1 回かけて、導入の全場面（タイトル・審査員紹介・進出者）が終わる finish まで 0.3 のまま続く。「地鳴りの 0.2 秒だけ絞る」意図なら、title 場面の頭で duck(1) を入れる方が意図に合う可能性がある（オーナー判断）。

### 2. 「この年をやめてタイトルへ」で BGM が止まらない（重さ：低／確信：高）
- 場所：RootView.swift L343-348（onChange(of: session.abandoned)）。同じタイトル戻しの returnToTitle（L357-358）は `Sound.stopBGM()` を呼ぶが、こちらは呼ばない。
- 手順：育成画面 → 設定 → 解散（DisbandFarewellView → session.abandonRun）。
- 起きること：.daily が鳴ったままタイトル・導入へ。タイトルは無音という作りなら不揃い。
- 最小の直し：L346 の `if quit {` の中の先頭に `Sound.stopBGM()`。

### 3. SE の「全SE断」は鳴り中の長い SE を止めない（重さ：低／確信：高）
- 場所：FinalsPresentationView.swift L361 / L378（hushSE(true)＋duck(0.25)）。`hushSE` は新しい SE を捨てるだけ（SoundManager L55・L109）。
- 長い SE：se_applause_hall 10.1s・se_cheer_big 10.2s・se_cheer_mid 9.4s・se_applause_small 10.6s（Resources/Audio 実測）。stop する手段が無い。
- 手順：7 人目の審査員の前（開示で 6 人目まで拍手・歓声を鳴らした直後に長押し早送りした場合は fastForwardBeat L506 が tada＋applauseHall を鳴らす）→ タップで「伝説の間」。
- 起きること：拍手が鳴ったまま「無音の溜め」に入る。決勝の溜めが濁る（戻らないのではなく、止まらない）。
- 最小の直し：Sound に `stopAllSE()`（sePlayers の全 player.stop()）を足し、hushSE(true) の所で呼ぶ。または hushSE(true) 内で鳴り中を stop。

### 4. エンディング・年末結果の BGM は前の画面の曲のまま（重さ：低／確信：中・仕様かもしれない）
- 場所：EndingViews／YearResultView に Sound.bgm 呼び出しが無い。
- 起きること：決勝後は .finals／.tension が年末結果・エンディングの間ずっと鳴り、タイトル戻りで stopBGM。次年へ進む時は WeekMainView.onAppear が .daily に戻す（問題なし）。ただ、エンディング（8 種）に専用曲は無く、前の曲の続き。
- 直し：作品判断。直すなら EndingFlowView の onAppear で stopBGM か .daily。

## §2 問題なしと確かめた主な所
- StageFrame.swift StageCeremony（L272-324）：絞り→待ち→取り消し判定→finish／abandon で、全経路（タップ・途中取り消し・最後の取り消し）で duck(1) に戻る。tap 後に run が起きても `done` で抜ける。早送り（MZSpeed）は待ちが縮むだけ。設置は TournamentResultView L264 と FinalsPresentationView L210 の 2 箇所とも同じ作りで OK。TournamentResult 側は abandon で onDone を呼ばない＝beginReveal（tension）も走らない（画面が消えているので正しい）。
- FinalsPresentationView L361-364／L378-383：hushSE(true)+duck(0.25) の後の復帰は、非構造化 `Task {}` なので画面が消えても取り消されず必ず走り、hushSE(false)+duck(1) が揃う。`holdingSeventh` が advance／fastForwardBeat の両方で二重起動を防ぐ。MZSpeed の「はやい」でも待ちが短くなるだけで復帰は走る。
- 決着後の残り札の voteTailTask（L409）：onDisappear で取り消し＝閉じた後に音が鳴らない。hush・duck は絡まない。
- BGM の戻り：育成の BGM は WeekMainView.onAppear（L333）の `Sound.bgm(.daily)`。RootView.content は if/switch で画面が差し替わる作り（覆い fullScreenCover ではない）ので、大会結果・決勝・年末結果から戻ると WeekMainView が新しく作られ onAppear が走る。WeekMainView の上にかぶる fullScreenCover（手帳・カレンダー・ショップ・イベント）は BGM を変えない。したがって「覆いで戻って onAppear が走らない」型は無い。
- 同じ曲の再指定（.tension を FinalistAnnounceView と beginReveal で 2 回、.finals）は SoundEngine L136 で音量追従のみ（曲の頭に戻らない）。
- 閉じた後も前の画面の曲が鳴る件：returnToTitle（L357）は stopBGM し duckFactor も 1 に戻す（SoundManager L163）。FinalistAnnounceView／TournamentResultView は onDisappear でタスクを取り消し（ループ・待ちが残らない）。
- 電話等の割り込み：resumeBGMAfterInterruption（SoundManager L90-）が曲・duck を保ったまま鳴らし直す。
- ループ音は BGM のみ（numberOfLoops=-1）。BGM は playBGM 切替時に旧 player を fadeOut→stop、stopBGM でも fadeOut→stop。タイマーは player ごとに取り消し可能（cancelFade）で、新しいフェードが旧フェードを奪う作り。stop 忘れは無い。

## 補足（SoundManager の作りの小さな癖・直さなくてよい）
- playBGM の読み込み失敗時、`currentBGM=track` のまま `bgmPlayer=nil`（L140・L144）。以後同じ曲の再指定は鳴らし直さない（リソース欠落時のみ。低）。
- refreshBGMVolume（L167）は進行中のフェードを取り消さず音量を直書き。設定スライダーを動かした直後にフェードが上書きする場合がある（低）。
