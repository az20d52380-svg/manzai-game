# 最近目視していない画面の目視 10/26

## 選んだ画面と理由
docs/*1024〜1026*.md で `MZ_UI=<値>` として出てこなかった値から6つ：spectator / debt / rent / catalog / finalist_announce / weekend（いずれも iPhone 17・MZ_NOCHIP=1・起動4秒後に1枚）。

## 所見
### 重要
- なし

### 軽微
- spectator と weekend が通常の週メイン（1年目 第1週）と同一画面になった。フックが専用画面へ直行していない可能性（起動4秒では遷移前の可能性もあり、要確認）。
- rent は第4週の週メイン（所持金 ¥200,000・「免許の更新に行って」の一言）で、家賃の専用画面ではない。フックの用途要確認。
- catalog（部品見本）は下部の日程／コンビ／設定バーが一覧に重なって見える。デバッグ画面のため影響小。

### 問題なし
- debt：「短期バイトの話」の会話。切れ・重なりなし。借金 -¥100,000 の赤バッジも読める。
- finalist_announce：「準決勝の終演から、しばらく。」の暗転。崩れなし。
- 週メイン画面（spectator/weekend/rent）：文字切れ・はみ出しなし。
- 関西弁の残り・％表示：どの画面にもなし。

## 撮影の保存先
/Users/hujiko/manzai-game/feedback_shots/rare_screens_1026/（spectator, debt, rent, catalog, finalist_announce, weekend の各 .png・長辺700）

## 親の訂正（10/26 夕）
- spectator・weekend・rent が「専用画面にならない」のは不具合ではなく呼び方の違い：spectator は `MZ_MODE`（舞台の枠の型・RootView.swift:481）、weekend は `MZ_UI=event MZ_EV=weekend`（RootView.swift:295・10/26 夜に目視済み）、rent は `MZ_UI=rent MZ_WEEK=rent` の併用（WeekMainView.swift:106）。軽微は catalog（DEBUG の部品見本）の1件だけ＝直さない。
