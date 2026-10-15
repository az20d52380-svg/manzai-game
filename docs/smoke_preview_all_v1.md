# preview-all 通しスモーク v1（2026-10-15・ブランチ preview-all）

## 結論
落ちる・進めない不具合は **見つからず**（コード変更なし）。重い順の不具合リストは空。

## 1. swift test
`swift test --package-path GameCore`：126 件・失敗 0（green）。

## 2. 自動通し（iPhone 17 / E5D11233）
フック：`MZ_SMOKE=3`（年末まで自動）＋`MZ_YEARS=n`（n 年ぶん先に自動で進める）。env は `SIMCTL_CHILD_` 接頭辞で渡す。
- 1年（YEARS=0）・3年（YEARS=2）・10年（YEARS=9）とも年末の観戦決勝（「次の細を見る」）まで到達、プロセス生存。
- クラッシュレポートなし。`log show` の error/fault は OS 由来のみ（CFBundle plugin factory・CoreAudio LoudnessManager・xpc）＝シミュレータ環境のノイズ。アプリ固有の警告なし。
- ビルド警告（既存・動作に影響なし）：AbilityUpView.swift:72/152/198、NotebookView.swift:115、YearResultView.swift:96（Text 補間で LocalizedStringKey 非対応型）、WeekMainView.swift:197（burstGen/beatAdvice を nonisolated から参照・Swift6 で要注意）。
- 撮影：feedback_shots/smoke_v1/y0/y2/y9.png（未コミット）。

## 3. 手で触る所（simctl 経由の control タップ。idb/axe は無し）
押せて、正しい画面へ行った：
- 週メイン：ネタを書く（家で書く→週送り・完成度30）／能力アップ（＋−で未確定表示・確定で戻る）／お店（購入で¥・体力・残回数が更新、戻す出現）／休む（サブ一覧→家で寝る→週送り）／日程／コンビ／設定。練習は体力0で「休演」表示のとおりグレー（仕様どおり）。
- ネタ帳（コンビ→持ちネタ）：型を変える（色パレット展開）／しまう→「しまったネタ」／出す→復帰。
- 設定：最初からやり直す→確認ダイアログ→もどる で閉じる（やり直すは未押下）。
- 大会（MZ_UI=netaentry）：エントリー画面→新幹線で出場→本番（スキップ）→結果（敗退）→次へ進む→イベント（谷口の会話→選択肢 A 押下→「相性↑」→閉じる）→第13週のメインへ復帰。
- 撮影：feedback_shots/smoke_v1/ a*,b*,c*,d*,e*,f*,g*,h*.png。

未確認（時間の都合・不具合の兆候なし）：イベント選択肢 B、バイト、練習（体力ありの時）、設定のやり直す実行、「ネタを書く」で新規題名入力＋候補ボタン、通過側の結果・優勝演出。

## 気づき（不具合ではない）
- 大会エントリー画面（f1）は舞台看板がステータスバー直下に食い込む。意図した全面表示なら問題なし（要目視判断）。
- 能力アップ画面の＋は、行ごとに最大値まで押せるかの上限挙動は未確認。
