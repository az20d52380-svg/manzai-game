# 数字の出し方の一貫性チェック v0（コード読みのみ・未編集）

対象: ManzaiGame/Sources。注意: 現在の作業ツリーは WeekMainView.swift:1034 が `Int(d.rounded())` のまま＝preview-all ba3a615 の直しが入っていない側。

## 表（量の種類 × 画面 × 出し方）
| 量 | 画面 | ファイル:行 | 出し方 |
|---|---|---|---|
| 経験点（残高） | 能力アップ画面 / 週メインの「経験点 n たまってる」/ 手帳「経験点 n 未使用」 | AbilityUpView:21,58 / WeekMainView:659,678 / NotebookView:87,95 | `points()`＝内部値×10の切り捨て（共通で一致） |
| 経験点（次の+1の値札） | 能力アップ画面 | AbilityUpView:102,94,133 | `points()`（max(1,…)）。差は points(前)-points(後) |
| 経験点（練習カードの獲得予告） | 週メイン カード | WeekMainView:1034 | **内部値の四捨五入 `max(1,Int(d.rounded()))`（×10なし）** |
| 能力値 | 能力アップ / 手帳 / 週メイン / 手帳バー | AbilityUpView:108,118 / NotebookView:132 / WeekMainView:350 | `Int(v.rounded())` 四捨五入（一致） |
| 実力（jitsuryoku） | 能力アップ / 手帳 / 大会入口 / 結果 | AbilityUpView:72,73 / NotebookView:91 / StageViews:157 / TournamentResultView:66 | `.rounded()`（一致）。大会側のみ「実力+相性」の合計を丸める |
| 相性 | 手帳 | NotebookView:151 | **`Int(s.compat)` 切り捨て** |
| 相性 | カード予告 / バースト | WeekMainView:1036 / 846 | 四捨五入（カードは前後の丸め値の差、バーストは増分を丸め） |
| 知名度 | 年間結果 | YearResultView:230,273 | **`Int(s.fame)` 切り捨て** |
| 知名度（増分） | カード予告 / バースト | WeekMainView:1041 / 859 | **`max(1, Int(fd.rounded()))`（0.4増でも+1に切り上げ）** |
| 知名度（選択肢イベント） | 選択肢結果チップ | ChoiceEventOverlay:228 | 数字なし「↑/↓」（閾値0.001） |
| 完成度（ネタ） | 週メイン ネタ一覧 | WeekMainView:551 | **`Int(n.polish)` 切り捨て** |
| 完成度（ネタ） | 手帳バー / バースト | NotebookView:365 / WeekMainView:851 | 四捨五入 |
| 体力 | 週メイン / GameSession差 | WeekMainView:991,724 / GameSession:256 | 四捨五入（一致） |
| お金（残高） | 下帯 / 買い物 / 年間結果 | WeekMainView:922 / ShopView:37 / YearResultView:232 | `Yen.text`＝¥+3桁区切り、負は「−¥」（一致） |
| お金（残高） | 最後の舞台（S6b） | S6bView:43 | **`"¥\(...)"` 区切りなし・負は0に丸め** |
| お金（増減） | カードの費用ピル | WeekMainView:886-891 | 万円・小数1桁（整数なら小数なし）`+¥2.5万` |
| 賞金 | 大会結果チップ / 手帳履歴 | TournamentResultView:130 / NotebookView:173 | **`r.prize/10000` 整数除算＝切り捨て** 「+15万」「15万」 |
| 賞金 | 年間結果合計 | YearResultView:231 | `Yen.text`（円・区切りあり） |

## ずれている組と直し方
1. 経験点: カード予告(WeekMainView:1034 四捨五入・×10なし) と 能力アップ(points 切り捨て×10)。直し: カード側も `AbilityUpView.points(d)`（ba3a615 の方式）に統一し、max(1,…)も points>0 のときのみに。
2. 相性: 手帳 `Int(s.compat)` 切り捨て vs カード/バースト 四捨五入。直し: 手帳を `Int(s.compat.rounded())` に（実力の合算も rounded なので揃う）。
3. 知名度: 年間結果 `Int(s.fame)` 切り捨て vs 増分 `rounded` かつ最低+1。直し: 年間結果を rounded に。増分の max(1,…) は 0.5 未満でも +1 と出て積算と合わない＝「↑」表示かrounded後0なら出さない、にするか、意図的なら仕様として明記。
4. 完成度: 週メインのネタ一覧 `Int(n.polish)` 切り捨て vs 手帳/バースト 四捨五入。直し: 一覧側を `Int(n.polish.rounded())` に。
5. 賞金/お金の単位: 賞金 `/10000` 切り捨て（5.5万→「5万」）vs 費用ピル 小数1桁（5.5万）vs 年間結果 円表記。直し: 万円表記の共通関数（小数1桁・整数なら省略）を `Yen` に足し、/10000 の2か所とピルで共用。
6. 残高の円表記: S6bView:43 だけ区切り無し・負を0化。直し: `Yen.text(max(0,s.money))` に（0固定演出はそのまま）。
7. （軽微）経験点の値札: `max(1,points(amount))` と 消費の実差 `points(前)-points(後)` の2経路。1段の実コストと値札が±1ずれ得る。直し: 値札側も同じ差分計算に寄せる。

ずれ件数: 7（うち実害が大きい順に 1, 3, 5。2・4・6 は表示だけの小さな不一致、7 は要実測）。
