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
