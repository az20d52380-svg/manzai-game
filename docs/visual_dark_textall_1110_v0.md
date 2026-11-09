# ダークモード目視：まとめの枝 text-all-1110-bundle-cand（a3e57030）2026-11-10 v0
結論：新しい問題なし（8枚・iPhone 17のみ）。読めない色・背景と文字の重なりは見当たらない。appearance は light に戻し確認済み。
撮り方は前例 visual_dark_allbundles_1109_v0.md と同じ（simctl ui appearance dark・SIMCTL_CHILD_MZ_*）。スクショ: docs/shots_1110/dk_*.png

| 画面（フック） | 所見 |
|---|---|
| dk_gloss（glossary MZ_GLOSS=4） | 崩れなし。「すれ違い」の新文・大会節とも紙色の札に暗い文字で読める |
| dk_settings_bottom（settings MZ_SCROLL=career） | 崩れなし。解散の注意文・赤枠ボタン・権利表記とも読める |
| dk_gacha | 崩れなし。ログインボーナス・ガチャ3ボタン・天井・衣装グリッドとも読める |
| dk_gacha_rates | 崩れなし。注記・割合表とも読める |
| dk_allocate | 崩れなし。表・経験点の色札・ボタン4つ・特技札とも読める |
| dk_week（week STOPWEEK=14 NOCHIP=1） | 崩れなし。目標帯・体力の一言・コマンド・下の帯とも読める |
| dk_trophies（trophies 15,16,22） | 崩れなし（エンディング図鑑の画面に称号3件）。名前＋条件とも読める |
| dk_finals_spec（finals_spectator FIN=board） | 崩れなし。観戦の帯・暫定ボード・敗退行（半透明）とも読める |

既知：長い画面の下端が切れるのはスクロール。
