# 大文字（accessibility-large）目視 2026-10-26 v0
iPhone 17 / content_size accessibility-large で各1枚。スクショ: feedback_shots/largetext_1026/<名前>.png（content_size は large に戻し済み）。debugChip（優勝/無双）は所見にしない。

- a 年末総決算 上の段（MZ_UI=yearend MZ_YEARS=1）: 崩れなし。見出し「頂グランプリ 到達段階」は2行折り返しで全文読める。賞金/知名度/最終所持金の3枠は「¥272,000」まで収まる。「3年目へ」ボタンは画面内。
- b 下の段（MZ_SCROLL=history）: 崩れなし。出来事の「第48週 頂GP 決勝 優勝「（見本）（客席から）」」は折り返しで全文読め「観戦」札も収まる。独白・使い方帯・「年初と現在」の見出しも切れなし。
- c 戦績タブ（MZ_UI=notebook MZ_YEARS=1 MZ_TAB=kiroku）: 崩れなし。「これまでの頂グランプリ」「今年の大会」の年表と「+500万」「優勝」札が同じ行に収まる。3カラムの「3回/1回/500万」も詰まらない。
- d 大会の記録タブ（MZ_TAB=kiroku・1年目）: 崩れなし。注: 実装上 c と d は同じ「戦績」タブ（enum .kiroku）で、年表の有無だけ違う。「優勝「ひだまり座」（客席から）」は折り返し＋「観戦」札で収まる。

崩れあり: 0件（軽微0件）。
気づき（崩れではない）: 末尾が「（客席から）」で折れる行は2行になるだけで読める。直す場所なし（参考: YearResultView.swift / NotebookView.swift）。
