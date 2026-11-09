# 大文字（accessibility-large）目視：まとめの枝 text-all-1110-bundle-cand（a3e57030）2026-11-10 v0
結論：新しい崩れなし（8枚・iPhone 17のみ）。切れ・はみ出し・重なりは見当たらない。文字の大きさは large に戻し済み。
撮り方は前例 visual_largetext_allbundles_1109_v0.md と同じ（simctl ui content_size・SIMCTL_CHILD_MZ_*）。スクショ: docs/shots_1110/lt_*.png

| 画面（フック） | 所見 |
|---|---|
| lt_gloss（MZ_UI=glossary MZ_GLOSS=4） | 崩れなし。「すれ違い」の新文4行・大会節の長文とも折り返しで収まる（下端の「頂グランプリの回戦」が画面端で切れるのはスクロール） |
| lt_settings_bottom（settings MZ_SCROLL=career） | 崩れなし。解散の注意文2行・ボタン・権利表記とも収まる |
| lt_gacha | 崩れなし。ログインボーナス・ガチャ3ボタン・天井・かけら行とも収まる |
| lt_gacha_rates（gacha_rates） | 崩れなし。注記・割合表とも収まる（下は注釈でスクロール） |
| lt_allocate（allocate） | 崩れなし。表・ボタン4つ・特技札とも収まる |
| lt_week（week STOPWEEK=14 NOCHIP=1） | 崩れなし。目標帯・体力の一言（1行）・コマンド・下の3ボタン収まる。舞台の二人は見える |
| lt_trophies（trophies 15,16,22） | 崩れなし。称号3件の名前＋条件は1〜2行で収まる |
| lt_finals_spec（finals_spectator FIN=board） | 崩れなし。観戦の帯の説明（1行）・暫定ボード・下の帯とも収まる |

既知（前例どおり）：長い画面の下端が切れるのはスクロール。本体の大きい文字の既知の崩れ（offers の舞台）は今回の対象外。
