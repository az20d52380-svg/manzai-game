# THE HANA（勝ち上がり戦）の流れのコード点検（11/15・読むだけ）

**要点3行**
1. 新しく見つかった食い違い・事故は **低が2件・中0・高0**。通過の連鎖（hanaYear/hanaNext）・週の重なり・年またぎ・中断復元・賞金/知名度/トロフィー/年末の数えは問題なし。
2. Python 正典と Swift：段の定数（週・ライン・賞金・知名度）は `check_config_sync.py` 80/80 一致、通過/優勝の処理・出場資格・前夜の除外・乱数の消費位置も同じ形。**規律A違反なし**。
3. 見つかったのは「見送る」の警告が無い点と、カレンダーが先の段を出さない点（どちらも表示だけ・低）。

節：§1 出場資格・日程・並び／§2 負け・見送り・中断復元／§3 重なり・年またぎ・最終年／§4 賞金・知名度・トロフィー・年末／§5 Python 正典との突き合わせ／§6 問題なし一覧

## 新規の指摘

### 低-1 「見送る」で今年の THE HANA が終わると知らされない
- 場所：ManzaiGame/Sources/StageViews.swift:229付近（`session.decideTournament(nil)` の「見送る」）／GameCore Calendar.swift:56（`hanaYear == year && hanaNext == i`）
- 手順：女コンビで HANA2回戦の入口を「見送る」→ `hanaNext` が 1 のまま、準決勝・決勝の週は入口が出ない（見送りで1段飛ばしはできない仕様）。入口の説明（hintSpec）にも「落ちる／見送るとその年はここまで」の記述が無く、1回戦（動画審査）でも同じ。
- 直し方の案：①入口に1行「見送るとこの年の THE HANA はここまで」を足す（THE HANA の段のときだけ）②そのまま（設計どおり・entry_audit_1115 §THE HANA が挙動を既出と確認済み＝画面の説明だけが未）。推奨①。

### 低-2 カレンダーは今の状態で出られる段だけ塗る＝1年の最初は 1回戦しか見えない
- 場所：ManzaiGame/Sources/CalendarView.swift:200-203（`isTournamentWeek`：これからの週は `isEligible` で絞る）
- 手順：女コンビの年初、カレンダーには第32週（1回戦）だけが印として出て、37/42/44 週は空き週に見える。通過すると順に出る。「勝ち上がり戦」という全体の道筋は画面からは分からない（11/08 の code_review_2026-10-19g §2 の判断どおりで、不整合ではなく見せ方の問題）。
- 直し方の案：①今のまま（出られない週を「大会」と見せない既定を優先）②HANA だけ、先の段を薄い色（未確定の印）で出す。判断はオーナー。

## 既出（再掲しない）
- 夜行バス遠征の数え（東京の HANA でも t12 が増える）：trophy_meta_audit_1115 #1。
- 優勝と同じ週の夜逃げ・解散でトロフィー／smallWon が付かない件：trophy_meta_audit_1115（recordHanaWin も onStage 経由＝同じ穴）。ただし解散週の分は GameSession.swift:1442 で onStage だけは呼ぶ（HANA決勝の記録は付く）。
- 週の衝突なし・hanaYear の年またぎ：entry_audit_1115 §出場資格、gamecore_boundary_audit_1115。
- 二重数えなし（復元経路は pump を通らない）：save_restore_audit_1115。
- AUTOPILOT 151：古い候補ブランチ the-hana 2本の扱い（枝は残し、check_candidates の対象外）。AUTOPILOT 199：難しさの判断と「決勝が2月第4週」の暦（下の §1 参照・オーナー待ち）。

## §1 出場資格・日程・並び
- 日程：HANA 32/37/42/44 週。暦は「第1週＝4月・4週で1ヶ月」（CalendarView.swift:210）なので 1回戦＝11月第4週、2回戦＝1月第1週、準決勝＝2月第2週、決勝＝2月第4週。頂GP 準々決勝（43）の翌週に HANA 決勝、GP 準決勝（45）の前＝**HANA が GP の途中に挟まる**。AUTOPILOT 199 が既に判断待ちとして挙げている点で、コードの内部（週番号）と画面の月表示は食い違っていない。
- 資格：`.hana(round:)`＝女コンビ かつ（1回戦、または同じ年に前の段を通過）。芸歴の制限なし（15年全部で毎年出られる）。入口・カレンダー・upcomingStages（GameSession.swift:744）・WeekRunner.proceed（:399）がすべて同じ `isEligible` を見る＝画面と内部は一致。
- 段の名前：内部キー "HANA1回戦" を表示側で "THE HANA 1回戦"（GPName.display）に統一。結果ログ→年表の hanaReach は "THE HANA " の後ろを読む＝一致。問題なし。

## §2 負け・見送り・中断復元
- 負け：通過しないと hanaNext が進まない＝次の段は入口が出ない。前年の hanaYear/hanaNext が残っても `hanaYear == year` で無効。問題なし。
- 見送り：低-1。次の段へ進めてしまう経路は無い（hanaNext は通過でしか動かない）。
- 所持金不足（エントリー費2,000円）：resolveTournament は何もせず進む＝見送り扱いで次の段は出ない。入口のボタンは enabled で押せなくしてあるので実害なし。
- 中断→復元：hanaYear/hanaNext/hanaWins は GameState に載り、セーブ（WeekRunnerSnapshot が state を持つ）で保たれる。復元は pump を通らず onStage/recordHanaWin を二重に呼ばない（save_restore_audit_1115 で確認済み・ここでも同じ）。旧セーブは femaleCombo=nil＝男コンビ扱い＝HANA は出ない。
- 二重に数える経路：state.hanaWins（キャリア内）は WeekRunner.swift:224、Meta の通算は onStage "HANA決勝"（Meta.swift:168）で別々に1回ずつ。優勝演出（showHanaChamp）は acknowledgeResult 側で数えない。問題なし。

## §3 重なり・年またぎ・最終年
- 同じ週に HANA と他大会／GP が重ならない（データ上・Boundary1107Tests／CalendarOverlap1107Tests が重なっても通常大会優先を固定）。
- 年またぎ：年初の WeekRunner.init で 1回戦は常に出られる状態に戻る（`i == 0`）。最終15年目も HANA（週32〜44）は GP 決勝（47）より前に終わる＝年末前に必ず完結。
- 女コンビでない周回（男・男女）では state.femaleCombo が nil/false で HANA は一切出ない（GameSession.swift:254）。男コンビの golden は不変。

## §4 賞金・知名度・トロフィー・年末
- 賞金：決勝のみ手元250万（Calendar.swift:82）、通過ごとに知名度+3、優勝+8。Python と同値（§5）。1〜3回戦の賞金0は入口で「0万」を出さない処理済み（StageViews.swift:187）。
- 年表の「優勝」の印：summarize が `prize>0` を優勝と読む（GameSession.swift:1800）→ HANA は決勝だけ賞金があるので「決勝＝優勝／他＝通過」と一致。
- 六冠（t22）：smallTournamentCount が HANA を「1回戦で出た・決勝通過で優勝」と数える（Meta.swift:184）。smallWinCount（GameSession.swift:1131）は HANA/頂GP を除く。
- NotebookView.kirokuWins：今年の記録の HANA 優勝を `max(0, hanaWins − 今年分)` で重複排除。問題なし。
- EndingViews:341 の「THE HANA 優勝 N回」は Meta の通算（周回をまたぐ）、手帳は state.hanaWins（今のキャリア）＝見る画面で母数が違うが、ラベルは「通算」と「記録」で分かれており混乱はしない。

## §5 Python 正典と Swift の突き合わせ
- 定数：HANA_WEEKS/NAMES/LINES/PRIZE/CHAMP_FAME と hanaTournaments（週・ライン・賞金・知名度）は check_config_sync が 80/80 一致（`python3 tools/check_config_sync.py` 実行済み）。
- 段の処理：Python hana_result（通過で (年,i+1)、決勝通過で hana_wins+1）と WeekRunner.swift:219-226 は同じ。出場資格 ok と isEligible も同じ。
- 乱数：Python enter_tournament は eligibility 後に `B.perform` 1回（ネタ補正は rng を使うが NETA_ON 時のみ）、Swift は GameEngine.perform 1回＝合否の乱数消費位置は同じ。HANA だけ「2本制」の決勝補正を付けない点も両方 final=False で一致。
- 動画審査の前夜除外：Python sim_career.py:491 と Swift GameSession.swift:609 が同じ条件。
- golden：gen_golden.py に「THE HANA」と「HANA 決勝」の2系統あり（女性コンビ）。`swift test --filter` の指定名では 0 件になった（Swift Testing 形式・クラス名が違う）ので golden の再実行はしていない。config sync のみ確認。
- 規律A違反：見つからず。

## §6 問題なし（1行ずつ）
- 通過連鎖（hanaYear/hanaNext）：年・段の両方で照合＝飛び級・前年の持ち越しなし。
- 優勝後の再入場：決勝は最後の段で hanaNext は動かない・週も1回きり＝なし。
- 週の重なり・年またぎ・最終年：上記 §3。
- カレンダーの過去週の塗り：実際に出た週だけ（paintsPastWeek）＝見送り・敗退後の週を「やった」と塗らない。
- 前夜イベント：1回戦だけ除外し、2回戦以降は出る＝2回戦以降は舞台に立つので妥当。
- 結果画面の「優勝」「突破」「動画審査」の言い換え：isHanaFinal／isHanaVideo の条件と名前キーが一致。
- 賞金・知名度の二重加算：WeekRunner の1か所のみ。
