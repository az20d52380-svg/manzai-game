# Fable投入レディネス v0 — 何が揃ったか／何が【仮】か／Fable後にMacがやること

- 日付: 2026-07-05 / 対象: Fableセッション（Q1ラストイヤーの奇跡＝主・Q2角の同時成立裁定＝副）を1セッションで裁く回。
- キックオフ即用は `docs/fable_kickoff_prompt_v2.md`。本書はその“地図”＝受け皿の実在/検証状況・仮の仮の所在・撃つ前の残チェックを1枚に。
- 数値は全て【仮】。確定フリップ（golden同期）はMacへ引き継ぐ前提。

---

## 0. 一行結論

**撃てる。** 受け皿の実験台3台が実在し、3台ともアンカー（0pt/OFFベースライン＝canonical §2）に一致、golden非干渉も構造保証＋実測で確認済み。blockerゼロ。残るは実験的近似（得意A/裏天井）が“仮の仮”である点の明示だけ（下記§3）で、これは裁定に but-clause として書けば足り、投入を妨げない。

---

## 1. 何が揃ったか（受け皿3台の実在と検証状況）

いずれも `tools/` 配下・experiment-only・`exp_pity3.py` の「グローバル/属性を一時上書き→finallyで完全復元」流儀に準拠。

| 台 | 用途 | 実装の要点 | アンカー実測（0pt/OFF・n=800） | 判定 |
|---|---|---|---|---|
| `tools/exp_lastyear.py` | Q1 | 最終年run_year直前の `s._yg−X` レバー＋**停滞層(9年目終了ever_final==False)の最終年“単体”分離集計(st_n/st_reached/st_won)**＋10年目残予算診断 | のんびり改 22.9%/0.38%・分散 41.4%/2.62%・G3 X=0=62.1% | 3アンカー全一致 |
| `tools/exp_corner.py` | Q2 | 30pt×SSR(cap24)×裏天井(MODE C)×得意A×絆 の5レバー積み上げスキャン。得意Aは `exp_talent_ability.apply(1.20)`、絆は `compat_start` 底上げ(BOND_COMPAT_START=8)で近似 | のんびり改 22.9%/0.38%・分散 41.4%/2.62% | 一致（ノイズ内） |
| `tools/exp_talent_ability.py` | 得意A単体 | `do_training` をラップし演技系4能力(sense/idea/expr/chara)のadd量のみ×1.20。mental/compat/stamina/fameへの漏れゼロ | のんびり 23.2%→24.8%(優勝Δ0)・分散 40.8%→39.3%(優勝Δ0) | 漏れゼロ実測・角壊れず上バウンド側から実証 |

canonical §2 基準値（n=600-800・ノイズ内一致でOK）: のんびり改(PCasual2) 優勝≈0.3%/到達≈23.1%、やり込み(PSpread) 優勝≈2.7%/到達≈41.5%、30ptやり込み優勝≈62.1%（到達≈98.9%）。

### golden非干渉（構造保証＋実測）
- `gen_golden.py` の import は `import balance_sim as B` / `import sim_career as C` の2つのみ（実測grep）＝`exp_*.py` を一切importせず、別プロセス実行で構造隔離。
- `cd tools && python3 gen_golden.py`（exit=0・50データ行）を2回実行→diff空（決定的）。生成50行をcommitted Swift golden（`GameCore/Tests/GameCoreTests/CareerGoldenTests.swift`）とソートdiff→完全一致。先頭行も一致。
- 保護ファイルの `git diff --stat`（`sim_career.py`/`gen_golden.py`/`balance_sim.py`/`canon_v2.py`）＝空（クリーン）。
- 3台とも実行後にグローバル状態（BURST_P/COMPAT_CAP/CAP_CURVE/EVENTS_ON/_gp_perform/do_training/add/YEAR_GROWTH_CAP/_yg）が既定値へ復元されることを実測確認。
- ラストイヤーの `s._yg−X` は draw を消費しない＝乱数消費順不変＝Mac本実装時の規律A（draw回数不変）を最初から満たす形。

### 既に回っている実測（Fableの出発点・全て【仮】）
- **Q1**: 停滞層はプレイ型で非対称。のんびり改は残予算+5.78を使い残し→X=0〜4で停滞層(n=593)最終年 到達15.5%/優勝0.34%が不動（奇跡が起きない）。分散型は残予算+2.40を使い切り→停滞層(n=506)最終年 到達30.8%→64.2%・優勝2.17%→13.24%（X=0→4単調上昇）。ただし**G3が無条件適用で62.1%→75.5%(+13pt)漏れる**＝停滞層(ever_final==False)ゲートで消せるのが最大の設計判断点。
- **Q2**: 火力はほぼ全て 30pt×SSR に集中（分散 41.4%/2.62%→60.88%）、後段3レバーは予算・相性上限が張り付き加算ゼロ＝~60%で飽和。角セル 分散 優勝60.75%/到達99.0%（<90%＝必勝化せず）。得意A単体は予算クランプに吸われ角内で冗長、絆はプレイ型と上限力学に完全依存で最も仮。

---

## 2. Fableの仕事（台を作るのでなく回して裁く）

- Q1（重心80%）: 残予算診断→停滞層分離→用量反応（**停滞層ゲート有/無の弁別**）→裏天井合成→必勝化回避の言語化。「のんびり改では奇跡が構造的に起きない非対称」を設計思想として肯定するか別出口を用意するかの裁定が隠れた核心。
- Q2（重心20%）: exp_corner既測を再測で確証し、規範(i)0pt不変・(ii)角<90%・(iii)加算的(プラトー)を判定。角スコープ補正の要否と方向を裁定。
- 出力2枚: Q1→`docs/lastyear_calibration_v0.md`、Q2→`docs/corner_arbitration_v0.md`（新設）。詳細は `fable_kickoff_prompt_v2.md`「出力の形」。

---

## 3. 何が【仮】か（特にQ2角裁定の“仮の仮”）

すべての数値が【仮】だが、Q2は近似の階層が一段深いので明記する。

1. **得意A（方式A）はラッパ近似＝仮の仮。** `do_training` をラップし演技系4能力のadd量を×1.20する実験フックで、run_year本体には未配線。Macが本実装（正典側で稽古効率+%を配線）するまで正典ではない。generous版（演技系4能力すべて×1.20）で「最悪でも角が壊れないか」をbracketしている＝上バウンド測定。
2. **裏天井は BURST_P 一時上書き＋`_gp_perform` ラップの近似＝仮の仮。** MODE C（準決以下のみBURST_P上書き・決勝本番は素・初到達ever_finalで恒久解除）を式どおり再現しているが、これも Mac が run_year へ本実装（`pity_calibration §5-1`・乱数消費順不変で）するまで正典ではない。
3. **絆は角の中で最も機構が薄い＝最も仮。** confirmed hook が「compatが直接スコアに乗る(balance_sim.py:190 `score=jitsuryoku+compat+roll+pen`)」しかないため、絆ボーナス≒追加compatを `compat_start` 底上げ（BOND_COMPAT_START=8【仮】）で近似。この近似の帰結として値がプレイ型と上限力学に完全依存する（compat稽古する分散では上限24に飲まれ寄与≒0・compat稽古しないのんびりでは決勝まで生存し+4.62）。機構自体の要否含めFable/オーナー判断。
4. **Q1のG3漏れ対策（停滞層ゲート）は設計上の示唆であって未確定。** ゲート付きレバーでG3漏れが消えるかはFableが実測で弁別する。
5. **バランス数値の正本は canonical/GameConfig。** 本書・exp_*の数値は確定フリップ前の【仮】。

→ **Q2角裁定は「この実験的近似の上での方向確定」であり、Mac本実装後に4.8が正典ハーネスで角セルを再測する前提**。Fableはこの but-clause を裁定に必ず刻む（撃ち切らず方向だけ確定）。

---

## 4. 撃つ前の残チェック

blockerはゼロ。以下はminor（投入を妨げないが、Mac引き継ぎ前に処理が望ましい）。

- [minor] `exp_corner.py` の飽和検査拡張（pair_w/tail/sat）が未コミットの作業ツリー変更（`git status ' M tools/exp_corner.py'`）。レバー機構は不変・golden非干渉だが、Mac引き継ぎ前にコミット要。
- [minor] `exp_lastyear.py` の per-scan finally が `C._gp_perform`/`B.BURST_P` しか復元せず `B.COMPAT_CAP`/`V(CAP_CURVE/EVENTS_ON)` を復元しない（次scanのapply/代入で上書きされ、最終的にmain()のfinallyで復旧するため結果汚染もプロセス終了後汚染も無い＝実測クリーン）。exp_corner（scan毎に完全復元）と比べ非対称なだけ。単体import利用時のみ復元漏れになり得る。
- [確認済・処置不要] golden完全不変・3台アンカー一致・得意Aのmental等漏れゼロ・停滞層分離集計・裏天井MODE C・`_yg`レバーいずれも正しく実装・finally復元も実効的に完全。

→ **上記minor 2件は「回して裁く」には無関係（結果は実測クリーン）。撃てる。** Mac引き継ぎのタイミングで exp_corner をコミットし、必要なら exp_lastyear の per-scan 復元を exp_corner と対称化する。

---

## 5. Fable後にMacがやること（申し送り）

### Q1 ラストイヤー
- **Mac**: run_year へ最終年緩和を本実装（最終年のみ `s._yg` を−X相当で伸びしろ+X・**停滞層ゲート(ever_final==False)付き**・**乱数消費順を変えない＝draw回数不変が必須**・規律A／`gen_golden` diff空＋`swift test` green を1コミット）。
- **4.8**: 正典ハーネスで再測し canonical / red_team §1 の該当行を確定値へ。
- **オーナー**: 緩和幅Xの体感ダイヤル（“最後の一花”の強弱）と発動年の非明示演出（谷口「今年が最後や、まだ伸びるぞ」等・finals/dialogue側TODO・非バランス）。

### Q2 角
- **4.8**: 得意A（方式A・稽古効率+%）と裏天井を run_year へ本実装した**後に**、角セル（30pt×SSR24×裏天井×得意A×絆 同時ON）を正典ハーネスで再測。合格【仮】: SSR角<90%・0pt初回帯不変・加算的（プラトー）。canonical更新。
- **4.8**: 必勝化の兆しが出たら `fable_findings` Q5の(a)能力別合計効率キャップ（加算合成・乗算禁止）/(b)SSR角犠牲 のどちらを機構化するか、Fable裁定の方向に沿って実装。
- **cli-mac**: 角セルを固定シード群として標準スキャンに常設（以後のレバー変更で必ず角を踏む回帰）。

### 共通
- 触っていない: `sim_career.run_year`本体・`gen_golden.py`・`balance_sim.py`成長中核・`CAP_CURVE`本体・`canon_v2`数値・golden・committed Swift golden（禁止事項遵守）。
- 新規/変更: `tools/exp_lastyear.py`（新規）・`tools/exp_corner.py`（新規・飽和検査拡張は未コミット）・`tools/exp_talent_ability.py`（新規）・本書・`docs/fable_kickoff_prompt_v2.md`。
