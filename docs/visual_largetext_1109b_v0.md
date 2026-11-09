# 大きい文字（accessibility-large）目視 後半 2026-11-09 v0
iPhone 17・各1枚。スクショ: feedback_shots/largetext_1109b/<名前>.png（content_size は large に戻し済み）。

- 選択イベント（MZ_UI=event）event.png：崩れなし。吹き出し2行・「次へ 進む」ボタン収まる。
- 飲みの誘い／後輩の誘い（MZ_EV=0041）event_kouhai.png：崩れなし。
- 予選の知らせ（qual_notice）qual_notice.png：崩れなし。通知カード1行で収まる。
- 決勝進出者の発表（finalist_announce）finalist_announce.png：崩れなし。
- 決勝の審査員席の演出（finals MZ_FIN=judges）finals_judges.png：崩れなし。名札は2行で収まる（下の講評欄は画面端で切れるだけ）。
- お金が足りない月末の支払い（rent MZ_MONEY=110000）rent_short.png：崩れなし。表・合計・所持金とも収まる。
- ファンレポ／結果画面（result_done MZ_FANREPORT=1）fanreport.png：崩れなし。講評・賞金・知名度の札・ボタンとも収まる。
- 解散の別れの場面（disband）disband.png：崩れなし。台詞3行・選択欄とも収まる。
- はじめにの回想（intro MZ_MEET=2）intro.png：崩れなし。
- バイトの結果（week MZ_WEEK=autojob）autojob.png：崩れあり（低）：結果札「交通量調査 所持金+32,000 体力-10」が舞台の中央に重なり、下の「体力 -10」札が下部バーの「知名度 3」に重なる。一時表示の札。候補: WeekMainView.swift の結果札の配置。舞台の被りは前半 a/b と同系統。
- エンディングの場面（MZ_ENDING=2 MZ_ENDSTEP=cards）ending_cards.png：崩れなし。
- 用語集（glossary）glossary.png：崩れなし。

未撮影: 敗者復活・二人で出かける場面・エンディング別場面の他型（フックが無い／同型）。

集計: 高0／中0／低1（バイト結果札の重なり）。

## 親の照合（11/09 夜）
- autojob：結果の帯（交通量調査 所持金 +32,000 体力 -10）は舞台の上に一時的に出る帯で、文字は1行で読める。下の「体力 -10」は体力の数字から浮き上がる一時の数字（数字の飛び出し）で、知名度の札に少しかかるのは消えるまでの間だけ＝低のまま（直すなら飛び出しの位置を体力の札の上に寄せる）。
- 追加（親）revival：新しい目視フック MZ_UI=stage_result（MZ_STAGE=敗者復活 既定・GP準決勝 も可・MZ_PASS=1 で通過）で敗者復活の敗退の結果画面1枚＝崩れなし（「客席アンケート・ヒトコエ」の札と2行の講評が収まる）。山場のページ（revivalLoss）は数回進めた先で未撮影。
