# 今日さわった画面の目視一巡（1027）v0

- 通常サイズの10画面（iPhone 17）は崩れなし。
- 文字サイズ最大（accessibility-XXXL）の2画面に軽い崩れが2件（下記）。通常サイズでは出ない。
- 撮影後に文字サイズは large へ戻し済み。コードは未変更。

| # | 画面とフック | 崩れ | 内容 | 画像 |
|---|---|---|---|---|
| 1 | week STOPWEEK=8 | なし | | feedback_shots/regress_1027/01_stopweek8.png |
| 2 | week WEEK=practice | なし | | 02_practice.png |
| 3 | week WEEK=rest | なし | | 03_rest.png |
| 4 | week WEEK=netawrite | なし | | 04_netawrite.png |
| 5 | week OFFER=1 | なし | | 05_offer.png |
| 6 | settings | なし | | 06_settings.png |
| 7 | yearend YEARS=1 CARE=1 | なし | | 07_yearend.png |
| 8 | intro_name | なし | | 08_intro_name.png |
| 9 | intro_title | なし | | 09_intro_title.png |
| 10 | glossary GLOSS=1 | なし | | 10_glossary.png |
| 2x | practice・文字最大 | あり | 画面下の「日程／コンビ／設定」ボタン列が下端で切れ、体力バーも極小 | 02_practice_xxxl.png |
| 4x | netawrite・文字最大 | あり | 上の舞台イラストが細い帯に潰れ、「候補」ボタンの文字が「…」に省略される | 04_netawrite_xxxl.png |

## 親の対応（10/27 定期）
- 練習（AX最大）の下の列の押し出し：原因は同じ日に入れた「大きい文字では札の題を2行まで」＝戻した（題は1行・はみ出す時は …）。AX最大で再撮影＝下の列は収まる。
- ネタを書く（AX最大）：「候補」は大きい文字の時だけサイコロの絵だけに（読み上げは「題名の候補」）。舞台の絵が細くなるのは大きい文字で下の一覧が伸びるため＝前から（画面の作り）。
