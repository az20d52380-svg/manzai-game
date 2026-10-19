# 決勝演出まわりの画面 目視監査（2026-10-19・iPhone 17・コード変更なし）

注意：judging/winner/loser/spectator/preshow は単独の MZ_UI ではなく `MZ_UI=frame MZ_MODE=<名>`。stage=`MZ_UI=stage`、stamina/living/forecast/partner=`MZ_UI=weekhint MZ_WH=<名>`、weekend=`MZ_UI=event MZ_EV=weekend`。
見た数15（演出画面は2枚）。所見 高0／中1／低4。

| フック | 結果 |
|---|---|
| preshow | 崩れなし（出番札が演者の下半身にかかるのは意図通り） |
| judging | 崩れなし（セリフ帯が左右の幕枠まで全幅で伸びるが読みやすい） |
| winner | 崩れなし（紙吹雪・「予選通過！！」札とも収まる） |
| loser | 崩れなし |
| spectator | 崩れなし（看板「タイフーン」縦書きも収まる） |
| stage | 所見L3：週メインが出るだけで「舞台」画面ではない（フックの用途確認） |
| frame | 上記 preshow〜spectator のモードで確認済（MZ_MODE 既定 lit は未撮） |
| weekend | 所見L2 |
| forecast | 所見L4 |
| partner | 週メイン共通の所見M1のみ |
| injury | 崩れなし（体調ダウン ダイアログ4行で収まる） |
| stamina | 週メイン共通の所見M1のみ |
| living | 週メイン共通の所見M1のみ（吹き出し「時間あるうちに…」は収まる） |
| notif | 所見L1 |
| catalog | 崩れなし（先頭画面のみ） |

## 所見
- **M1（中）週メインの「実力／相性」カードが右側の相方（谷口）の頭に重なる**（stamina/living/forecast/partner/stage 全部で共通）。人物の頭が隠れ、相性メーターが相方に被って見える。直し案：カードを右上に寄せて小さくする／人物を左へ少し寄せる。ファイル：ManzaiGame/Sources/WeekMainView.swift（実力カード）。画像 docs/finals_screens_audit_1019_stamina.png
- **L1（低）notif：本文カードの右端が画面の端で切れている**（左は余白ありで非対称）。直し案：右側にも同じ水平余白。ファイル：NotificationPromptView（ManzaiGame/Sources 内）。画像 docs/finals_screens_audit_1019_notif.png
- **L2（低）weekend（先輩から誘い）：セリフ枠とボタンの間が大きく空く**（本文1行のため）。直し案：本文を中央寄せにするかボタンを枠直下へ。ファイル：EventView 系。画像なし（致命的でない）。
- **L3（低）stage フックは週メインしか出ない**（`ui=="stage"` は初期化専用で、舞台の演出は出ない）。決勝の舞台そのものの目視は `frame` モードで代替。
- **L4（低）forecast：月末の支払いポップアップに閉じるボタンが見えない**（撮影時点＝起動3秒後。自動で閉じる前提ならOK、未確認）。直し案：ボタンの有無を確認。画像 docs/finals_screens_audit_1019_forecast.png
