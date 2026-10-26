# 女性コンビ・会話画面の目視 v0（2026-10-27）

形：femaleFemale（ff）／maleFemale（mf＝自分が男・相方が女）／femaleMale。iPhone 17・MZ_NOCHIP=1。スクショは feedback_shots/female_1027/（未コミット）。既に見た画面（combo_gender §7・§8、visual_check_female_1025、female_later_years_1026 の disband・ending 1・event partner/weekend・finals・frame winner・intro・netaentry・week・yearend）とは重ねていない。

| # | 画面・フック | 形 | 見た所 | 問題 |
|---|---|---|---|---|
| 01 | MZ_UI=intro_name | ff | 結成届の自分欄「私」、相方欄「谷口」 | なし（相方欄は谷口のままは仕様） |
| 02 | MZ_UI=intro_name | mf | 自分欄「俺」 | なし |
| 03 | MZ_UI=event（既定0011 月末の飲み会） | ff | 札「私」・「ほとんど残らないよ」 | なし。生の {me} なし |
| 04 | MZ_UI=event MZ_EV=0012 短期バイト | ff | 「けっこう稼げるね。でも、夜勤なんだ」 | なし |
| 05 | MZ_UI=event MZ_EV=0016 目が冴えた夜 | mf | 札「俺」・「もう夜中だよ。明日、起きられる？」 | なし（男でも自然） |
| 06 | MZ_UI=week MZ_WEEK=farewell 解散の別れ | ff | 札「私」、谷口「体には気をつけてね」 | 軽微：私「話がある。コンビは今日で終わりにしよう」がやや硬い（女でも通る範囲） |
| 07 | MZ_UI=qual_notice | ff | 通知（頂GP公式） | 会話なし・性別語なし |
| 08 | MZ_UI=finalist_announce | mf | 「あなたのコンビ」 | 会話なし・性別語なし |
| 09 | MZ_UI=ending MZ_ENDING=3 | ff | 「私のアパート」・谷口「……そっか。十年だもんね」 | なし。人形は札「私」「谷口」 |
| 10 | MZ_UI=offer（週画面） | femaleMale | オファー表示 | 性別語なし |

## 結論
- 男の語の残り・{me}/{partner1} の生記号：0件。
- 問題：重さ「小」が1件（#6 解散の台詞の硬さ。直し案：「話があるの。コンビ、今日で終わりにしよう」。表示の文の置き換えだけ）。
- 人形の見た目は今回の画面では札の文字だけで、髪型の確認は別の画面（舞台）が必要。

## 親の確認（10/26 深夜の定期）
- 解散の台詞の案（「話があるの。…」）は採らない：台詞は男女どちらでも自然な1本にする方針（キュー120・combo_gender_v0 §8）＝形ごとの語尾の出し分けはしない。今の文のまま。
- 人形の髪型・見た目は今回未確認（次の目視の回に MZ_KIND で舞台系を）。

## 人形の見た目（追記）
コード確認：人形（ManzaiFigure）は StageOutfit.ore/taniguchi(kind) で女の髪型（.long/.bun）と服色を出し分け済み。顔アイコンは FaceCatalog.ore/taniguchi(for:) で出し分け済み。出し分けが無い部品は審査員の顔（固定の7人・形に依存しない設計で問題なし）。見た画面は ff・mf の frame／finals／ending／intro／neta ほか（champ・yearend_old は MZ_UI がその名前を拾わず週画面に落ちた＝人形は週画面の寄席で確認）。スクショ feedback_shots/female_1027/doll_*.png（未コミット）。

| 画面 | フック | 形 | 問題 | 直し方の案 | 重さ |
|---|---|---|---|---|---|
| 舞台 本番（後ろ姿） | MZ_UI=frame | ff | 私＝紫の着物・髪は短いボブ風、谷口＝ピンク・お団子。男の絵のままの所なし。ただ後ろ姿で着物の形が男女同じ（髪と色だけで判別）。 | 今のままで可。差を強めるなら肩幅・裾の丸みを女は少し変える。 | 小（任意） |
| 舞台 本番 | MZ_UI=frame | mf | 俺＝青・短髪、谷口＝ピンク・お団子。形に合っている。 | なし | なし |
| 週画面の寄席（人形） | 既定の週 | ff／mf | 同上（ff は私が紫＋ボブ、谷口がお団子）。男の絵の残りなし。 | なし | なし |
| 決勝の審査員席 | MZ_UI=finals | ff | 審査員7人の顔は固定（形に依存しない）。人形は出ない。 | なし | なし |
| 最終興行 | MZ_UI=ending | ff | 人形は出ない（札と金額のみ）。 | なし | なし |
| 結成回想 | MZ_UI=intro | ff | 人形は縦札「私」「谷口」のみ＝髪型の出し分けは対象外。 | なし | なし |
| ネタ帳（コンビ） | MZ_UI=neta | ff | 人形なし（数値表）。 | なし | なし |
| 形の選択 | MZ_UI=combokind | ff／mf | 顔アイコンは形ごとに切替済み（コード確認のみ・撮影は上の一覧）。 | なし | なし |

結論：男の絵のままの所は0件。任意の小改善1件（後ろ姿の着物の輪郭が男女同じ）。優勝・年末の専用画面の人形は MZ_UI の名前が合わず未撮影（champ／yearend_old は effective でない＝要フック名の確認）。

## 親の追加撮影（10/26 深夜の定期）
- 優勝の演出：`MZ_FX=champion MZ_KIND=femaleFemale`（MZ_UI=champion は無い＝演出の単独再生は MZ_FX）。人形なし・「CHAMPION DUO」・谷口の台詞とも中立＝問題なし。
- 年末総決算：`MZ_UI=yearend MZ_KIND=femaleMale`。人形なし・男女の語なし＝問題なし。
- 形の値は maleMale / femaleFemale / maleFemale / femaleMale（ComboKind.swift:8）。
