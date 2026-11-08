# shots_1109（decision_brief_2026-11-08 C 節・前＝本体／後＝候補）

| C | 候補 | フック | 前 | 後 | 違い | 一言 |
|---|---|---|---|---|---|---|
| C-1 | （既存） | - | c1_offer_desc_before.png | c1_offer_desc_after.png | 写る | 既存 |
| C-2 | claude/allocate-confirm-cand | MZ_UI=allocate | c2_allocate_before.png | c2_allocate_after.png | 写る | 振り分け0のとき「確定」が薄くなり押せない（前は赤く押せる） |
| C-3 | claude/final-year-history-cand | MZ_UI=yearend MZ_YEARS=14 MZ_CARE=1 | c3_yearend_before.png | c3_yearend_after.png | 写る | 最終年は「これまでの頂グランプリ」が上に来て、年ごとの行が見える |
| C-6 | claude/partner-action-name-cand | MZ_UI=week MZ_WEEK=rest | c6_rest_menu_before.png | c6_rest_menu_after.png | 写る | 「相方と過ごす」→「相方とネタの話をする」 |
| C-9 | claude/hana-loss-line-cand | MZ_UI=hana_result MZ_PASS=0 | c9_hana_loss_before.png | c9_hana_loss_after.png | 写る | THE HANA 1回戦で落ちた時に谷口の「……次、いこう」の札が増える |
| C-19 | claude/combi-name-verbatim-cand | MZ_UI=calendar MZ_COMBI=谷口バンド MZ_NAMES=俺,佐藤 | c19_combi_name_before.png | c19_combi_name_after.png | 写る | 日程表の見出しのコンビ名：前は相方名に置き換わって「佐藤バンド」、後は入力どおり「谷口バンド」（11/09 親が撮り直し） |
| C-4a | claude/money-format-cand | MZ_UI=shop | c4_shop_before.png | c4a_shop_after.png | 写る | お店の家賃・値札：前は +¥50,000／¥20,000、後は +5万円／¥2万（1万円以上が「万」表記。¥3,000 は同じ）。部屋カードと品書きの値札を見る |
| C-4b | claude/money-format-cprime-cand | MZ_UI=shop | c4_shop_before.png | c4b_shop_after.png | 写る | C-4a と同じお店画面。a との違いは右上の所持金の帯が「¥30万」になる所（11/09 親が確認） |
| C-15 | claude/lost-notebook-neta-candidate | MZ_UI=event MZ_EV=0056 | c15_lostnote_before.png | c15_lostnote_after.png | 写る | 「二人のノート」→「二人のネタ帳」、「書いてるノート」→「書いてるネタ帳」（谷口と俺の2行を見る） |
| C-17 | claude/final-neta-notice-cand | MZ_UI=prelude_final MZ_NOTICE=1 | c17_final_notice_before.png | c17_final_notice_after.png | 写る | 2本目カードの下に赤字「1本目を2本目と同じネタにしたので、2本目の選択が外れました。選び直してください。」が増える |
| C-18 | claude/announce-order-cand | MZ_UI=finalist_announce | - | - | 写らない | 呼ばれる順の差は漢字名の位置だけで、発表の動きの途中の並びにしか出ず、静止画では前後が同じに見える（カタカナ名・谷口バンドで確認） |
| C-22 | claude/youth-notice-y10-cand | MZ_UI=week MZ_YEARS=9 MZ_STOPWEEK=1 MZ_CARE=1 | c22_youth_before.png | c22_youth_after.png | 写る | 10年目1週の下に谷口の一言の札が出る（後のみ・起動7秒後に撮らないと消える）。前は札なし |
| C-24 | （既存） | - | c24_offer_stamina_note.png | - | - | 既存 |
| C-25 | （既存） | - | c25_calendar_gp_paint.png | - | - | 既存 |

注: C-2 の「前」でも持ち分の割り振り表示は同じ（フックが粒を積んだ状態）。差は右下の確定ボタンのみ。
