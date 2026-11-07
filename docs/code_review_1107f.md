# コード点検 11/07f（優勝後の「勇退／続ける」差分 487df7ba..HEAD。読み取りのみ・コード変更なし）
対象：ManzaiGame/Sources の差分（Endings / FinalsPresentationView / GameSession / Meta / RootView / YearResultView）。
既知の after_win_check_1107・playtest_dynasty_1107・code_review_1107e と重複する物は除いた。高は無し。

## 所見（4件：中1・低3）

### #1 中｜「勇退する」に確認が無く、誤タップで取り返しがつかない
- 場所：YearResultView.swift:486-497（restartButton）／RootView.swift:398（onRetire）／GameSession.swift:1145-1148（retireAfterWin→saveNow）
- 再現：能力マックス等で十数年続けた優勝の年末で、左の「勇退する」を1回タップ → retiredAfterWin=true → careerOver になり saveNow がセーブを消す（1293行の guard）→ そのままエンディング。戻る手段・確認ダイアログなし。「続ける」を主ボタン（右）に置いて連打対策はしてあるが、左の副ボタンを誤タップした時の救済は無い。
- 直し方の案：「勇退する」を押したら「ここで終わります。よろしいですか？（はい／もどる）」の確認を1段挟む。または押してから数秒の「取り消す」。
- 判断が要るか：要る（確認を足すか＝操作の手数とのトレードオフ・オーナー決定）。

### #2 低｜優勝の翌年の独白に、優勝を無かったことにする行が残る
- 場所：YearResultView.swift:393-397（"去年と" だけ除外）／yeLeap の 441行「去年より、ずっと忙しい一年だった」・452行「去年の自分が見たら、驚くような一年だった」
- 再現：優勝（Y年）→続ける→Y+1年が準決勝止まり等で決勝に立たない年。fame≥30 なので躍進プール(yeLeap)になり（yearEndPool:367）、「去年の自分が見たら、驚くような一年」が出うる（去年は日本一）。除外した "去年と" は停滞プールの1行だけで、fame が高いと停滞プールにはまず入らない＝今回の除外はほぼ効かない（fame の減衰で<30になるかは未確認）。
- 直し方の案：前年優勝の時は "去年" を含む行を yeLeap からも外す（year<=1 の処理と同じ形：`!$0.contains("去年")`）。
- 判断が要るか：不要（表示だけ・外して空になる時は元のままにする既存の形で足りる）。

### #3 低｜玉座奪還(t20)を取れるようにしたことで、周回の点の実効上限が+2pt上がる
- 場所：Meta.swift:76（obtainable）／Meta.swift:201（MetaBook.points）／Meta.swift:209-213（式）／GameSession.swift:246
- 内容：t20 は 2pt（Meta.swift:17）。取れなかった間は到達できなかった点が加わり、次の周の初期経験点・所持金・伸びしろの上限（metaTopPoints 基準の式）が、全部集めた人で今までより高くなりうる。式の定数 metaTopPoints が「最大38」前提か「取れる分(36)」前提かは未確認。
- 再現：優勝→続ける→翌年負け→翌々年に優勝で t20 → MetaBook.points が+2。
- 直し方の案：metaTopPoints を最大38前提で置いてあれば変更不要。36前提なら38に合わせる（式なので「最大」エフォートの作業）。
- 判断が要るか：要る（バランス値＝オーナー確認。数式に触れる場合は golden 影響を見る）。

### #4 低（未確認）｜「勇退する」「続ける（N年目へ）▶」の2ボタン横並びが大きい文字で収まるか
- 場所：YearResultView.swift:489-495（HStack に2ボタン）
- 内容：「続ける（15年目へ）▶」は11文字。Dynamic Type 大・小さい端末で折返し／切れの可能性。a11y_large_text_check_1107_v0 は差分前の画面。実機・シミュレータでは見ていない＝未確認。
- 直し方の案：大きい文字の時だけ縦積み（ViewThatFits）。
- 判断が要るか：不要。

## 確かめて問題なしだった点（実コードで確認）
- 保存→復元：winAcknowledged は SaveData の Optional（旧セーブ＝nil→演出から）。saveNow は「finished かつ優勝」でのみ true を書く＝演出中(finished=false)は nil。復元は yearDone のみ分岐（GameSession.swift:284-292）で、init の復元では pump を呼ばない（呼ぶのは 253/351/384/963/973/1191行）＝復元で recordChampion/onYearEnd を再実行しない。勇退を選ぶと careerOver→セーブ削除、retiredAfterWin を保存しないのは問題なし（選んだ時点で消えるため）。
- 二度押し：retireAfterWin は canChooseRetire で守られ（2回目は無効）、startNextYear は `finished` で守られる。幕間を連打しても startNextYear は1回。
- 最終年／夜逃げ／解散との組み合わせ：最終年の優勝は careerOver が先に true＝選択なしでエンディング。続けた後の夜逃げ・解散は judge の #1/#2 が先に当たる。最終年に優勝歴があって今年は非優勝＝championPair/Retire（新規の行・年表は yearHistory に今年分が入っている）。
- THE HANA：outcome.champion は頂GP優勝のみ（winFinale を立てるのは GameSession.swift:1429 だけ）＝HANA優勝で選択画面は出ない。hanaReach は年ごとに log=[] で取り直し、通算は state.hanaWins＝二重計上なし。NotebookView.kirokuWins も年末の画面からは開けず、翌年は log が空。
- トロフィー／記録：didRecordChampion は startNextYear で戻す（連覇の2回目を取りこぼさない）。t20 は「streak==1 かつ過去に優勝」＝連覇では付かない。t18 は wonBefore で優勝歴ありを除外（yearHistory の今年分は `year != runner.year` で除く）。recordChampion の streak は yearHistory 末尾から数え、年ごとに1行のみ（`last?.year != runner.year`）。テスト TrophyHana1107Tests の obtainable=21 は差分後の値と一致。
- エンディング：endingID は選択中 nil＝EndingBook.record（EndingViews.swift:51・表示時）は選択中に呼ばれず、勇退／最終年の1回だけ。onEnding も選択中は nil。
- DEBUG 以外への影響：MZ_RECORDS は #if DEBUG 内。RootView の champion2/3・soakLoop・自動プレイ(GameSession.swift:1756以降)の retireAfterWin 呼び出しは #if DEBUG 内。本番の変更は winAcknowledged・canChooseRetire・retireAfterWin・winHeadline・repeatWinLine・UI のみ。
- 台詞：repeatWinLine／FinalsPresentationView の「また、勝ったんだね」は `$0.year != 今年` で今年分を除いて判定（yearHistory に今年が入っていても初優勝を連覇扱いしない）。

## 未確認
- #2 の fame 減衰（停滞プールに入る可能性）、#4 の大きい文字、幕間(YoseYearTurnCurtainView)のオーバーレイが下の「勇退する」へのタップを通さないか（実機未確認。型定義の場所も grep で見つからず未読）。
