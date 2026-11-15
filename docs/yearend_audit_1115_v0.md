# 年末総決算の数字の出所の点検（11/15・読むだけ・コード不変）

対象：ManzaiGame/Sources/YearResultView.swift ／ GameSession（yearStartState・hasYearStart・yearHistory・totalPrize・log）。
既出の照合：candidate ブランチ（final-year-history-cand・yearly-goal-cand）、docs/decision_brief_2026-11-08.md、docs/AUTOPILOT.md（132・136・231・359）。

## §1 指摘（3件・高0／中0／低3）

### 1. 旧セーブ（yearStartState なし）で再開した年の末に、知名度の「↑+n」が年初との差ではなく全量になる　【低（見た目の数字違い）／確信度 中】
- 場所：YearResultView.swift:320（`delta: Int(s.fame.rounded()) - Int(session.yearStartState.fame.rounded())`）。等級の段（33行）とレーダー（222行）は `session.hasYearStart` で守られているが、ここだけ守られていない。GameSession.swift:284 は nil の時 `GameState(config: cfg)`（初期状態）を入れる。
- 手順：2年目以降で、yearStartState の無い旧セーブを読み込む → その年を最後まで遊ぶ → 年末総決算。
- 見えること／実際：知名度の札に「↑+（今の知名度−初期値）」＝今年の伸びでなく通算の知名度が出る。実際の今年の伸びは不明（年初値が無い）なので出さないのが正しい。
- 直し方：`delta: session.hasYearStart ? … : nil`（1行）。
- 既出：なし（A-5／code_review_2026-10-19c §2-3 は等級とレーダーの守りだけ）。

### 2. 同じ場合に、レーダー「年初と現在」が差のない図になるのに見出し・凡例は「年初」のまま　【低／確信度 高】
- 場所：YearResultView.swift:222（`base: hasYearStart ? yearStartState : s`）・:220 見出し・凡例 :225。
- 手順：1 と同じ。
- 見えること／実際：「年初」の点線と「現在」が完全に重なる（伸びがゼロに見える）。実際は伸びが不明。
- 直し方：`hasYearStart == false` の時は radarBlock を出さない（33行の gradeLadder と同じ条件）。
- 既出：なし。

### 3. 年1年目の旧セーブ（yearStartState なし）で、基準が「素の初期状態」になり、周回の点・女コンビ開始分の差が育ちに出る　【低／確信度 低】
- 場所：GameSession.swift:284-285（`?? GameState(config: cfg)`・`save.runner.year <= 1` で hasYearStart=true）。新規開始は :251 `GameState(config:, metaPoints:, femaleCombo:)` ＋年初処理後の r.state。
- 見えること／実際：旧セーブで周回の点や女コンビの初期値がある場合、等級の段に「育っていない能力の ↑」が出うる。本物の旧セーブ（yearStartState 追加前）はほぼ残っていないはず。
- 直し方：1年目でも nil だったら hasYearStart=false にする（`save.yearStartState != nil` のみ）。
- 既出：なし。

## §2 問題なしと確かめた主な所
- 今年の賞金（totalPrize）：通常の大会は weekDone で加算（GameSession:1408）。優勝年の GP 賞金は yearDone で `log` 行と一緒に加算（:1463）、yearHistory.prize は同じ式を「加算の前」に `totalPrize + gpPrize` で作る（:1439）＝画面の合計と年の記録は一致。夜逃げ・解散の年は、その週の結果を先に log／totalPrize に足してから記録（:1431-1435）＝一致。翌年に `totalPrize = 0`（:1189）でリセット、保存・復元も totalPrize ごと（:335）。
- 優勝の二重加算：yearDone の処理は pump 内で `break loop` され、復元は yearDone を pump し直さない（:346 は weekDone かつ結果なしの時だけ）。yearHistory 側は `last?.year != runner.year` で二重防止、トロフィーは didRecordChampion で二重防止＝賞金・出来事ログの二重は起きない。
- 手帳の優勝の二重カウント（AUTOPILOT 231）：yearHistory は年末（yearDone）で追加。年末画面の間は手帳を開けない（RootView）＝本編では起きない。既出・済の判断どおり。
- 大会の成績の3行：eventLines が決勝の行・優勝を優先、「ほかN大会」は賞金合計との差を説明（hiddenStageCount）。観戦は数えない。stageRecord と独白の filterByRecord は同じログから数える＝一致。
- 到達の判・小見出し・年表の呼び名：reachStamp と reachLabel は champion→bankrupt→dissolved→final の同順で、年末画面・手帳・年表で一致。「不出場」は log の1回戦の有無で判断（loggedGPEntry）で、中断→再開でも log が保存されるため崩れない。
- 優勝した年：勇退／続けるは canChooseRetire（優勝かつ非最終年）。最終年の優勝は careerOver で onNextYear=nil → 「エンディングへ」。「続ける（N+1年目）」が最終年に出ない。共有カードの連覇表記は yearHistory（今年を含む）から数え正しい。
- 夜逃げ・解散の年：careerOver（:1143）で「来年」の独白行を除外（YearResultView:386）。ボタンは onNextYear=nil。
- 15年目の年末：careerYears=15 で「来年」を外し、yearHistory は最大15行で表示。終わらない年の押下は startNextYear が yearStartState と hasYearStart=true を更新（:1180-1181）。
- 称号／トロフィー：年末総決算の画面には出さない（TrophyBook は onYearEnd で付与するだけ）＝表示と実際の食い違いの対象外。
- 来年の狙い：現行の画面には無し。案は candidate `claude/yearly-goal-cand`（decision_brief B-12・AUTOPILOT 132）＝既出。candidate は main に追いついておらず（他ファイルの差分が多い）、今回の点検対象は現行の main。final-year-history-cand（AUTOPILOT 136）＝15年目の履歴の見せ方の案で、数字の食い違いではない＝既出。
