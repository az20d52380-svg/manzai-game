# 文の直しのまとめの枝（56d59b77）の目視 v0（11/10）

結論：
1. 見られた7画面（用語集・設定・ガチャ・提供割合・能力アップ・決勝の審査員席・週メイン）で、切れ・はみ出し・折り返しの崩れは無かった。
2. 画面の縦スクロールの下側（用語集のすれ違い注記、設定の解散の注記全文、能力アップのヒント下段）は MZ_SCROLL 等のフックが無く先頭1画面だけ確認＝一部は未。
3. 称号の説明（t15/t16/t22）・決勝の点の発表・体力切れトースト・決勝の帯は出せず未。

| 画面 | フック | 結果 | スクショ |
|---|---|---|---|
| 用語集（先頭） | MZ_UI=glossary | 崩れ無し（すれ違い・解散の注記は下側で未） | shots_1110/glossary.png |
| 設定 | MZ_UI=settings | 崩れ無し（解散の注記は下端で切れ目＝スクロール未） | shots_1110/settings.png |
| ガチャ | MZ_UI=gacha | 崩れ無し（初回の例外の注記も折り返し正常） | shots_1110/gacha.png |
| 提供割合 | MZ_UI=gacha_rates | 崩れ無し | shots_1110/gacharates.png |
| 能力アップ | MZ_UI=allocate | 崩れ無し（ヒント行の折り返し正常） | shots_1110/allocate.png |
| 決勝の審査員席 | MZ_UI=finals | 崩れ無し（観戦の帯・点の発表までは進まず＝未） | shots_1110/finals.png |
| 週メイン | MZ_UI=cards | 崩れ無し（撮影週の注記） | shots_1110/cards.png |
| エンディング図鑑 | MZ_UI=endingbook | 崩れ無し（称号一覧ではない） | shots_1110/endingbook.png |
| 称号一覧 t15/t16/t22 | 無し | 未 | - |
| 体力切れトースト | 無し | 未 | - |

## §追記（フック追加後・キュー289）
- 新フック: `MZ_SCROLL=career|credits`（MZ_UI=settings）・`MZ_UI=trophies`（図鑑の先頭に称号。MZ_TROPHIES=15,16,22）・`MZ_UI=finals_spectator`（観戦。開始は審査員席の場面＝「客席から観戦」の帯の場面までは進まず、帯は未）。用語集は既存の MZ_GLOSS=<n>。
- まとめの枝（本体フック取り込み）で撮影: 称号 t15/t16/t22＝折り返し・はみ出しなし（`shots_1110/v2_trophies.png`）、用語集「すれ違い」の注記＝崩れなし（`v2_glossary.png`）。観戦の帯は `v2_spectator.png` で審査員席まで（帯の場面は未）。
- 本体: `hook_settings_career.png`・`hook_trophies.png`・`hook_finals_spectator.png`。
