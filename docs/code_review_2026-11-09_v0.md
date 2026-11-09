# コード点検 11/09（10/28 以降の差分）v0

対象：`git diff 8d88df35 HEAD -- ManzaiGame/Sources GameCore/Sources`（52ファイル・+2265/-324）。台詞の良し悪しは見ていない。DEBUG フックは軽く見ただけ。
確認：`cd GameCore && swift test` → **Executed 469 tests, with 0 failures**／`python3 tools/check_config_sync.py` → **80/80 一致**。アプリ側のテスト・sim は回していない（読んだだけ）。

## まとめ
- 件数：高 0／中 2／低 5（落ちる所・セーブが読めなくなる所・乱数の消費順の食い違いは見つからなかった）。
- 一番重いのは「ガチャの有料購入直後の抽選が先に無料券を使う」件（お金は失われないが、10回買って1回が「未開封」で残る）。
- 古いセーブ：GameState の追加項目（metaPoints／femaleCombo／hana*）は全部 Optional、SaveData の追加も全部 Optional、Skill／ChoiceEventKind／categoryLog の寛容な復号も形が合っている＝読めなくなる所なし。

## 指摘の表
| # | 重さ | ファイル:行 | 何が起きるか（再現の条件） | 直し方の案 |
|---|---|---|---|---|
| 1 | 中 | GachaView.swift `run(_:)`（.paid1/.paid10 と nil の枝）＋ GachaState.swift `pullOne` | 無料券を持ったまま「10回 ¥1,000」を買うと、`pull(count: 10)` は無料券から先に消費する＝有料9回分しか開封されず、有料1回分が「未開封の1回を回す」に残る。「未開封のN回を回す」でも同じ（無料券が先に減る）。お金・回数は失われない（推測：実機未確認） | 購入直後と「未開封」では有料分だけを引く専用の入口（free を飛ばす）を作る。または文言で「無料券が先に使われます」と出す。判断が要る |
| 2 | 中 | GameConfig.swift `careerYears = 15`／GameSession.swift:`careerOver`（`year >= careerYears`） | 10→15 年。10年目の途中や年末（旧では「十年で区切り」の画面）で中断した旧セーブは、復元後に勇退せず11年目へ続く（セーブは読める・落ちない）。図鑑に既にある「十年」系エンディングの本文は十五年に変わる | 判断が要る（旧セーブをどう扱うか／出荷前なら無視してよい） |
| 3 | 低 | NotebookView.swift:181（`kirokuWins`）＋ GameSession.swift の yearHistory 追加（`smallWins`） | 年末（yearDone 後〜次の年へ進むまで）に手帳を開くと、今年の優勝が「今年の記録の優勝」と「yearHistory の champion／smallWins」の両方で数えられ、通算優勝が今年分だけ二重になる。GP優勝は 10/28 より前から同じ形（推測：表示だけ・実機未確認） | `marks` から「頂GP」を除く・今年分の yearHistory を引く（年が yearHistory に入っている間は今年の記録を数えない） |
| 4 | 低 | GameSession.swift `didRecordChampion`（SaveData に無い） | pump が復元後に同じ yearDone へ再入する経路があれば `TrophyBook.recordChampion`（通算優勝・最多連覇）が二重に積まれる。今の復元は phase を直接立てて pump を通らないので起きない（推測：将来の変更で顕在化） | SaveData に `didRecordChampion: Bool?` を足す、または recordChampion に年の重複ガード（`lastRecordedYear`） |
| 5 | 低 | GameSession.swift:~718（StageInfo の決勝ライン）と WeekRunner.swift:166 | 画面の「頂GP 決勝」ラインは `gpFinalLine + gpLateBonus` を別計算で出している。今のアプリは `finalLineOverride`（王者ライン）を使っていないので一致するが、使い始めると表示だけずれる | runner の `finalLine` を読む形に1本化（将来の話） |
| 6 | 低 | Store/StoreIDs.swift（`costume.hakama`／`leopard` を削除） | 旧の衣装課金（非消耗型）を購入済みの端末があれば、その衣装が消えて標準に戻る（`StageOutfit.current` は未所有なら standard）。未出荷なら無関係 | 判断が要る（出荷済みの購入者の有無） |
| 7 | 低 | IntroFlow.swift `charSize`（縦札の字の大きさ） | `(height-26)/n-2)/1.3` は札の高さが小さく名前が極端に長いと0や負になりうる。今の札は高さ150・名前は短縮済みで実害は出ない（推測） | `max(10, …)` の下限を足す |
| 8 | 低 | GachaView.swift `.task`（`pendingNote` を立てるだけで読まれていない） | 未使用の @State（見た目に影響なし） | 消すか、未開封があれば一言出す |

## 問題なしと確かめた主な所
- GameCore：THE HANA の週（32/37/42/44）は道中大会（12/15/27/29/35/38/46）・GP（30/39/41/43/45/47）と重ならず、`tournament(inWeek:state:)` で男コンビには出ない。`hana` の通過記録（hanaYear/hanaNext）は年ごとに正しく戻る。大会の経験点・周回ボーナス・11年目以降の予算の式は Python（`tourney_exp`・`late_growth_factor`）と順序・係数が一致（check_config_sync 80/80・golden を含む 469 テスト通過）。数値の直書きは GameConfig／CalendarConfig 内だけ。
- セーブ：`winAcknowledged`（優勝の演出の途中で閉じた復元）・`smallEntered/smallWon`・`week = min(…, cfg.weeks)`・GachaState の旧形式（paidPending→ledger "legacy"）の変換は、既定値の抜けなし。`decode(Set<ChoiceEventKind>)`／`[Int: BandCategory]` は書き出しの形と合っている。
- 画面の状態：FirstStageView（task の取り消し・二度押しガード・VoiceOver 時は自動で押さない）、AbilityUpView の確定（`confirmFinished` で反映は1回）、FinalsPresentationView の `voteTailTask` の取り消し、WeekMainView のオファー札を `enumerated` に変えた範囲外の修正は問題なし。
- 課金：`handle` は付与→finish の順で取引ID重複を台帳で防ぎ、払い戻しは付与しない。`Transaction.updates` の再配信でも二重にならない。ガチャの提供割合表示は切り捨てで合計100%を超えない。
- 文言：新規・変更の文に実名・ゲーム外の固有名なし。一人称の直書きは話者ラベル（`name: "俺"`・既存の作法）だけで、本文は `{me}`／`Names.partner` を通している（NotebookView の「相方」も Names.partner に直っている）。

## 親の照合（11/09 夜）
- #1 確認：GachaState.pullOne:105 は無料券を先に使う＝指摘どおり（AUTOPILOT 229・判断待ち）。
- #3 取り下げ：年末（finished）の間は RootView:403 で YearResultView に替わり、NotebookView は WeekMainView:167 からしか開けない＝本編では二重に数えない。
- #7・#8 は直した（0bcb6286 の1つ前のコミット）。
