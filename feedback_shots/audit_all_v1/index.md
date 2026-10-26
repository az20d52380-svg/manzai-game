# 全画面監査 audit_all_v1（iPhone 17・MZ_NOCHIP=1・900px）

共通: MZ_NOCHIP=1 を付けて起動。番号はプレイ順。

|番号|画面名|開き方（環境変数）|備考|
|--|--|--|--|
|01|タイトル|MZ_UI=intro_title||
|02|導入回想カード|MZ_UI=intro||
|03|名前決め|MZ_UI=intro_name||
|04|週メイン|MZ_UI=stage||
|05|練習選び|MZ_UI=cards MZ_FREE=1 MZ_WEEK=practice||
|06|バイト|MZ_UI=cards MZ_FREE=1 MZ_WEEK=baito||
|07|休む|MZ_UI=cards MZ_FREE=1 MZ_WEEK=rest||
|08|ネタを書く_ネタ選び|MZ_UI=weeknetas MZ_FREE=1 MZ_WEEK=netawrite||
|09|ネタを書く_新しく書く|MZ_UI=weeknetas MZ_FREE=1 MZ_WEEK=newneta||
|10|お店|MZ_UI=cards MZ_FREE=1 MZ_WEEK=shop||
|11|能力アップ|MZ_UI=allocate||
|12|能力アップ_粒不足|MZ_UI=allocate MZ_MODE=short||
|13|能力アップ_＋押下後|MZ_UI=allocate MZ_TAPS=1||
|14|日程カレンダー|MZ_UI=calendar||
|15|コンビ画面_ちから|MZ_UI=notebook||
|16|コンビ画面_記録|MZ_UI=notebook MZ_TAB=kiroku||
|17|ネタ帳_一覧|MZ_UI=neta_list||
|18|設定|MZ_UI=settings||
|19|設定_やめる確認|MZ_UI=settings MZ_STEP=1||
|20|大会前の振り忘れの知らせ|MZ_UI=prestage||
|21|大会エントリー|MZ_SMOKE=2||
|22|大会エントリー_ネタ選び|MZ_UI=netaentry||
|23|本番前カード_GP|MZ_UI=prelude||
|24|本番前カード_決勝|MZ_UI=prelude_final||
|25|本番の舞台_部品_lit|MZ_UI=frame MZ_MODE=lit||
|26|本番の舞台_preshow|MZ_UI=frame MZ_MODE=preshow||
|27|本番の舞台_judging|MZ_UI=frame MZ_MODE=judging||
|28|舞台_winner|MZ_UI=frame MZ_MODE=winner||
|29|舞台_loser|MZ_UI=frame MZ_MODE=loser||
|30|舞台_spectator|MZ_UI=frame MZ_MODE=spectator||
|31|ジュース演出|MZ_UI=juice||
|32|予選結果_波形|MZ_SMOKE=1||
|33|予選結果_講評|MZ_SMOKE=1||
|34|予選結果_通過|MZ_UI=pass||
|35|予選結果_通過_完了|MZ_UI=result_done||
|36|ファン報告|MZ_UI=result_done MZ_FANREPORT=1||
|37|決勝演出_籤|MZ_SMOKE=4||
|38|決勝演出_先の組|MZ_SMOKE=4 MZ_FIN=pre||
|39|決勝演出_審査員開票|MZ_SMOKE=4 MZ_FIN=open||
|40|決勝演出_講評|MZ_SMOKE=4 MZ_FIN=comments||
|41|決勝演出_ボード|MZ_SMOKE=4 MZ_FIN=board||
|42|決勝演出_一騎打ち|MZ_SMOKE=4 MZ_FIN=duel||
|43|決勝演出_優勝|MZ_SMOKE=4 MZ_FIN=win||
|44|年末リザルト|MZ_SMOKE=3||
|45|年末リザルト_優勝ボード|MZ_SMOKE=5||
|46|エンディング|MZ_UI=ending||
|47_0011|イベント会話_0011|MZ_UI=event MZ_EV=0011||
|47_0012|イベント会話_0012|MZ_UI=event MZ_EV=0012||
|47_0013|イベント会話_0013|MZ_UI=event MZ_EV=0013||
|47_0014|イベント会話_0014|MZ_UI=event MZ_EV=0014||
|47_0015|イベント会話_0015|MZ_UI=event MZ_EV=0015||
|47_0016|イベント会話_0016|MZ_UI=event MZ_EV=0016||
|47_0022|イベント会話_0022|MZ_UI=event MZ_EV=0022||
|47_0025|イベント会話_0025|MZ_UI=event MZ_EV=0025||
|47_0027|イベント会話_0027|MZ_UI=event MZ_EV=0027||
|47_0028|イベント会話_0028|MZ_UI=event MZ_EV=0028||
|47_0029|イベント会話_0029|MZ_UI=event MZ_EV=0029||
|48|ランクアップ|MZ_UI=cards MZ_FREE=1 MZ_RANKUP=1||
|49|複数年_2年目|MZ_UI=stage MZ_YEARS=1||

## 撮れなかった／未撮影
- 日常の下位画面のうち、練習の個別メニュー・休むの個別メニューは 05/07 の一覧まで（個別の実行後は週送りになるため）。
- 敗者復活の山場（TournamentResultView climaxIndex）・決勝の負け版（FinalsPresentationView の loser）: 専用フック無し（結果が負けの時のみ・実プレイが要る）。
- 観客席から観る決勝（spectator）: FinalsPresentationView(spectator:true) 専用フック無し（watchingFinal は第47週に決勝へ進めなかった年のみ）。
- NotificationPromptView（通知許諾）: 導線から外れて休眠＝フックは MZ_UI=notif（今回は撮影対象外）。
- 選択肢イベントの 0012 は金欠帯・他は MZ_EV で強制発火（47_*）。
- 今回足した DEBUG フック: MZ_UI=intro_title/intro_name/prelude/prelude_final/weeknetas、MZ_WEEK=practice/baito/rest/netawrite/newneta/shop/allocate/settings/notebook/calendar（WeekMainView）。
