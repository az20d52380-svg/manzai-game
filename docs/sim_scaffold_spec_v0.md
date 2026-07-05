# sim受け皿 実装スペック v0 — Fable較正の前にCLI/Macが作る下ごしらえ

- 日付: 2026-07-05
- 位置づけ: `fable_plan_v0.md` §3 の「Fable前の下ごしらえ」を、**実コードをRead/Grepして実在の関数名・行番号で書いた実装可能スペック**（ultracode監査＋敵対的レビューで裏取り済み）。CLI/Macセッションがそのまま着手できる形。数値は全て【仮】。
- **前提（オーナー先決・`fable_plan §4`）**: T2の成長期限解除値（25年 vs 実質恒久）を配線前に確定。※現状 `sim_meta` の MAX_YEARS=25 と `canon_v2` 定数25 が数値一致するため現horizon(≤25年)では挙動同一＝実質moot。25で踏襲するのが既定案。
- **開発規律A厳守**: golden-touching（T1/T2）は「①`tools/*.py`→②GameCore→③`gen_golden.py`でgolden再生成→④`swift test` green」を1コミットで揃える。**gen_golden標準出力のbefore/after diffが完全に空（バイト一致）**をゲートにし、**Swift側の期待値リテラルは絶対に手書きしない**。
- 行番号は2026-07-05時点。着手時に該当関数を再確認すること。

---

## 依存順（重要）

- **T1 → T2 → T3 は直列必須**（T1でrun_yearを単一ソース化してからT2で予算式に特権を入れないと、`gen_golden.year_budget`という第2の同期先が残り正典二重化が再発）。
- **T2を state方式（`s._champ`）にすると T3の3実験は無改造で自動継承**。
- **T4・T5 は独立**（いつでも可・並行可）。
- 担当: golden-touching（T1/T2）＝**cli-mac**（swift test必須）。experiment-only（T3/T4/T5）＝**4.8-cloud**（Python完走で検証可・swift不要）。

---

## T1: gen_golden/sim_career の run_year 二重実装を単一正典化（concerns#51）〔touches-golden・cli-mac〕

**触る所**: `tools/sim_career.py` run_year(350-526)に週次ログフック＋モジュール変数(line100付近)。`tools/gen_golden.py` 自前run_year(59-152)を削除しC.run_yearへ委譲・year_budget(55-57)削除・GoldenPolicy新設・main(162-184)調整。

**手順**:
1. `sim_career.py` line100付近に `RUN_WEEK_LOG = None`。
2. run_yearの週ループ末尾（line524 `s.min_money = min(...)` の直後）に:
   `if RUN_WEEK_LOG is not None: RUN_WEEK_LOG.append((year, week, (s.money, s.stamina, s.fame, s.sense, s.idea, s.expr, s.chara, s.mental, s.compat)))`
   （旧gen_goldenのlog placement=生活費処理後と一致させる）。
3. `gen_golden.py` に `GoldenPolicy(B.Policy)` を定義: `choose` は offer!=None なら `('offer',None)`、それ以外 `PATTERN[(week-1)%len(PATTERN)]` を返すだけ（gate/injury/redirectは掛けない＝C.run_year側が処理）。`transport` は常に `B.BUS`。`_GOLDEN_POL = GoldenPolicy()`。
4. `gen_golden.run_year` を薄いラッパに置換:
   `C.RUN_WEEK_LOG = log; won, stage, _fin = C.run_year(_GOLDEN_POL, s, year, rng, gp_seed=gp_seed); C.RUN_WEEK_LOG = None; assert not getattr(s,'_bankrupt',False); return won, stage`
   （2-tuple維持でmain line172 `champion, prev_stage =` 不変）。
5. year_budget(55-57)削除（C.run_yearが予算計算）。snapshot/swift_rowはmainのまま流用。

**等価性の前提（この条件下で乱数消費順が旧実装と一致）**: `EVENTS_ON/NETA_ON/AUDIENCE_SPLIT/UPSET_ON/BOREDOM_ON=全False`、`INJURY_ON=True`、`STAMINA_GATE=20`、**`INJURY_ABILITY=0.0`**（←重要: 真値化すると `sim_career:481-482` の `rng.choice` が余分に1draw消費しgolden破壊。レビュー指摘）。canonical §3項6が既に「run_year⇔gen_golden複製ループの3年bit一致をクロス検証済み」と明記＝この委譲で不変が保てる裏付け。

**検証**: 変更前 `cd tools && python3 gen_golden.py > /tmp/golden_before.txt`。変更後 `python3 gen_golden.py > /tmp/golden_after.txt`。`diff` が**完全に空**を確認（空でなければGoldenPolicyのoffer/transport/gate順を修正・Swiftリテラルは触らない）。空確認後 `cd GameCore && swift test`（CareerGolden/WeekRunnerGolden）green。1コミット完結。

---

## T2: ~~王者の特権を run_year へ配線~~ → **不要（2026-07-05・王者編廃止・owner⑥）**〔削除〕
> 王者編廃止により本タスクは実施しない。canon_v2.CHAMPION_GROWTH_END(dead)・sim_meta の王者編ロジックは将来のコード清掃で除去（4.8・golden非影響部分）。以下は履歴。

**先決**: 解除値25 vs 恒久のオーナーフォーク（`fable_plan §4`）。既定案=25（`sim_meta` MAX_YEARS=25 と一致で現horizon挙動不変）。

**触る所**: `sim_career.py` 定数追加(GROWTH_END_YEAR line122隣)・予算計算(358-360)・優勝return(455)。`sim_meta.py` 重複行(89,120)。`canon_v2.py` dead constant(16)。

**手順**:
1. `sim_career.py` line122付近に `CHAMPION_GROWTH_END = 25  # 初優勝後は成長期限解除(canonical §2-B)`。
2. 予算計算(358-360)を `end = CHAMPION_GROWTH_END if getattr(s, '_champ', False) else GROWTH_END_YEAR` を先に置き、`for k in range(1, min(year, GROWTH_END_YEAR) + 1)` を `min(year, end)` に変更。
3. 優勝early-return(line455 `return True, gp_stage, True`)の**直前**に `s._champ = True`。
4. `sim_meta.py` line120 `C.GROWTH_END_YEAR = MAX_YEARS` を削除、line89 `C.GROWTH_END_YEAR = 15`（毎キャリアglobal reset）も削除（state方式でグローバル汚染しない）。
5. `canon_v2.py` line16 を `CHAMPION_GROWTH_END = C.CHAMPION_GROWTH_END`（単一ソース参照）へ。

注: `s._champ` は `C.new_state()`→新規`B.S()`で毎回未設定=False＝キャリア間リークなし。

**golden不変の理由**: golden3年は year(1-3) < GROWTH_END_YEAR(15) かつ golden内で優勝しない→`s._champ`常にFalse→`min(year,end)=year`でend値非依存→bit不変（理論保証）。ただし必ずgen_golden diff空＋swift test greenで実証。

**検証**: T1同様 gen_golden before/after diff空 → `swift test` green。加えて `python3 sim_meta.py 200` 完走・`python3 canon_v2.py` import壊れず。T1と同一コミット可。

---

## T3: ~~dynasty再測を特権解除ありへ~~ → **不要（2026-07-05・王者編廃止・owner⑥）**〔削除〕
> 連覇マトリクスは設計対象外に。以下は履歴。

T2をstate方式(`s._champ`)にしたため、3関数は各キャリア先頭で`C.new_state`を作りsを年跨ぎ保持（exp_renpa:33/exp_dynasty_matrix:27/exp_v2_meta:54）→優勝年にrun_yearが`s._champ=True`をセット→翌年以降の予算endが自動でCHAMPION_GROWTH_ENDに伸びる＝**特権が自動継承・コード必須変更なし**。

**手順**: (a)各run_dynasty直上に「初優勝で成長期限解除(run_year s._champ)を継承」コメント1行、(b)`s._champ`を明示リセットしていないことを確認、(c)返り咲き年(defending=False, titles>0)でも効くことを確認（`s._champ`は一度Trueで維持）。(d)docstring等にハードコードされた旧10連覇%があれば正典vN移行バナー付きで更新。

**検証**: `python3 exp_renpa.py 500` / `exp_dynasty_matrix.py 500` / `exp_v2_meta.py 300` 完走。特権前後で10連覇率が上振れすることを記録。**この結果がcanonical §2-Bマトリクスの再測値**（◐未検証を✅へ更新する根拠）。

---

## T4: exp_pity.py 新設（裏天井の測定台）〔experiment-only・4.8-cloud〕

**新規** `tools/exp_pity.py`。依存: balance_sim(BURST_P:177, perform:180-191)・sim_career(run_yearの第3戻り値finalist)。

**手順**: (1)ヘッダに「数値は全て【仮】」。(2)`PITY_ON=True`, `PITY_DRY_TH=3`, `PITY_BURST_P=0.30`, `BASE_BURST_P=B.BURST_P`。(3)自作ループ: `rng=random.Random(seed); s=C.new_state(init,compat); dry=0`、各年**開始前**に `B.BURST_P = PITY_BURST_P if (PITY_ON and dry>=PITY_DRY_TH) else BASE_BURST_P`（performは呼び出し時にB.BURST_Pを読む=balance_sim:183で上書きが効く）。(4)`won, stage, finalist = C.run_year(pol, s, year, rng, gp_seed=(prev_stage>=3))`、finalistなら`dry=0`else`dry+=1`、wonで初優勝年記録し勇退。(5)main で PITY on/off 2条件を比較出力（初優勝年中央値・優勝なし率・平均発動回数）。(6)**finallyで`B.BURST_P = BASE_BURST_P`を必ず復元**。

注: これは全perform（予選含む）にBURST_Pが乗るグローバル上書き。決勝のみに限定したい場合はrun_yearにフック追加（別タスク）。裏天井の効果式（2案統合）は**オーナー先決**（`fable_plan §4`）＝この台は「連続無決勝で率を上げる」骨だけ提供し、式の最終形は決定後に差す。

**検証**: `python3 exp_pity.py 500` 完走・on/offで分布差。直後 `python3 gen_golden.py | head` でBURST_Pが0.10に戻っていること（ヘッダ表示）を確認。golden非対象。

---

## T5: exp_v2_meta の SSR cap 30→24 整合〔experiment-only・4.8-cloud〕

**触る所**: `tools/exp_v2_meta.py` TIERS(24-27)のSSR行(line26)。

**手順**: line26 `('SSR相方(20→30)', 30, dict(...))` を `('SSR相方(20→24)', 24, dict(...))` に（ラベルとccap両方）。根拠: 正典v2のSSR=相性上限+4=24（`sim_meta.py:34 ('SSR',20.0,24.0)`と一致）。

**golden非波及の確認（レビュー裏取り済）**: gen_goldenはexp_v2_metaをimportも実行もせず`B.COMPAT_CAP`を書き換えない。COMPAT_CAP既定=20(balance_sim:27)、run_yearがCOMPAT_CAPを読むのはB.addのcompat clamp(111-113)のみで、goldenのcompatは初期5→上限20クランプで24/30に到達不能。TIERS変更はexp_v2_meta内career_scan/dynasty_scanがローカルにset/restoreする範囲のみ＝**experiment-only（確認済）**。

**検証**: `python3 exp_v2_meta.py 300` 完走・SSR行が(20→24)表示。concerns #34（SSR分散0pt優勝66.67%）が解消することを記録。

**範囲外の残課題**: `exp_dynasty_matrix.py:22`・`exp_renpa.py:26` もSSR cap=30のまま（別タスクで同一整合・experiment-only）。

---

## T6: exp_archetype.py 新設（得意能力ボーナス方式Aのsideways測定台）〔touches-golden・cli-mac〕

**目的**: オーナー⑤で確定した方式A（得意能力の稽古効率+%・対象=演技系4能力）が sideways（全アーキタイプが総合力等価）を保つかを実測し、`enabled=on` フリップの合否を出す（`character_archetypes §9-B`）。

**触る所**: `balance_sim.py` do_training(140-152)に per-stat 稽古効率倍率フック（`s._train_mult` dict・既定空=倍率1.0）。`sim_career.py` はフック透過。新規 `tools/exp_archetype.py`。**mental/staminaには倍率を掛けない**（予算プール外＝方式A対象外・§9安全判定）。

**測定セル（§9-B・6つ全部を合格条件に）**: (1)能力別の優勝限界寄与 (2)アーキタイプ別優勝率スプレッド（**メンタル/体力primary型も含む**・canonical §2帯内か） (3)1年MVP予算拘束 (4)トロフィー30pt角 (5)合成最悪ケース（軸整合seed＋大会直前投下・加算合成キャップ下） (6)難度較正（3ポリシー）が動かないか。

**goldenImpact**: `s._train_mult` を既定空（倍率1.0）にすれば do_training の乗算は恒等＝**gen_goldenは倍率を注入しないのでbit不変**。ただしdo_trainingを触るので **規律A（gen_golden before/after diff空＋swift test green）を1コミットで**。倍率を実際に効かせるのは exp_archetype 内のみ（enabled=off維持）。

**検証**: `python3 exp_archetype.py 1000` で6セルを出力。全型がcanonical §2目標帯内・30pt/軸整合最悪ケースで頂部が跳ねない・難度帯不変、を満たせば on 候補。1つでも外れたら対象能力限定/寄与均し/飽和連動/加算キャップの条件を足して再測。

---

## Fableに渡す生データ（下ごしらえの出口）

上記を強ボット（PSpread/PCasual2）＋十分シード数＋信頼区間で走らせ、**閾値表・連覇マトリクス・決勝初到達年ヒストグラム**に整形。Fableへは「dynasty×SSR×debuff×pityの帯が同時充足する解はあるか」の1構造判断だけを投げる（`fable_plan §2`）。STEP2/3・cap22〜24・K/PEN/DELTAグリッド・H3差分の**閾値探索は4.8**、最終選択はオーナー。
