# 12pt 直し後の回帰目視（v0）

iPhone 17・縮小1枚ずつ。見た点＝はみ出し・…切れ・重なり・枠はみ出し・ステータスバー重なり。直した物は無し。

| 画面 | フック | 結果 | 所見 | コミット |
|---|---|---|---|---|
| 用語集 | MZ_UI=glossary | ○ | 崩れなし | - |
| 通知許可 | MZ_UI=notif | ○ | 崩れなし | - |
| 予選通知（ロック画面） | MZ_UI=qual_line | ○ | 崩れなし | - |
| 決勝進出発表 | MZ_UI=finalist_announce | ○ | 演出の途中（暗転）で撮影・崩れなし | - |
| タイトル | MZ_UI=intro_title | ○ | 崩れなし | - |
| コンビ結成 | MZ_UI=intro_name | ○ | 崩れなし | - |
| 舞台の枠 | MZ_UI=frame | ○ | 崩れなし | - |
| 週の画面 | MZ_UI=stage / stamina / forecast / partner | ○ | 4つとも同じ週の画面（状態違いは差が見えない）・崩れなし | - |
| 体調ダウン | MZ_UI=injury | ○ | 崩れなし | - |
| 年替わり | MZ_FX=yearturn | ○ | 崩れなし（「1」が筆文字で「一」に見えるのは既存の字体） | - |
| 演出 | MZ_FX=cutin / streak / burst | ○ | 単独再生は背景のみ・字は崩れなし | - |
| 選択イベント | MZ_UI=event MZ_EV=0014 / 0023 / 0041 | ○ | 駅・休憩室・楽屋とも崩れなし | - |

結論：崩れ0件。

## 親の追記（10/20）
- stamina/forecast/partner/living/injury は `MZ_UI=<名前>` ではなく **`MZ_UI=weekhint MZ_WH=<名前>`** のフック（MZ_UI=stamina 等は存在しない case＝ふつうの第1週が出る）。正しいフックで stamina（第5週・体力0・休演の判）と partner（第7週）を目視＝崩れなし。DEBUG の「優勝／無双」の札が実力の札に少し重なるのは DEBUG 版だけ。
