# GameCore 4ファイル点検（2026-11-16・読むだけ・コード未変更）

対象：GameCore/Sources/GameCore/ の Allocation.swift・Career.swift・ChoiceEventEffect.swift・JudgeTalk.swift。正典＝tools/balance_sim.py（projected_gain / pour_step / recommended_plan / _affordable_raw / _rank_cost_multiplier）・tools/sim_career.py（run_career / _ev_add / _app_apply）。

## §1 要約
- 高0件・中0件・低3件・要確認1件。Python 正典との式の食い違いは、既定の設定では無し（定数・演算順・タイブレークとも一致）。
- 一番重いのは Allocation の「growthDecayD が 0 のときの Swift と Python の扱いの違い」（低・設定が 0 のときだけ）。
- 乱数：4ファイルとも RandomSource を呼ばない（JudgeTalk は salt のハッシュのみ）。消費順が条件で変わる所は無し。

## §2 指摘
### 2-1 growthDecayD=0 の扱いが Swift と Python で違う（低・確信 中）
- 場所：Allocation.swift:59（projectedGain）・GameEngine.swift:28（add）／正典 balance_sim.py:210・272（`if GROWTH_DECAY_D:`）
- 起きる条件：config.growthDecayD = 0 にしたとき（既定 120 では起きない）。Python は 0 を「逓減なし」と読む（真偽判定）。Swift は `if let d`（nil だけが「なし」）なので `s[a] / 0` ＝ inf/NaN になり、伸びが 0 か NaN になる。
- 影響：sim で D=0 を「無効」の意味で使うと Swift と結果が分かれる。現状どちらの経路にも 0 を入れる所は無い（grep で growthDecayD の代入は既定値の 120 のみ）。
- 直し案：Swift 側を `if let d = config.growthDecayD, d > 0` にする（add と projectedGain の2箇所を同時に）。規律A：式の変更なので tools/balance_sim.py との同期・golden 確認が要る（既定値では結果不変のはず）。

### 2-2 イベント効果 .compat が config.compatGrows を見ない（低・確信 高）
- 場所：ChoiceEventEffect.swift:30 ／正典 sim_career.py:306（`if B.COMPAT_GROWS:`）
- 起きる条件：compatGrows=false の設定のとき。Python の _ev_add は相性を動かさないが、Swift の applyEventEffect は clamp して動かす。GameEngine.add(.コンビ相性) は compatGrows を見ている（GameEngine.swift:44）ので、イベント経路だけ抜けている。
- 影響：既定は true なので実機・golden とも不変。false にする実験（sim）とアプリで差が出る。
- 直し案：`.compat` の分岐を `if config.compatGrows` で囲う。規律A：sim と同期済みの挙動に合わせる変更で、既定値では不変。

### 2-3 GameCareer.runCareer が years < 1 で落ちる（低・確信 高）
- 場所：Career.swift:116 `for year in 1...years`
- 起きる条件：years が 0 以下（Swift の閉区間は下限 > 上限で実行時に停止）。呼び出し元は GameCore/Tests のみ（RunCareerTests ほか・years は 2〜）で、ManzaiGame/Sources からは呼ばれていない＝実機では起きない。
- 直し案：`guard years >= 1 else { return nil }` か `stride`。

## §要確認
- Career.swift:runCareer には Python run_career が年頭に行う「ネタの年越し劣化（NETA_V2 の used_y・tired・buzz 減）」に当たる処理が無い（sim_career.py:1167〜1178）。runCareer はテスト専用で、アプリ本体は GameSession 経由なので影響は不明。年越しの劣化を GameSession／WeekRunner 側が担当しているなら問題なし。担当箇所の確認が要る（golden は NETA_V2 を使わないはずだが未確認）。

## §既知
- Allocation.swift recommendedPlan が、予算を使い切った後にメンタルを注がずに止まる件＝docs/code_review_1108d.md §3（画面は GameSession.recommendedAllocation が続きを拾う・止まるのは sim ボットと golden だけ）。重ねて書かない。
- ネタ名・コンビ名の {me} 等が Names.show で置換される件＝code_review_1108d.md（JudgeTalk の『{題}』に入るネタ名にも同じ経路が通る）。
- ChoiceEventEffect の全分岐 clamp・money のみ無制限＝code_review_1108d.md・code_review_unreviewed_1115_v0.md で確認済み。

## §3 見て問題なしの所
- Allocation：_rank_cost_multiplier・_affordable_raw・pour_step・recommended_plan・projected_gain と式・演算順・POUR_EPS（1e-9）・タイブレーク（Ability.allCases と ALL_ABILITIES が同順で、最小値は先勝ち）が一致。RANK_COST_BANDS の値（(15,0.70)…(90,3.20)・S=4.20）・レシピ表・allocationStep も一致。
- Allocation：affordableRaw は recipe が空なら 0（`?? 0`）。通貨の消費量と残高の丸め（b/(w·m)·w·m が b をわずかに超えうる）で残高が -1e-16 級になりうるが、ExpDisplay.value は `Int(raw*10+1e-6)` で 0 に丸まり、次回の affordableRaw は eps 以下で 0 を返す＝表示・進行に影響なし。
- Allocation：projectedGain と add の分岐（decay→予算→clamp）の順序・メンタルの予算除外が同一。pourStep は gain≤eps なら通貨も状態も動かさない。recommendedPlan のループは 10,000 回の上限と「gain 0 で break」で必ず止まる。
- Career：runCareer の終了判定（champion → 優勝年を返す／bankrupt・dissolved → nil）は WeekRunner が champion と bankrupt/dissolved を同時に立てない（WeekRunner.swift:184/315/463/468）ので Python（bankrupt/dissolved を先に判定）と同値。gpSeeded（prevStage>=3）も一致。YearOutcome の Codable は dissolved 欠落の古いセーブを decodeIfPresent で読める。runYear は yearDone でのみ state と rng を書き戻す（途中で抜ける経路なし）。
- ChoiceEventEffect：weakestSkillPlus は固定4要素の min（同値は先勝ち＝Python _app_weak4 と同順）、weakerSenseIdeaPlus は `<=` でセンス優先（Python と同じ）。growthCeiling は budget が nil なら no-op・下限 0。rift は nil を 0 として加算し 0..100 に clamp（nil のまま負を足しても 0 の非 nil になるだけで無害）。凍結・ブースト・拘束は max で長い方を残す。
- JudgeTalk：mix は `&+`/`&*` の剰余演算で桁あふれしない・負の salt も bitPattern で安全・結果は非負。`list[mix % count]` は空配列を事前に `!list.isEmpty`／`guard` で除外。fill は slot を先に置換し、ネタ名は最後に差し込むので、ネタ名に「{入り}」等が入っても再展開されない。pick は {題} 行を除いて空になれば元の候補に戻す。bandLines は 7 名×4 帯（A〜D）すべて存在（score が負・100 超でも band は D／A に落ちる）。paperReview の margin 分岐は nil・-3〜0・-10〜-3 の隙間がすべて汎用プールに落ちる。judgeNames[mix % 7] は範囲内。
