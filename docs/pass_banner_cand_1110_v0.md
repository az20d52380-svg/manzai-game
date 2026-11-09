# 通過の上帯を優勝と別の文に（候補・論点の推奨形） v0

- 前：`◆ 漫 才 の 頂 、 こ こ に 決 ま る ◆`（優勝演出と同文）
- 後：`◆ 次 の 舞 台 へ ◆`（字間・飾り・フォントは同じ。実在番組の決まり文句に似ない語）
- 場所：`ManzaiGame/Sources/Design/YoseMilestoneFX.swift` 162行目（合否看板 signboard の上帯・「予 選 通 過」の上）。読み上げ文 accessibilityLabel は当該箇所に無く、揃え不要。
- 触っていない：`YoseChampionCelebrationView.swift` の優勝文、FinalsBroadcastIntro の「〜 漫才の頂、ここに決まる 〜」。
- テスト：GameCore 469 tests 失敗0／アプリ 402 tests TEST SUCCEEDED。
- 撮影：未。MZ_UI=pass は「客席の反応」の最初で止まり、結果発表（看板）までタップが要るため到達できず。
- 判断（オーナー）：文言の採否。他案があれば同じ1行を差し替えるだけ。
