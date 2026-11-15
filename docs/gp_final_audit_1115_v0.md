# GP 準決勝→敗者復活→決勝→優勝／敗退→年末 のコード点検（11/15・読むだけ）

- 要点1：新規4件（中1・低3）＋既出の関連2件。規律A（Python 正典と Swift の式・乱数消費）の食い違いは**なし**。
- 要点2：一番重いのは「敗者復活を通って優勝した年だけ、称号『敗者復活の奇跡』(t21) が付かない」（優勝週は weekDone を経ず onStage が呼ばれない＝trophy_meta_audit #4 の見落としていた具体例）。
- 要点3：決勝の点・順位・ボード・票と StageResult（passed／margin）は一致。中断→復元で決勝が再抽選・二重結果になる経路はなし（乱数はセーブに載り、演出は結果確定後の再生）。

節構成：§1 新規の指摘 ／ §2 既出・関連 ／ §3 確認済み（問題なし）

## §1 新規の指摘

### #1 【中】敗者復活を通って優勝した年に t21「敗者復活の奇跡」が付かない（t15/t16 の敗者復活分も）
- 場所：WeekRunner.swift:309-318（優勝は週の結果を返さず即 `.yearDone`）／GameSession.swift:1431-1485（yearDone の優勝分岐は onStage を呼ばない）／Meta.swift:154-174（t21 は onStage の「敗者復活」通過でだけ付与）。
- 起きる手順：準決勝（週45）で落ちる→週47 の敗者復活を通る→同じ週の決勝に勝つ。結果の `weekResults`＝[敗者復活 通過, GP決勝 通過] は weekDone を経ないので TrophyBook.onStage が一度も呼ばれない。t17（決勝進出）は onYearEnd で付くが、t21「敗者復活を通って決勝へ進む」だけが付かない。決勝で**負けた**時は weekDone を経て付く＝「勝った時だけ取れない」逆転。同様に、体力30未満・所持金マイナスで敗者復活を通った時の t15/t16 も優勝の時だけ判定されない。
- trophy_meta_audit #4 は「決勝の分の t15/t16 が走らない」と書き、推奨①（今のまま）としているが、敗者復活の通過分が巻き込まれることには触れていない。
- 直し方の案：①今のまま（敗者復活→優勝は取れない仕様と割り切る＝称号の説明文「敗者復活を通って決勝へ進む」とは食い違う）／②優勝分岐（GameSession.swift:1469付近）で `runner.snapshot().weekResults` のうち「敗者復活」の行だけ onStage に渡す（決勝の行は渡さない＝t15/t16 を決勝に広げない）。TrophyBook は端末内・冪等（award は重複しない）＝golden 非対象。推奨②。

### #2 【低】敗者復活→優勝の年だけ、連敗数（lossStreak）と styleTalkDone が戻らず、翌年の最初の負けが「連敗中のまた」になる
- 場所：GameSession.swift:1409-1420（lossStreak=0／styleTalkDone=false の更新は weekDone の `big` ループの中だけ）／同 :1431-1485（yearDone の優勝分岐は更新しない）／startNextYear（:1189-1228）は lossStreak を持ち越す（code_review_1107g の「意図どおり持ち越し」）。
- 起きる手順：準決勝敗退で lossStreak=1 → 敗者復活→決勝を通って優勝（weekDone が無いので 0 に戻らない）→「続ける」で翌年へ。翌年の最初の GP 敗退で lossStreak=2 になり、`justLostRepeat`（「連敗中にまた負けた翌週」の心の声）・`.streak` の掛け合いが出る。優勝した直後なのに連敗扱い。lossStreak>=3 で styleTalk（0019）も早く出うる。
- 通常の優勝（準決勝を通過→決勝）は準決勝通過の weekDone で 0 に戻っているので起きない＝敗者復活経由だけ。
- 直し方の案：優勝分岐に `lossStreak = 0; styleTalkDone = false`（UI 層のみ・乱数なし・golden 非対象）。①入れる ②今のまま。推奨①（1〜2行）。

### #3 【低】決勝（または準決勝）の負けた夜に、同じ週の週末処理で夜逃げ・解散すると、決勝の演出が出ず年末結果へ直行する
- 場所：WeekRunner.swift:455-471（週末処理で bankrupt／dissolved なら `.yearDone`）／GameSession.swift:1440-1452（その分岐は結果を log・賞金年計・onStage にだけ足す）／RootView.swift:402-424（FinalsPresentationView の負け版は `pendingResult` の最後が GP決勝・不通過の時だけ）。
- 起きる手順：所持金が少ない状態で決勝に落ち、週末の生活費で bankruptLine を割る（または相性低下で解散）。`pendingResult` が作られず `finished=true` になるので、「決勝で負けた夜」の演出・結果画面を飛ばして年末（夜逃げ／解散）が出る。準決勝（週45）で通過した夜に同じ事が起きると、決勝進出者の発表も出ない。
- 影響：ほぼ起きない経路（決勝の負けが所持金ぎりぎりの年）。起きても最終結果は正しく、演出が出ないだけ。trophy_meta_audit #2/#3 は称号側の同じ経路で、画面側の指摘は無い。
- 直し方の案：①今のまま ②夜逃げ・解散で終わる年でも、weekResults の最後が GP決勝（不通過）なら先に決勝演出を見せてから年末へ（pendingResult を立てて finished を保留＝制御が複雑になる）。推奨①。

### #4 【低】準決勝敗退の発表は「他10組が決勝進出」と出るが、敗者復活を通ると決勝の他組は9組（発表された組のうち1組が消える）
- 場所：FinalistAnnounceView.swift:40（`passed ? 9 : 10`）／FinalsPresentationView.swift:1401-1406（yearRoster は prefix(count)）／FinalsPresentationView.swift:77-90（決勝は他組 9）。
- 起きる手順：準決勝で落ちる→発表で「10組」が読まれる（自組は影のまま）→敗者復活を通る→決勝は他9組＋自組＝10組で、発表の10番目の組（`prefix(10)` の末尾）が決勝に出ない。本物の M-1 では敗者復活の枠が10組目＝発表は9組。落ちた年は発表と決勝の顔ぶれが10番目だけ食い違う。落選して客席から観る年（観客版決勝・他10組）は発表と一致する。
- AUTOPILOT 89「残り＝敗者復活の案内（オーナー確認待ち）」に近いが、この数のずれは出ていない。
- 直し方の案：①今のまま（敗者復活を通る年は少ない・10番目は誰も覚えていない）②落選時の発表も9組にして「敗者復活枠」の影を1つ置く（演出の判断）。推奨①。

## §2 既出・関連（新規に数えない）

- 優勝週は onStage が呼ばれない（t14／決勝での t15/t16）：trophy_meta_audit_1115 #4 既出。**#1 はその具体例のうち t21 を足したもの**。
- 敗者復活を「通った」時の結果画面が無い（敗者復活→そのまま決勝の本番前カードへ）：AUTOPILOT.md 89「敗者復活の案内（オーナー確認待ち）」に既出。コード上も、敗者復活の通過後は `advanceAuto` が `.gpFinal` を返す→pump の default 分岐→`pendingResult` なしで RootView.swift:442-447 の本番前カード（StagePreludeView）へ直行する（週の結果は決勝と同じ weekDone に載る）。副作用：敗者復活の「知名度 +n」「ハマった夜」は表示されない（`lastResultFameDelta` は決勝の増分で上書き・result_screen_audit §「2件が載るのは敗者復活＋決勝だけ」＝食い違いなしと整理済み）。優勝の年は出来事ログにも「敗者復活 通過」の行が無く、決勝の1行だけ（GameSession.swift:1478）。
- 優勝の週は生活費・誘い・オファー・自由行動が飛ぶ（WeekRunner.swift:309-318 のコメント「runYear と同一」）：Python 正典（sim_career.py:1030-1033・gen_golden.py:138-141）も同じ＝仕様。

## §3 確認済み（問題なし）

- 経路①準決勝で落ちて敗者復活へ：WeekRunner.swift:273-278（準決勝敗退だけ `revival=true`・gpAlive=false・相性は gpLossCompat で下げる）。週47で `.gpRevival`→resolveAuto。画面：準決勝の結果（判の前に決勝進出者の発表）→週46自由→週47 敗者復活の本番前カード。問題なし。
- 経路②敗者復活で落ちる：finalist=false のまま決勝へ進まず週末処理→weekDone→結果画面（山場 ClimaxData.revivalLoss）→`acknowledgeResult`→第48週。roundsPassed=4・reachedFinal=false（年表は「準決勝敗退」）。相性は下がらない（コメントどおり）。問題なし。
- 経路③決勝で負ける（敗者復活経由を含む）：weekResults=[…, GP決勝 不通過]→weekDone→pendingResult→RootView.swift:422-424 が FinalsPresentationView（負け版）→`acknowledgeResult`→第48週。TrophyBook.onStage は weekDone で1回（敗者復活の t21 も付く）。lossStreak は通過→0→敗退+1 で整合。問題なし。
- 経路④優勝：yearDone(champion)→yearHistory は `yearHistory.last?.year != runner.year` の guard で1行・prize は totalPrize＋gpPrize（直後に totalPrize へ gpPrize を足す＝二重でない）／連覇は yearHistory の末尾から数える・`didRecordChampion` で recordChampion と t20（玉座奪還）を1回だけ／出来事ログ1行／winFinale→FinalsPresentationView→`acknowledgeWin`→finished→YearResultView。winHeadline・repeatWinLine・TrophyBook.recordChampion の連覇の数えは同じ式で一致。問題なし。
- 勝敗と点・順位・ボード・票（観点2）：`perform` は `score >= line`＝passed（margin>=0 が通過）。FinalsData は champion＝通過のとき自組を最終決戦に入れて4票以上（補正ループ）、負けのときは自組を3票以下かつ首位でなくする。惜敗（margin>=-4）は1本目1〜3位で最終決戦まで残り、それ以下は4位以下で敗退。他組の合計は同点を作らない（used で重複回避）。7審査員の点の和＝合計に補正済み（50〜99 に収めてから和を合わせる）。表示合計は帯の乱数で margin と比例はしない（逆算防止の設計）＝StageResult の合否・順位帯とは矛盾しない。同点・僅差でも矛盾なし。
- 中断→復元（観点3）：RNG はスナップショットに載る（WeekRunnerSnapshot.rng）。決勝前（`.gpFinal`・pendingAuto=.final）で保存→復元しても `advanceAuto` で同じ乱数から同じ結果（保存直前に落ちても同じ）＝二度結果が出る・結果が変わる経路なし。決勝の結果を見る演出中（負け＝`pendingResult` 保存済み／優勝＝winFinale を `winAcknowledged==nil` から復元）は、演出が頭（くじ）から再生されるだけで、結果は lastFinalMargin（保存週内結果から復元・GameSession.swift:290）／pendingResult の margin から同じ見せ札が再構成される（FinalsData は能力・年・margin で決定的）。飛ぶ経路なし。`acknowledgeWin` 後は winAcknowledged=true で年末から。careerOver（最終年・勇退）は saveNow が save を消す。
- 二度押し：advanceAuto・decideTournament・choose・acknowledgeResult・acknowledgeWin・retireAfterWin・startNextYear は phase／finished／pendingResult の guard。決勝演出の finishResult も同じ（double_tap_audit #6 は演出内の札の送りで別件）。
- 観点4（優勝週の他の処理）：優勝週は生活費・オファー・自由行動・週末の誘い・解散判定が走らない（仕様＝§2）。負けた週は offer を引かず（acted）、週末処理は1回。二重になる処理は見つからない。週ごとの tick（相性凍結・ネタ合わせブースト・稽古拘束）は choose（自由週）だけ＝GP 週は走らないのは他の大会週と同じ。
- 観点5（Python 正典との食い違い）：gen_golden.py:85-140 と WeekRunner.resolveAuto が、回戦・敗者復活・決勝の順序（エントリー費→perform→大会の経験点→知名度→gpStage 進行／敗者復活→同週の決勝→効果ライン `line − fameFinalBonus×(知名度−50)/50`）・乱数消費（perform ごとに uniform＋burst 判定の2draw・敗者復活と決勝で各1回）・定数（gpRounds・gpRevivalLine 79・gpFinalLine 81・gpLateBonus 11年目+2・fameFinalBonus 1.5・gpPrize・champFame・fameFinalist・gpLossCompat・tourneyExp*）で一致。ネタの補正（netaScoreBonus）は selectedNetaID==nil で恒等 0＝golden 非経路。sim_career.py の upset／飽きられ／_neta_line_adj は研究用で golden・アプリ非経路（既知・AUTOPILOT 124）。規律A 違反なし。
- 復元時の定数：`finalLine` は config から取り直す（A-4）。アプリは seedFinal／finalLineOverride を使わない（gen_golden の王者編専用）＝王者ライン上書きが復元で消える経路はアプリでは起きない。
