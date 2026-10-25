# 女性の形・後半の年の目視（2026-10-26）

基準：combo_gender_v0.md §8。形 femaleFemale / femaleMale、iPhone 17。保存先 feedback_shots/female_later_1026/（7枚）。

## §1 撮った画面と所見
| 画像 | 形・年・週・画面 | 所見 |
|---|---|---|
| ff_y3_w20_week | femaleFemale 3年目 週20 week | 札「私」「谷口」・ふき出し「目の検査に行っておこう。」。男言葉なし・顔/札の崩れなし |
| ff_y10_w30_week | femaleFemale 10年目 週31 week | 「通った。この調子で、次も準備しよう。」。問題なし（週は STOPWEEK=30 で31表示） |
| ff_y10_yearend | femaleFemale 10年目 yearend | **年末画面は開かず、上と同じ week 画面**（yearend フックは MZ_YEARTURN 併用でないと年の幕間に入らない・週が0〜1でないと発火しない）。年末画面の目視は未達 |
| fm_y6_w12_week | femaleMale 6年目 週13 week | 「背中が張っている。寝る前に体を伸ばしておこう。」。問題なし。相方の絵は男の形のまま崩れなし |
| fm_y6_w12_notebook | femaleMale 6年目 notebook(コンビ) | 実力/相性・名札（相方 谷口）。性別語なし |
| ev_weekend | femaleFemale event=weekend | 先輩「疲れたな。少し付き合わないか」＝第三者の口調でOK。谷口「いいかな。どうする？」中立 |
| ev_styleTalk | femaleFemale event=styleTalk | 谷口「重いんだよね」・私「顔、疲れてるよ。ちゃんと休めてる？」＝§8 の直し後の言い方どおり |

ソース確認：
- 札の「俺」は Names.show（Text の init 経由）で全画面「私」に置換される。StageScene.swift:79 / StageFrame.swift:146 の `StageFootTag(name: "俺")`、S6bView.swift:152・EndingViews.swift:385 の `Advice(name: "俺")` も同経路で漏れなし。
- {me}/{partner1}：「{me}ら」「{partner1}ら」の直書きは Names.swift:40 のコメントのみ＝ChoiceEventData の「ら」は既に「たち」へ直済み。差し込み記号の漏れ 0 件。
- 「俺」を文中に直書きした台詞は堀口(ChoiceEventData.swift:824)・野々村(:1223)のみ＝第三者の口調でOK。
- TournamentResultView.swift:591〜600 は §8 の「未対応」記載だが、現物は既に「見ていく？」「すごかったね」「悔しいね」「何か食べて帰ろう」に直済み（§8 の記述が古い）。

## §2 直す候補
**表示だけで直せる物**：なし（差し込み漏れ・札・顔の崩れは今回の範囲で0件）。
**台詞の判断が要る物**：なし。
**文書の更新（任意）**：combo_gender_v0.md §8 の「未対応：TournamentResultView.swift:591〜598」は済に更新。
**未確認**：年末(yearend)画面と年の幕間は撮れていない。次回は MZ_UI=yearend + MZ_YEARTURN=1 で（STOPWEEK は外す）撮る。
- 追記（親・10/26）：femaleFemale の10年目の年末総決算を `MZ_UI=yearend MZ_YEARS=9 MZ_CARE=1`（STOPWEEK なし）で撮影＝崩れなし・朱印「準々決勝敗退」は見出しに被らない。これで女性の形の後半の年の目視は済。
