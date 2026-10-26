# Dynamic Type 目視 a11y_check_1026_v0（2026-10-26・読み取りのみ・コード未変更）
条件: iPhone 17 / content_size=accessibility-large（AX1。AX5 までは未確認）/ 撮影後 large に戻した。スクショ: /private/tmp/claude-501/-Users-hujiko/353672c6-e5bd-4021-bb16-3171e606e062/scratchpad/a11y1026_<name>.png

## 画面ごと
- combokind（形の選択）: 崩れなし。4枚とも文字が収まり、補足文も2行で収まる。
- intro_name（名前決め・MZ_MEET=2）: 崩れなし。結成届の行は収まる。下の「結成する！」ボタンは無効（灰色）の見た目＝名前未入力のため正常。「結成印」枠は小さいが読める。
- disband（別れの場面）: 崩れなし。台詞2行にはみ出し・切れなし。
- week=farewell: 崩れなし（本体は disband と同じ）。右上の DEBUG チップ（🏆優勝/💪無双・RootView.swift:420-424）が場面右上の時計に重なる＝DEBUG限定で本番には出ない。
- yearend（年末総決算）: 崩れ1（軽）。見出しカード右の「年次リザルト」「頂グランプリ 3回戦敗退」の文字に DEBUG チップが被り、文字が読みにくい（本番では出ない）。「出来事」一覧は下端がフェードして「下にも続きます」表示＝意図どおり。
- week（週の画面）: 崩れ1（軽）。上部の「春新人賞A まであと11週」帯の下に、帯の外へ「まだネタがない。まずはネタを書こう。」(WeekHint.swift:47) が1行はみ出して細く表示され、直後の吹き出し（相方の台詞）と詰まる。AX1 では収まっているが、さらに大きいと重なる恐れ（WeekMainView.swift:461 付近の帯の高さ固定の有無を要確認）。「ネタを書く」ボタンの副題「まだネタがない。まず一本」は2行に折り返して収まる（WeekMainView.swift:962）。

## 件数
崩れ: 実害のあるもの 0 件／軽微 1 件（week の帯下ヒント行が詰まる）／DEBUG チップの重なり 3 画面（本番影響なし）。
最重の1件: week のヒント行と吹き出しの詰まり（AX1 では判読可・AX3 以上で重なる恐れ）。
次の一手: accessibility-extra-extra-extra-large でも同じ画面を撮って確かめる。

## AX5（accessibility-extra-extra-extra-large・同じ6画面・DEBUGチップは無視）
スクショ: /private/tmp/claude-501/-Users-hujiko/353672c6-e5bd-4021-bb16-3171e606e062/scratchpad/a11y1026ax5_<name>.png（combokind / intro_name / disband / farewell / yearend / week）
- 実害（切れて読めない・ボタンが画面外・重なって押せない）: 0 件。
- 6枚とも AX1 の撮影と見た目が同一。文字が大きくなっていない＝この画面群は Dynamic Type に追従せず固定サイズ（YoseFont の固定pt指定と見られる）。崩れない代わりに、文字サイズ拡大の設定を使う人には効かない（点検の観点が「崩れ」から「追従しない」へ変わる点は別途判断）。
- 前節の week のヒント行の詰まりも AX5 で悪化せず（同一）。
content_size は large に戻した。
- 【親の補足】「追従しない」は誤り。YoseFont は `Font.mzScaled`（Theme.swift:239）で文字サイズ設定に追従するが、上限 1.35 倍で止める作り。AX1 で既に上限に届くため AX1〜AX5 が同じ見た目になる＝設計どおり（10/19 の a11y 点検の方針）。
- 候補ブランチ9本（calendar-jan・career-end-save・lost-notebook-neta・mob-roster-per-run・money-short-choice・qual-long-list・revival-short・tv-fatigue-display・week-hint-priority）は 10/26 夕の本線にぶつからずに入る（git merge-tree）。
