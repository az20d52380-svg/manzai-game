# コード点検：候補まとめ枝 origin/claude/all-bundles-1109-cand と本体の差分 v0

対象：`git diff HEAD origin/claude/all-bundles-1109-cand -- ManzaiGame/Sources GameCore/Sources`（32ファイル・+1073/-656）。読んだだけ（テスト・sim は回していない）。台詞の良し悪しは見ていない。
注意：差分には「本体にあって候補に無い」向きも混ざる。HEAD にだけある `de76303d`（縦札の字の下限8・ガチャの pendingNote 削除）が、候補側では巻き戻って見える（#6）。

## ①要点3行
- 件数：高 0／中 2／低 7（落ちる所・セーブが読めなくなる所・GameCore の乱数の消費順の食い違いは見つからなかった）。
- 一番重いのは「暦を1月始まりに戻す（calendar-jan）× 帰省の電話（homecomingCall）の発火条件」の食い違い：週41以降は本番が1〜2週おきに続くので、条件「3週以内に本番なし」を満たすのは GP に残っていない人だけになる（推測）。
- GameCore の差分は `ChoiceEvent.swift` の週の数字4つだけ（UI 層の週次抽選の候補。golden・乱数は不変）。数値の直書きの追加は表示用の定数（一覧45/35/25・読みの仮名の hash）だけ。

## ②指摘の表
| # | 重さ | ファイル:行 | どの候補から | 何が起きるか | 直し方の案 |
|---|---|---|---|---|---|
| 1 | 中 | GameCore ChoiceEvent.swift:421 ＋ GameSession.swift `weeklyExtraGate(.homecomingCall)`／`noTournamentWithin3Weeks` | calendar-jan × （既存の gate） | 帰省の電話が `week>=41`（11月〜）に動いた。この帯は GP の週 41/43/45/47・道中大会 46 が続き、`nextStage.week - week > 3` を満たすのは GP が閉じた（落ちた／出ていない）人か週48だけ。GP を勝ち進む年は出ない（推測：実測していない） | 週数を 41→37 前後に戻す、または gate を「次の本番が3週以内」ではなく「今週が本番週でない」に緩める。判断が要る（正月の話の季節感と頻度） |
| 2 | 中 | GameSession.swift:1342（saveNow の guard）・RootView.swift:362,420 | career-end-save（キュー117） | 旧：`finished && careerOver` で毎回セーブを消した。新：消すのは closeCareer（エンディングに入る／returnToTitle／勇退）だけ。夜逃げ・解散の年末画面でエンディング無しのままアプリを落とすと、終わった周のセーブが残る（復元で終わった年末へ戻るはず＝落ちはしない・推測）。復元して「もう一度」を押せば消える | 夜逃げ・解散の確定点（finished が立つ所）でも closeCareer を呼ぶ、または saveNow の guard に `finished && careerOver && 年末でない` を足す |
| 3 | 低 | FirstPassShare.swift:10・TournamentResultView.swift:183 | first-pass-share | 「初めての通過」の印は端末の UserDefaults に新規キー。既に何度も通過した端末（旧ビルドからの更新）でも次の通過で「初めての通過」と出る（推測：出荷前なら無関係） | 印の初期値を「図鑑・通過の記録が既にあれば出した扱い」に（TrophyBook か yearHistory を見る） |
| 4 | 低 | GameSession.swift `neta2DroppedNotice`（非保存）・StageViews.swift の表示 | final-silence／C-17 | フラグは次に selectNeta/selectNeta2 を呼ぶまで残る。2本目を選び直さないまま決勝を終え、翌年の決勝入口で `selectedNeta2 == nil` なら、外していないのに「2本目の選択が外れました」が出る（推測） | 年の切り替え（nextYear）と決勝の結果確定でフラグを false に |
| 5 | 低 | GameCore ChoiceEvent.swift:43,49（case の行コメント） | calendar-jan | 夏祭り「週14-20」・年末ライブ「週33-36」のコメントが古いまま（gate は 26...32／45...48）。docs/choice_events_more_v1.md の週の記述も同様の可能性 | コメントを直す（動作は変わらない） |
| 6 | 低 | IntroFlow.swift `charSize`・GachaView.swift `.task` | （本体側 de76303d が未取り込み） | 候補の枝は本体の直し（字の大きさの下限8・未使用 pendingNote の削除）を持たない。このまま本体へ入れると巻き戻る | refresh_candidates で本体を取り込み直す（衝突は出ない見込み・推測） |
| 7 | 低 | WeekHint.swift:37-39 | week-hint-priority | 体力の警告を `preoccupied`（撮影の週）より前に出した。撮影の週は稽古に出られないので「今週は休むのも手だ」が出ても動けない（休めるかは未確認・推測） | `preoccupied` の判定を体力警告の前へ戻す（生活費の警告だけ先頭に残す） |
| 8 | 低 | GameSession.swift:683（kouhaiInvite `week >= 24`）ほか週の直書きの gate | calendar-jan（取りこぼし） | 暦を動かした時に直したのは月が名指しの4イベントだけ。「1年目の後半」＝週24 など、4月始まり前提の数字が残る（後輩は春に来る話なら週13前後になる・推測） | 季節の絡む gate を grep し直して確かめる（判断が要る） |
| 9 | 低 | ChoiceEventOverlay.swift:22・GameSession.pickIndex | invite-variants | `stablePicks` は保存されない。イベントの途中（会話を読み途中）で落として復元すると、`usedPicks`（保存あり）に入った番号を避けて別の文面が選ばれる＝読み始めと違う会話になる（推測・実害は小さい） | 復元直後の1回だけ `usedPicks` の最後の番号を再利用する、または許容 |
| 10 | 低 | ChoiceEventData.swift `text(for:year:week:)`（2引数版） | invite-variants | 本編は pick 版に移ったが、旧 2引数版が残り、ManzaiGameTests.swift:775-787 はこちらだけを確かめている＝本編の経路のテストにならない（InviteVariantAvoid1108Tests が pick 版を見ている分は別） | 旧版をテスト専用と明記するか削除してテストを pick 版へ |

## ③問題なしと確かめた主な所
- unused-parts の削除（EventSceneView／DuskScene／PlaceScene／EventScene／DogEar／BubbleTail／BounceArrow／HexEmblem／emblemFill・Rim・Text／TalkBubble・NameTag・WaIcon・GainChip ほか Theme／YoseTokens の定数・AbilityBadge・CurrencyBadge・kataColor）は、候補の枝の ManzaiGame 全体（Tests 含む・md 除く）を `git grep` して参照0を確認。
- 「Yen.short／Yen.inText」への統一（money-format）：定義は Theme.swift:407-409 で `abs` を取る形＝WeekMainView の符号付き表示（`+`/`-` を別に付ける）と矛盾しない。`extraCards(showDesc:)` は既定値つきで呼び出し元は WeekMainView と Tests のみ。
- テレビ慣れの段（offerFatigueLevel）は GameEngine.offerFatigued と同じ窓（offerFatigueWindow=6）・同じ K（4）で数えている。借金の知らせの戻し（resetDebtWarnIfRepaid）は「0以上かつ段≠0」でだけ保存。
- 観客の声：新しい「古くからの客」系の文は knownOnly に載っていて無名のうちは出ない（スクリプトで bandA/B の語を拾って照合し、漏れ0）。実名の直書きは既存の流儀（台詞の「谷口」は Names.show、店長は「矢島」に Endings も揃った＝「布施」は全ソースで0）。Names.setCombi は init・restore・IntroFlow の3か所で呼ばれ、入力の1文字目でコンビ名が置換されない。
- 敗者復活の短い版（repeatSeen）は `roundsPassed==4 && !reachedFinal` ＝準決敗退→復活も負けの年を数える（roundsPassed は 0〜5・GP回戦名5つ）＝今年分は yearHistory に入る前なので数えない。nextGoal の添字も範囲内。

## 親の照合（11/09 夜）
- #6 取り下げ：枝が本体の新しい直し（字の下限8・pendingNote）を持たないのは、枝が作られた後に本体が進んだだけ。本体へは merge で入れるので、本体の直しは巻き戻らない（入れる前に refresh_candidates で取り込み直せば差分からも消える）。
- 中の calendar-jan（帰省の電話を週41以降へ）は「推測・未実測」。入れると決まったら、Python 側の発火条件の鏡像（check_event_trigger_parity）と出会う率の実測で確かめる。
- calendar-jan の実測（n=300・exp_event_reach_relax_v0 の base・ボット4種）：帰省の電話／キャリア＝本体 0.21〜0.26 → 候補 0.14〜0.22（約2〜4割減）。年末ライブも 0.13〜0.33 → 0.08〜0.24。0にはならない＝「GP に残る人には出ない」ほどではなく、出にくくなる程度。入れるなら帰省の発火の週の幅を合わせ直すかを一緒に決める（AUTOPILOT 129 の論点と同じ所）。
- #2（career-end-save）取り下げ：夜逃げ・解散の年末でセーブが残るのは候補の狙い（案A＝年末で落ちても周と図鑑を消さない）どおり。復元すると同じ年末の画面に戻り、「もう一度」（returnToTitle→closeCareer）で消える。
- #10 直した（候補 invite-variants-cand・旧い関数を pick 版への委譲に・395 green）。#4 直した（候補 final-neta-notice-cand・startNextYear で印を戻す・391 green）。#5 直した（候補 calendar-jan-candidate のコメント 7554d8c8）。まとめの枝には次の取り込み直しで入る。
- #7 取り下げ：撮影の週（preoccupiedWeeks>0）に塞がるのは稽古だけ（WeekMainView:898-899 の isTrain）＝「休む」は押せるので、体力の警告を先に出しても動ける。
