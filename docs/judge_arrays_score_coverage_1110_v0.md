# 審査員の講評・司会の文の配列ごとの採点済み状況（2026-11-10）

## 結論
1. 記録なし＝1配列のみ（`JudgeTalk.paperNetaLines`・条件付きの6行・配列名はどの文書にも出ない／内容は紙講評の採点に含まれる可能性）。講評の主要配列（Paper.* 11本・bandLines 7審査員×4帯・vocab・pickups）は全て文書に名前がある。
2. 次に採点すべき上位5（要素数×記録の古さ）：①Paper.fail（30本・最終 10/19）②Paper.pass（24・10/19）③Paper.passChemistryHigh（24・10/19）④Paper.failStaminaLow（18・10/19）⑤vocab（147語・最終 10/25 v6）。いずれも10/25 の紙講評増補（22→42本）より前の採点で、増補後の全面採点は v8（11/10）が failNear/passBurst/passMentalLow だけ。
3. 10/28 以降に配列へ足された行は0（JudgeTalk の変更は 11/02 のみ＝型なし語彙へ統一・引用符を含む新行なし）。FinalsTalk・FinalsBroadcastIntro・TournamentResultView の文は 11/10 の finals_mc_lines／tournament_result_text の採点が最新で、新行なし。

## 表1：記録なし（要素数の多い順）
|ファイル|配列|要素数(概数)|10/28以降の新行|
|---|---|---|---|
|GameCore/JudgeTalk.swift|paperNetaLines（紙講評のネタ状況別・通過/落選）|6（条件付き3×2）|0|

（参考：名前では出ないが内容の一致で採点済みと分かる物＝TournamentResultView.missLine（tournament_result_text_score_1110）、FinalsBroadcastIntro.vtrLines（finals_mc_lines_score_1110 ほか）、QualifierNoticeView.resultLines（dialogue_score 系）。いずれも新行なし。）

## 表2：記録が古い（10/27以前）で新行あり
該当なし（10/28 以降の追加行は0）。
参考＝記録が10/19 のままで、その後 10/25 に紙講評が増補された配列（増補後の採点は未確認。10/28以降ではない）：

|配列|要素数|最終に名前が出た文書（日付）|
|---|---|---|
|Paper.fail|30|judge_comment_score_v5（10/19）|
|Paper.pass|24|judge_comment_score_v5（10/19）|
|Paper.passChemistryHigh|24|judge_comment_score_v2（10/19）|
|Paper.failStaminaLow|18|judge_comment_score_v2（10/19）|
|Paper.passStaminaLow|14|judge_comment_score_v5（10/19）|
|Paper.failChemistryLow|12|judge_comment_score_v2（10/19）|
|Paper.failMentalLow|11|judge_comment_score_v2（10/19）|
|Paper.failFar|5|judge_comment_score_v5（10/19）|
|bandLines 天堂寺A／花園…（A帯の一部：天堂寺・卯月・白波・目白・音羽のA）|各4|judge_comment_score_v3/v4（10/19）|
|vocab（全型なし語彙）|147|judge_comment_score_v6（10/25）|
|pickups|11|dialogue_score_1026（10/26）|

（Paper.failNear・passBurst・passMentalLow・bandLines の他の帯は judge_comment_score_v8／judge_final_comment_score_v1 で 11/10。）

## 方法
GameCore/Sources と ManzaiGame/Sources で `static let …: [String]` を grep し、JudgeTalk.swift の Paper.*（11本）・bandLines（辞書：審査員7×帯A〜D＝28本）・vocab・pickups と、司会（FinalsTalk）・決勝/予選の画面文を対象にした。要素数は各配列範囲の文字列リテラル数（bandLines はキーを除く）。docs/ の judge・comment・score・review・sweep を名前に含む文書を配列名（Paper.＋名前、bandLines は審査員の姓＋帯）で grep し、git log の最終コミット日で「最後に名前が出た文書」を取った。10/28 以降の新行は `git blame` の author-time で引用符を含む行を数えた概数。限界：名前の一致だけなので、bandLines の帯別は姓＋帯の近接一致で粗い／code_review 系の名前一致は採点の証拠とは限らない／hookLines・sceneLines は関数内のインライン文（約70行）で配列名の記録は judge_comment_score_v3/v4・judge_final_comment_score_v1 にある。
