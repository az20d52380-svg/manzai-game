# GameCore 小ファイル点検（2026-11-18・読み取りのみ）

対象：GameCore/Sources/GameCore/ の ChoiceEventEffect / Allocation / Career / Item / Skill / GameState / RandomSource。正典＝tools/balance_sim.py・sim_career.py。

## 要点3行
- 新しい致命的な不具合は無し（高0）。式・乱数・golden に関わる食い違いも見つからず、Python 鏡像（pour_step / recommended_plan / _rank_cost_multiplier / apply_meta_start / buy_item / _ev_add）と Swift は同値だった。
- 新規は「特技の費用判定だけ Swift が 1e-9 甘い」「買えない品の分岐が死んでいる」「コメントの行番号が古い」など低〜要確認が中心。
- 既知の中（旧セーブで復号失敗する非Optional項目）はまだ未対応。出荷版が 10/06 以降ならスキップ可（save_compat_audit_1108_v0 の判断待ち）。

件数：高0 / 中1（既知） / 低6（既知3・新規3） / 要確認1

## 新規

### N1 低｜Skill.swift:46 と balance_sim.py:177（Swift と Python の食い違い）
- 何が起きるか：Swift の canLearn は `残高 >= 費用 - 1e-9`、Python の learn_skill は `残高 < 費用` で拒否（許容なし）。浮動小数の端数で残高が費用ちょうどより 1e-10 ほど低いとき、Swift は覚えられて Python は覚えられない。覚えると残高が -1e-10 の負になる。実害は画面で「あと0.0000001」が出ない程度だが、sim と実機で判定が分かれる。
- 直し方：どちらかに揃える（Python に 1e-9 を足すのが安全。通貨が負にならないよう引いた後 max(0, ...) も可）。
- 規律A：ボット（golden台本）は特技を覚えない＝golden 不変。sim の特技ボットの結果が僅かに変わり得るので sim 側は再測定が要る。式の変更ではない。

### N2 低｜Item.swift:60-72・Item.swift:3-4（死んだ分岐・コメント）
- 何が起きるか：canBuy は `config.shopLineup.contains(item)` を先に要求する。shopLineup は 栄養ドリンク／回復ドリンク大／喉のケア用品／銭湯の回数券／新幹線回数券 の5品だけ（balance_sim.SHOP_LINEUP と同じ）。よって buy 内の 中古のICレコーダー／ネタ作家の勉強会／ボイトレ短期集中／稽古場の年契約 の分岐は今は到達しない。ファイル冒頭の「例外＝ICレコーダー1点」も、今は店に並ばないので実態と合わない。
- 直し方：消さずに「現在は店に出さない（将来用）」とコメントで明記する。
- 規律A：コメントのみ。

### N3 低｜GameState.swift:49-50 ほかのコメントの行番号
- 何が起きるか：「GameEngine.swift:145-158」「exp* 追加（上 30-38）」は、いまの行とずれている（exp* は 33-46 行）。読む人が迷う。
- 直し方：行番号を消して名前（perform / exp* の節）で指す。
- 規律A：コメントのみ。

### N4 要確認｜GameState.swift:137（頂点の経験点に上限なし）
- 何が起きるか：`metaStartExpTop * pow(P / 38, 8)`。コメントに「上限なし」とあり Python と同値だが、P が 38 を超えると急増する（P=76 で 300×256＝約7.7万点）。通常のプレイでは P≦38 想定なら問題ない。超えうる設計か確認したい。
- 直し方：超えない保証が無ければ上限を置く。置くなら Python 鏡像も同時に。
- 規律A：式の変更＝規律A（周回ボーナス）。golden は metaPoints=0 なので不変。

## 既知（重ねて書かない）

| 項目 | 場所 | 既知の出どころ |
|---|---|---|
| 中｜非Optionalの後付け項目（growthUsed／recoveryWeeks／bankrupt／netas／archivedNetas／nextNetaID／compatFreezeWeeks／netaBoostWeeks／preoccupiedWeeks／exp*）が旧セーブに無いと復号失敗。init(from:) 未実装 | GameState.swift:26-90 | save_compat_audit_1108_v0.md（表の GameState 行） |
| 低｜runCareer の `1...years` は years<1 でクラッシュ（テスト専用） | Career.swift:110 | code_review_core4_1116_v0.md |
| 低｜recommendedPlan は予算を使い切ると、メンタルが残っていても止まる（画面は GameSession 側が拾う） | Allocation.swift:131 | code_review_1108d.md §3 |
| 低｜.compat は COMPAT_GROWS 相当の設定を見ない（Python は見る） | ChoiceEventEffect.swift:30 | code_review_core4_1116_v0.md |

## 確認して問題なしだった所
- RandomSource：nextUniform は上位53bit÷2^53 で [0,1)。&+ / &* で桁あふれなし。Codable は state を保存。
- ChoiceEventEffect：全分岐が clamp 済み（money のみ無制限・Int 溢れは現実的でない）。.rift は nil を 0 扱いで加算するが、rift の nil/非nil を見て分岐する所は無く無害。weakest の同値は先勝ちで Python と同順。
- Allocation：rankCostMultiplier（昇順の帯・最終帯 S）、affordableRaw、pourStep、recommendedPlan は Python と同値。見える伸びが無い段は通貨を消費しない。
- Item：injuryProbability は呼び出し側（WeekRunner.swift:341）が `stamina < 閾値` を先に確認しているので負・1超えにならない（最大 0.25）。resetYearlyItems は銭湯の回数券を残す（持ち越し仕様どおり）。
- Career：YearOutcome の古いセーブ読み込み（bankrupt/dissolved の既定値）は decodeIfPresent で正しい。
