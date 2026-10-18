# 候補ブランチ claude/q-candidate（2026-10-18・数値は全て【仮】）

claude/q-combined8s ＋ q106-skills 最新(cf387f1) ＋ 頂GP予選ライン−2。本体ブランチには未merge。

## 入っているもの
- q97 injury（体調ダウン）／q98 wintercup（寒梅漫才杯）／q103 items（アイテム）／q102 invites（誘い）
- q90 rooms（部屋・生活費=やりくり+家賃）／q96 offers（オファー）／q94 compat-rift（相性の溝）
- q106 skills（特技4つ：体が資本／愛され芸人／やりくり上手／相方思い。札の「覚えた」印の直し cf387f1 込み）
- 目視用 DEBUG フック（prep_check・DEBUG 内のみ）
- 【規律A】予選ライン−2：GP_ROUNDS 18/26/34/45/74→16/24/32/43/72、敗者復活 76→74（決勝80そのまま）。Python(sim_career.py)と GameCore(Calendar.swift) 同値。golden は不変（check_golden_sync OK）。根拠 docs/combined7_bands_v0.md 追記

## 帯（組B・n=1000・L0_T-）
| ボット | 今（7本なし）優勝/決勝/解散 | 候補（7本＋予選−2） |
|---|---|---|
| のんびり改 | 0.0 / 3.2 / 0.0 | 0.0 / 4.7 / 0.0 |
| ローテ | 0.3 / 18.3 / 0.0 | 0.4 / 18.8 / 0.0 |
| 必要充足 | 4.0 / 54.8 / 2.2 | 2.1 / 49.3 / 0.4 |
| やり込み | 5.6 / 54.1 / 12.9 | 4.8 / 55.0 / 6.0 |
（特技はボットが覚えないので combined7 の「7本・予選−2」行と一致を確認）

## 本体へ入れる手順
1. 本体ブランチ claude/manzai-slg-foundation-wprqlu で `git merge --no-ff origin/claude/q-candidate`
2. `cd GameCore && swift test`（180本緑）、`python3 tools/check_golden_sync.py`
3. アプリのテスト（xcodebuild build／ManzaiGame のテスト）

## 追記（親）：面白さの点検の数字（exp_fun_audit_v0・n=300・今／候補）
- 自由に選べる週・実質1択の週・同じ行動の連続は、ほぼ同じ（例 ローテ 自由27→26%・最長連続6.1→6.2週）。何も起きない最長はやや短く（ローテ 12.2→11.0週・やり込み 11.7→10.9週＝寒梅漫才杯と誘いの分）。
- 年ごとの伸びは同じ形（10年目の実力 ローテ 48.2→45.9）。
- 新しい仕組み（部屋・特技・誘いの行く/断る・オファーの断り方）は「人が選ぶ物」で、ボットはほとんど使わない＝この点検では効き目が出ない。手応えは実プレイで見る（候補を入れた後に実プレイ点検 v9）。
