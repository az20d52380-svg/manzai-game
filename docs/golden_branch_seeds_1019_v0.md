# 分岐 golden の種（2026-10-19）
背景: gamecore_review_1019 §5。3年 golden（seed 424243）は敗者復活・GPシード・王者シード・ライン上書きを通らない。
実装: tools/gen_golden.py の BRANCH_SCRIPTS（期待値は生成器の出力を CareerGoldenTests.swift の branchA/branchB に貼付）。既存3年の出力は不変。
探索: tools/find_golden_seeds_v0.py（種1〜25000×4年）。

## 台本A: seed=1・通常4年
- 3年目: 敗者復活戦に回る（準決勝で落ち week47 の revival 分岐）・roundsPassed=4
- 4年目: 前年到達>=3 で gpSeeded=true（1回戦免除）
## 台本B: seed=424243・1年目通常 → 2年目 seedFinal+ライン-999 → 3年目 seedFinal+ライン999
- 2年目: 王者シード（予選免除・決勝直行）→ 優勝して即年終了（champion 分岐の状態も固定）
- 3年目: finalLineOverride=999（決勝で落ちる）
- 注: ボットは25000種×4年でも自然優勝せず、王者シードは「優勝の翌年」を自然には再現できない。seedFinal を台本で指定する形（Swift 側 runYear の引数と同じ）。

結果: Swift と Python は全行一致（不一致なし）。swift test 333 件 green、check_golden_sync 3つとも ✅。
