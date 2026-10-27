# 候補ブランチの合わせ表（2026-10-27 深夜の定期）

オーナーが複数の候補を「OK」にした時、続けて本体へ入れられるかの確認。本体 bc2702e 時点。

## 要点
- 候補16本は、どれも**単独なら今の本体にそのまま merge でき、GameCore 433〜436／アプリ 271〜272 green**（7本は本体を取り込み直して push 済み・the-hana は新しいブランチ `claude/the-hana-candidate-r1027`＝d20a262）。
- 候補どうしの衝突は2種類だけ：
  1. **テストのファイルの末尾**（ManzaiGame/Tests/ManzaiGameTests.swift）：career-end-save・mob-roster-per-run・money-short-choice・revival-short・tv-fatigue-display・yearly-goal の6本どうし（全15組）。2本目以降は `python3 tools/merge_candidate_tests.py <取り込む側のブランチ>` で解ける（中身の衝突ではない）。
  2. **the-hana × calendar-jan**（GameSession.swift の起動時の1か所）：片方は WeekRunner に `hanaEnabled:` を足し、片方はコメントの「4月→1月（年初）」を直しただけ＝`hanaEnabled:` 付きの行＋「1月（年初）」のコメントで解く。
- 意味の上の注意：the-hana の決勝の週は「ゲームの暦で2月第4週」（the_hana_measure_1025_v0 §7）。calendar-jan（暦を1月始まりに）を入れると、同じ週が年の終わり寄り（11〜12月）の表示になる（オーナー案の「12月上旬」に近づく）＝両方入れる時は THE HANA の時期の言葉を見直す。

## 衝突しない組
上の2種類以外の組（a11y-tap-next・allocate-confirm・final-year-history・lost-notebook-neta・offer-desc-short・qual-long-list・season-sure・week-hint-priority を含む全組）は、merge-tree で衝突なし。

## 候補ごとの一言（OK なら merge するだけ）
| ブランチ | 何が変わるか | 論点 |
|---|---|---|
| a11y-tap-next-cand | 読み上げ（VoiceOver）中の二度押しでも演出の頁が進む（9画面） | キュー131 |
| allocate-confirm-cand | 振り分け0の時は「確定」を薄く・押せなく | キュー138 |
| calendar-jan-candidate | 暦を1月始まりに（決勝が12月） | キュー128 |
| career-end-save-candidate | 区切りの年末もセーブを残す | キュー117（candidate_review_1026） |
| final-year-history-cand | 最終年だけ「これまでの頂GP」を総決算の上へ | キュー136 |
| lost-notebook-neta-candidate | 「なくしたノート」を「ネタ帳」に | decision_brief_1025 #17 |
| mob-roster-per-run-candidate | 周ごとに決勝のモブの組が変わる | candidate_review_1026 |
| money-short-choice-candidate | お金だけが足りない選択肢を灰色で残す | decision_brief_1025 #7 |
| offer-desc-short-cand | 下のオファー札は名前と値札だけ | キュー137 |
| qual-long-list-candidate | 予選の通過者を長い一覧に | キュー110 |
| revival-short-candidate | 敗者復活で散る山場の2回目以降は短い版 | キュー127 |
| season-sure-candidate | 夏祭り・年末ライブを時期の最初の空いた週に必ず | キュー129 |
| the-hana-candidate-r1027 | 女コンビの大会 THE HANA（golden に関わる） | 判断待ち「THE HANA の難しさ」 |
| tv-fatigue-display-candidate | テレビ慣れを状態名で見せる | キュー112 |
| week-hint-priority-candidate | 週の一言でお金と体力の警告を先に | decision_brief_1025 #4 |
| yearly-goal-cand | 年末に「来年の狙い」を1行 | キュー132 |
