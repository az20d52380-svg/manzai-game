# 内部の名前が画面に出る所の点検 1027（v0）

## まとめ
- 確実に出る所：**0件**（今日直した WeekMainView の `"\(c) +…"` 以外に、画面用の別名を持つ enum の case 名がそのまま Text・トースト・読み上げ・GameCore の文に出る所は見つからなかった）。
- 推測／潜在（今は出ていないが、名前を変えると漏れる所）：**3件**（#1〜#3）。うち実害のある漏れは無し。
- 点検対象：別名の仕組みがあるのは ExpCurrency（displayName）・Training（CommandData.swift:46-115 と AbilityUpView.practiceLabel の2表）・NetaKata/NetaLength（NetaCatalog.displayName）・Theme.currencyChar。いずれも画面側は別名経由。

## 表
| # | ファイル:行 | 画面に出る文の例 | 正しい表示名 | 直し方の案 | 確度 |
|---|---|---|---|---|---|
| 1 | ManzaiGame/Sources/ShopView.swift:135 | `Text(item.rawValue)` →「ネタ作家の勉強会」「ボイトレ短期集中」 | 今は rawValue がそのまま売り物の名前（別名の表は無い）。同じ名の Training.作家の勉強会 は画面で「大喜利ライブに出る」＝名前がずれたまま | ShopItem に displayName を足して ShopView.swift:135 で使う（case 名を変えてもセーブ rawValue を壊さない） | 推測（潜在・今は漏れではない） |
| 2 | ManzaiGame/Sources/AbilityUpView.swift:101・119 | `「\($0.rawValue)」を覚える？`・`Text(k.rawValue)` →「体が資本」等 | Skill に別名の表が無く rawValue が表示名を兼ねる | Skill に displayName を足し2か所で使う | 推測（潜在） |
| 3 | ManzaiGame/Sources/CommandData.swift:46-115 と AbilityUpView.swift:368-378 | Training の画面名が2つの表に重複（「大喜利ライブに出る」等） | 同じ | 表を1か所（Training の拡張）にまとめ、片方を呼ぶ形にする。ずれると片方だけ古い名が出る | 推測（潜在・重複） |

## 漏れではないと確認したもの（参考）
- Ability（センス・発想・表現・華・メンタル）：case 名がそのまま画面名＝AbilityUpView:199/297・RadarChart:59・YearResultView:119・ChoiceEventOverlay:316 の `"\(a)"` は正しい。
- ExpCurrency：画面は displayName（AbilityUpView:138/249/402・WeekMainView:933）か Theme.currencyChar（WeekMainView:931/1077/1533）を使用。case 名の直書きなし。
- Training/Rest/Job：`"t_\(t)"` `"rest_\(r)"` `"job_\(j)"`（CommandData.swift:49/71/82/95/112）は内部 id のみ（DialogueData の反応キー）。画面の Text には出ない。
- NetaKata/NetaLength：画面は NetaCatalog.displayName（FinalsPresentationView:895 等）。JudgeTalk は kata を使わない（JudgeTalk.swift:57）。
- GameCore の文字列補間：WeekRunner.swift:234/355/383（"GP回戦N"）と JudgeTalk の {題}/スロット置換のみ。enum の case 名は入っていない。
- デバッグ専用で除外：GameSession.swift:1690・1714・1717・1752・1771・1826（[AT] 行・fputs）。
- CommandCategory.rawValue（WeekMainView:644/1005）は画面名そのもの。

## 親の確認（10/27 定期）
- 練習の画面名の2つの表（CommandData.swift と AbilityUpView.swift:368）は、今は全行一致（相方と合わせる・大喜利ライブに出る・カラオケボックスで声出し 等）。1つにまとめるのは片付けとして後回し（名前を変える時は両方を直す）。
- ShopView の `item.rawValue`（例「ネタ作家の勉強会」）はお店の品の名前そのもので、練習の「作家の勉強会」（画面名＝大喜利ライブに出る）とは別物＝今は漏れではない。
