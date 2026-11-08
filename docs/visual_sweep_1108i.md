# 目視点検 1108i（iPhone 17・14画面・直していない）
スクショ: scratchpad/vs_<hook>.png（hook名はMZ_UI。forecast/living/stamina/injury は MZ_UI=weekhint MZ_WH=名、weekend は MZ_UI=event MZ_EV=weekend、preshow/judging/loser/spectator は MZ_UI=frame MZ_MODE=名で撮影＝指定の MZ_UI 直指定では目的の画面にならない）
- glossary: 問題なし（見出し・本文の切れ/重なりなし。下部は縦スクロール分で未確認）
- forecast: 問題なし（「再来週は月末の支払い（家賃など）14万円」の案内は収まっている）
- living: 問題なし（「今週末に生活費14万円。所持金が足りない。」表示OK）
- preshow: 【低】コンビ名の札（そよ風ズ）が二人の下半身に被さる（演出上の意図なら問題なし）。他は崩れなし
- qual_line: 通知の段のみ確認（タップ不可のため一覧は未見）。問題なし
- qual_notice: 通知の段のみ確認（同上）。問題なし
- loser: 問題なし（「予選敗退」札・「惜敗」印とも収まる）
- spectator: 【低】右下の立て札が「タイフーン」だけで、見出しの「浪速タイフーン」と不一致（札が途中で切れている可能性。意図なら問題なし）
- injury: 問題なし（体力40・「谷口：無理すると倒れるよ。」表示OK）
- disband: 問題なし（会話3行・吹き出し収まる）
- stamina: 問題なし（体力0で「ネタを書く」「練習」が灰色＋休演の印・「体力が少ない。今週は休むのも手だ。」OK）
- catalog: 問題なし（上部のみ確認、下部は縦スクロール分で未確認）
- judging: 問題なし（「審査中・・・」と「どっと沸いた！！」の帯が収まる）
- weekend: 【低】本文と選択肢の間に大きな空白（約100pt）。機能上の崩れはなし
開発用文字・英字・誤字の露出: なし

## 親の確認（11/08）
- spectator の「タイフーン」：MZ_UI=frame の目視用の見本（StageFrame.swift:518 の固定文字）＝本番には出ない。本番の観戦（FinalsPresentationView:121）は「客席」の札＝問題なし。
- weekend の空白：選択肢を画面の下に寄せる作り（他のイベントと同じ）＝崩れではない。
- preshow の札の重なり：キュー111・137 と同じ種類（舞台と札の重なり）＝決定待ち。
＝直す所なし。
