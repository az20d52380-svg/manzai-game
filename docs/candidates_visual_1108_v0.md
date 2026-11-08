# 小件候補の目視と B-6 候補 11/08

iPhone 17・`simctl` の起動と撮影のみ（タップなし）。4本＋B-6 を重ねたビルドで確認。本体には入れていない。スクショは scratchpad（`/private/tmp/claude-501/-Users-hujiko/37ff8b23-7a0b-4215-b211-13a066de339e/scratchpad/`）の `v_*.png`・`b6.png`（コミットしない）。

## §1 目視の所見（崩れなし・直し 0）
- C-6 `claude/partner-action-name-cand`：`MZ_UI=week MZ_WEEK=rest`（v_rest.png）。「相方とネタの話をする」は札の1行に収まり、折り返し・切れなし。
- C-5 `claude/notebook-entries-label-cand`：`MZ_UI=notebook MZ_TAB=kiroku`（v_kiroku.png）。「今年の出場／通算の優勝／通算の賞金」の3列が崩れず並ぶ。
- C-17 `claude/final-neta-notice-cand`：決勝の本番前（v_notice.png）。朱の注意文は2行で、下の「本番へ」を押し出さずに収まる。この目視のため DEBUG フックを候補側に1コミット足した（22a5f2e9・`MZ_UI=prelude_final MZ_NOTICE=1`・本体には無い）。
- C-9 `claude/hana-loss-line-cand`：`MZ_UI=hana_result MZ_PASS=0`（v_hana.png）。「谷口：……次、いこう」が講評の下に収まり、「次へ 進む」と干渉なし。

## §2 目視できなかった物
- 7本のうち B-13（無音の間・音と時間）、C-16（トロフィーの数え方）、C-18（読み上げ順）は見た目が変わらない or 時間の挙動のため対象外。C-18 はテストで確認済み。

## §3 B-6 `claude/first-pass-share-cand`（c86c4136）
- 内容：初めての大会（GP）通過の祝い（YosePassCelebrationView の上）にだけ共有ボタンを出す。端末に UserDefaults の印を1つ持ち（`manzai.firstPassShareOffered.v1`）、1回出したら以後は出ない。セーブ本体・GameCore・式・乱数・GameConfig・golden は不変＝SaveDataConventionTests の対象外。
- カードの文：見出し「初めての通過」・補足「GP1回戦　結成1年目」・コンビ名・アプリ名。％・ボケなし。既存の ShareCardButton を再利用。
- 目視：`MZ_UI=result_done MZ_PASSFX=1 MZ_FIRSTPASS=1`（b6.png）。「画面をタップして進む」の上に「共有」ボタンが収まる。（MZ_FIRSTPASS は DEBUG 限定）
- テスト：GameCore 448件 0失敗／アプリ 356件 0失敗（新 FirstPassShare1108Tests 2件含む）／ビルドのエラー 0。xcodegen で project.pbxproj 更新済み。
- 未確認：共有シートを実際に開く操作（タップ禁止のため）・「出す」判定を2回目以降の実プレイで見る点。既存セーブで続ける人は次の通過で1度出る。
