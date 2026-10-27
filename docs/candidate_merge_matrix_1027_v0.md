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
