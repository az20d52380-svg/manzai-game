# テスト側の式の写し 洗い出し（2026-11-15・読むだけ・コード未変更）

**要点3行**
1. golden 系（FeatureGolden・Golden・CareerGolden・WeekRunnerGolden）に、体調ダウンと同じ型の「期待値と比べる側が式を写している」穴は**残っていない**（op 全種が本体関数を呼ぶ。injury_prob は 2f506d9cc で解消済）。
2. 非 golden の Python 同期系に、config 部品で式を書き写している所が**5件**（実質の穴は、段ごと検証の GPRewardTests の1件）。数値リテラルで式を固定している所（SkillTests 等）は「値の釘打ち」で別扱い。
3. golden 経路の外に1件：FeatureGolden の neta_grow が「稽古名→applyNetaRevise/Live の呼び分け・gain」をテスト側で書き直している（本物の呼び分けは App 層 GameSession.swift:850-871）。直すには純粋部分を GameCore へ寄せる必要あり。

節構成：§1 写しの一覧／§2 問題なし（op 種類ごと）／§3 直し方の推奨順

## §1 写しの一覧
| # | テスト側（ファイル:行） | 写している式 | 本体の同じ計算 | 本体関数を呼ぶ形に直せるか／順序リスク | 価値 |
|---|---|---|---|---|---|
| 1 | GameCore/Tests/GameCoreTests/GPRewardTests.swift:70-72 `expPerCurrency`、pw は :97 :101 :106 | 大会経験点＝`pw*tourneyExpK*weight*tourneyExpUnit*tourneyExpSplit*expSupplyScale`、pw＝`(1+RoundStep*i)*(passed ? 1 : Loss)`／`Revival`／`Final` | GameEngine.swift:98-103 `creditTourneyExp`（`tot=pw*K*weight`→`tot*unit*split`→creditCurrency で供給スケール）、WeekRunner.swift:227・260・286・304 の pw 組み立て（4か所に同じ `X*(passed ? 1.0 : Loss)` が散在） | 可。(a) `pw*K*weight*unit*split` を `tourneyExpPerCurrency(pw:weight:config:)` に出す。(b) 各段の pw を共有関数に出し WeekRunner とテストが同じ物を呼ぶ。掛け順（K→weight→unit→split→scale）を保てば Double 結果は不変。乱数は引かない | 中（段ごと検証はこのテストだけ。年 golden が集計で守る） |
| 2 | CoverageGapTests.swift:128-129 | 知名度の「その他の伸び」＝`fame0+amt*fameOtherMult*(d*d)`、`d=max(0,1-fame/fameOtherCap)` | GameEngine.swift:58-59（`add(.知名度…)` 内） | 可。`fameOtherGain(amount:fame:config:)` を出し共有。`amt*mult*(d*d)` の順を維持。年 golden のオファー慣れ台本が fame を比べるので集計では守られている | 低 |
| 3 | CoverageWTests.swift:120（RiftTests.swift:12・:102 は数値リテラル 0.5*15/20） | すれ違い増分＝`riftGain*(compatCap-compat)/compatCap` | GameEngine.swift:299 | 可。`riftGainAmount(compat:config:)` を出す。FeatureGolden の rift op（本体呼び）が既に守っている | 低 |
| 4 | CoverageXTests.swift:65 | 実力＝`センス*wSense+発想*wIdea+表現*wExpr+華*wChara` | GameEngine.swift:78-81 `jitsuryoku` | 同形の写しだが目的は「メンタルを無視する」確認。GoldenTests:82 が Python 定数で突き合わせ済。直す価値ほぼ無し | 無 |
| 5 | CoverageXTests.swift:104-105・EdgeBranchTests.swift:130・ChoiceEventTests.swift:236・BoundaryGapTests.swift:38 | 借金係数×供給スケール／スタジオ+レコーダー加算×スケール／`netaReviseGain*netaBoostMult`／`allocationStep*weight*1.15` | GameEngine.swift:115-120（稽古）・WeekRunner.swift:534-538（applyNetaRevise）・Allocation.swift（pourStep） | 「効果が掛かる」ことの局所確認で部品の一部を書いている程度。共有関数化の旨味小。放置可 | 低 |
| 6 | FeatureGoldenTests.swift testNetaGrowGolden（約178-190行。本物は ManzaiGame/Sources/GameSession.swift:850-871 applyNetaWork） | 稽古名→`ネタ見せ会/フリーライブ→applyNetaLive(hard:)`・`ネタ作り→applyNetaRevise()`・`喫茶店/ファミレス→applyNetaRevise(gain: netaPlaceGain[t])` の呼び分け | GameSession.applyNetaWork（GameCore の外） | 呼び分けを GameCore へ移し、テストと GameSession が同じ関数を呼ぶ。App 層の副作用（writeTargetID・selectedNetaID・おろし台詞）が絡むので、純粋部分（gain の選択と hard 判定）だけ出すのが現実的。乱数は引かない | 中（今は GameSession の gain/hard を取り違えても golden が通る） |

補足（写しではないが同型の注意）
- SkillTests.swift:35・:50 は `1.1`／`0.95` をリテラルで書く＝Skill.fameMult／livingMult を呼ばない。Python 側定数の釘打ちなら正しい（本体の定数を変えると落ちて気づける）。「定数の二重管理」でオーナー判断。
- GoldenPolicy／InjuryPolicy.pattern は Python の PATTERN の写しだが、台本そのものなので正しい（gen 側と手で同期）。

## §2 問題なし（本体関数を呼んでいる op）
FeatureGoldenTests（75-120行付近）の op：
- set → テスト側 `apply` で状態を直接書く（式なし）
- rest → GameEngine.applyRest／buy → GameEngine.buy／learn → GameEngine.learnSkill／week_end → GameEngine.applyWeekEnd／living_due → GameEngine.livingCostDue／new_year → GameEngine.resetYearlyItems／fame → GameEngine.add／rift → GameEngine.applyRiftWeekEnd／injury_prob → GameEngine.injuryProbability（2f506d9cc で共有済）
- neta_bonus → GameEngine.netaScoreBonus／extra offers → GameEngine.extraOffers／fatigue → GameEngine.applyOffer／event_effects → ChoiceEventTable.choices＋applyEventEffect／injury 抽選 → WeekRunner 本体を週ごとに駆動
- GoldenTests：applyTraining／applyJob／applyRest／pourRecommended／applyWeekEnd／blurWidth／jitsuryoku を呼ぶ（式の写しなし）
- CareerGolden／WeekRunnerGolden：GameCareer.runYear／WeekRunner 本体を駆動（比べるのは Python の固定値のみ）
- 期待値側の変換は `snap`（状態の取り出し）のみ。計算なし。

## §3 直し方の推奨順
1. **#6**（neta_grow の呼び分けを GameCore へ）：golden が App 層の取り違えを見逃す唯一の経路。純粋部分（稽古→「改稿(gain)／披露(hard)」の対応）を GameCore に出し、GameSession とテストが同じ関数を呼ぶ。
2. **#1**（大会経験点の係数と各段の pw）：`creditTourneyExp` の掛け順を保ったまま関数に出し、WeekRunner 4か所の `X*(passed ? 1.0 : Loss)` も共有に。gen_golden 差分0を確認。
3. **#2・#3**：fame その他の伸び・rift 増分を小関数化（golden が集計で守っているので急がない）。
4. #4・#5 は放置でよい。SkillTests のリテラルは Skill.* 定数参照に変えるか、「Python 定数の釘打ち」とコメントで明記するかをオーナー判断に。

## 追記（11/15 定期・親）
- #6 を直した（792a8c027・GameConfig.netaWork を共有）。
- #1〜#3 は直さない：GPRewardTests などは本体の出力を「独立に計算した期待値」と比べる単体テスト（オラクル）で、本体の関数を呼ぶ形にすると自分自身と比べることになり意味が薄れる。Python との一致は golden（本体の関数を呼ぶ op）が守っている。#6 と体調ダウン（496）は golden 側の写しだったので直した＝型が違う。
