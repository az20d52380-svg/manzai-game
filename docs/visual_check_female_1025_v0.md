# 目視 10/25 女性コンビ・男女コンビ（コードは未修正）

スクショ保存先: /private/tmp/claude-501/-Users-hujiko/fa5733ab-e087-4078-9188-e834d1c76f00/scratchpad/fk_<名前>.png（12枚・iPhone 17・幅600に縮小）。ff=femaleFemale / fm=femaleMale。

## 画面ごと
| 画面 | フック | 所見 | 崩れ |
|---|---|---|---|
| 週（ff） | MZ_UI=week | 札「私」・相方「谷口」・おだんご／長髪の人形ともに描画正常。相方の台詞「来月まで本番なしだって。長いね」自然 | 無し |
| 選択イベント weekend（ff） | MZ_UI=event MZ_EV=weekend | 谷口「私は行ってもいいと思ってる。そっちはどうする」。語尾・一人称とも自然 | 無し |
| イベント partner（ff） | MZ_UI=event MZ_EV=partner | 主人公札「私」。台詞「今月は家賃を払ったら、ほとんど残らないよ」自然 | 無し |
| ネタ帳→大会入口（ff） | MZ_UI=netaentry | 札「私」、人形（長髪・おだんご）はみ出し・重なり無し | 無し |
| 決勝（ff） | MZ_UI=finals | 審査員席の顔（女性審査員含む）正常。主人公側の記号・俺の残り無し | 無し |
| エンディング1（ff） | MZ_UI=ending MZ_ENDING=1 | 札「私」。ログ「私『払えるあてがない…』」。{me}の記号は解決済み | 無し |
| 導入の回想（ff） | MZ_UI=intro MZ_MEET=1 | 札「私」、台詞「ありがとう。隣のクラスの？」自然 | 無し |
| 解散（ff） | MZ_UI=disband | 「私『話がある。コンビは今日で終わりにしよう』」「そっちもね」。「だろ／だな／ぞ」無し | 無し |
| 本番 winner（ff） | MZ_UI=frame MZ_MODE=winner | 私＝紫・谷口＝ピンクの着物。おだんごの髪が欠けず、紙吹雪との重なりも問題なし | 無し |
| weekend（fm・自分が女／相方が男） | MZ_UI=event MZ_EV=weekend | 谷口「俺は行ってもいいと思ってる」＝男相方の一人称は「俺」で正しい | 無し |
| 導入の回想（fm） | MZ_UI=intro MZ_MEET=1 | 札「私」。ff と同じ | 無し |
| 決勝（fm） | MZ_UI=finals | ff と同じ（審査員席） | 無し |

勝敗の loser は frame の MZ_MODE=loser で未撮影（撮影枠の都合）。

## grep の結果（ManzaiGame/Sources・主人公「俺」・相方「谷口」の台詞のみ）
- 「俺」「お前」の主人公・相方台詞への残り: 0 件（残りは第三者の堀口 ChoiceEventData.swift:617,629・野々村:1028・先輩:305 の台詞のみ＝対象外）
- 記号 {me}／{partner1}: 画面では全て解決（Names.show で置換）。ソース上の使用は {me}27・{partner1}23 のみで未解決の別記号は無し
- 語尾「だろ／だな／ぞ／だぜ」: 0 件（「ぞ」は「のぞいて」DialogueData.swift:438・「どうぞ」MeetingKind.swift:57,91 の誤検出）
- 参考（問題ではない）: 「ねえ」ChoiceEventData.swift:564（谷口、女性にも自然）・「だよ」Endings.swift:114,130,153（中性）

## 注意
- 話者名の札は内部名「俺」のまま持ち、表示時に Names.show で「私」に置換する作り。画面上は全て「私」。
- 回想・解散の人形は札型で髪の描画は無し（崩れの対象外）。
