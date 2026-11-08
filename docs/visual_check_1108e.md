# 目視点検 1108e（11/08 の表示の直しの確認）

iPhone 17（E5D11233）・simctl の起動と撮影だけ（タップなし）・女コンビ MZ_KIND=femaleFemale。スクショは /private/tmp/claude-501/-Users-hujiko/37ff8b23-7a0b-4215-b211-13a066de339e/scratchpad/ の v1108e_*.png（縮小600px・コミットしない）。
目視用に DEBUG の小さなフックを1つ足した：`MZ_UI=hana_entry MZ_HANAIDX=0..3`（THE HANA の何回戦の入口を開くか。既定0）。

## 結果（崩れなし）
1. 賞金の無い大会の入口に「0万」が出ない（10eb222d）：HANA1回戦＝v1108e_hana_entry0.png／HANA2回戦＝v1108e_hana_entry1.png／HANA準決勝＝v1108e_hana_entry2.png。3枚とも「ライン／賞金」の札が出ず、入口が崩れていない（私/谷口の札・衣装も正常）。
2. 日程表の凡例と過ぎた週：v1108e_calendar_ff.png（12週）・v1108e_cal_late.png（44週・MZ_CARE=1）。凡例に「出られなかった大会の週は塗りません」が出る。過ぎた大会週は薄い赤＋文字（大会名）で表示され、HANA1 だけ塗られ HANA2 以降は未到来で空。崩れなし。
3. 決勝の導入：MZ_UI=finals で「今夜、ひと組だけ、日本一。」の幕→出順くじ（5番目）まで自動で進み、そこでタップ待ち。1場面飛ぶ・止まる症状なし（v1108e_finals0/1/2.png）。導入の各場面の中身（審査員・進出者の紹介）は撮影間隔上すべては見ていない。

## 目視できなかった物
- 無名のうちの「常連」「毎回」のファン報告（b8a630a8）：画面に出す専用フックが無い（文面は FanReportData の knownOnly 集合で除外される＝テストの範囲）。
- 推薦制の大会を出た週だけ塗る（218cd202）：目視用台本では推薦制の大会に出られず、出た週／出なかった週の両方は再現できていない（コードの条件のみ）。
- 大きい文字（content_size=extra-extra-large／accessibility-extra-large）：設定は入ったが、日程表・入口の画面は大きさが変わらず（固定サイズの文字）、確認にならなかった。content_size は large に戻した。
