# 衣装（ガチャ・着せ替え・反映・ログインボーナス）の流れの点検（2026-11-15 v0）

- 要点1：新しい指摘は4件（中1・低3）。クラッシュ・台帳の消失・効果の説明違いは0件。持っている衣装は台帳（GachaState.owned＋黒紋付は StoreManager）から毎回引くので、次の周・中断復元・iCloud 合流の後も表示と台帳は一致する。
- 要点2：一番重いのは「着た衣装が毎週見る稽古場（週メイン・入口・イベントの背景）に出ない」（#1）。反映されるのは大会の舞台（StageFrame）だけで、ガチャ画面のどこにもそれが書かれていない。
- 要点3：衣装に能力・知名度の効果はなく、画面にも「見た目だけ」と書いてある（ガチャ画面・お店・提供割合ページ）＝一致。ログインボーナスは日付またぎ・時刻戻しで固まる穴は無く、前進の悪用・タイムゾーンの取りこぼしが低で残る。

節構成：§1 指摘（#1〜#4）／§2 既出（grep で確認）／§3 問題なし。
読んだ範囲：Store/GachaState・GachaStore・StageOutfit・StoreManager、GachaView、GachaRatesView、StageFrame、StageScene、ChoiceEventOverlay、IntroFlow、ShopView。コードは直していない・ビルドなし。

## §1 指摘

### #1 着ている衣装が稽古場（週メイン・入口・イベント）に出ない（重さ 中・確信度 高）
- 場所：StageScene.swift:74,76（`StageOutfit.standard` 固定）。同じ固定が ChoiceEventOverlay.swift:386,388,434,436。反映するのは StageFrame.swift:135（`StageOutfit.current`＝大会の本番・結果・初舞台）だけ。StageScene は WeekMainView:546（毎週の主画面）・StageViews:129（大会前の入口）・ChoiceEventOverlay:353 で使われる。
- 起きる手順：ガチャで「豹柄」を出して「着用中」にする→週の画面に戻る→二人は標準の青と赤のまま。大会の本番に行って初めて着替えが見える。ガチャ画面・お店は「舞台の衣装」としか書いておらず、どの画面に出るか分からない。
- 直し方の案（判断が要る）：①稽古場（StageScene）も `StageOutfit.current` にする（毎週見える＝ガチャの手応えが出る・既存の人形の色セットをそのまま使える）。②今のまま、ガチャ画面に「大会の本番の舞台に出ます」と一行足す。推奨①（ただし俺＝青・谷口＝赤の識別が週画面の見やすさに効いていないかは目視が要る。標準の新規イントロ IntroFlow:309,311 は standard のままでよい）。

### #2 「着用中」の札が、所有の変化に追いつかない（重さ 低・確信度 中）
- 場所：GachaView.swift:15（`@State wearing = StageOutfit.current` は開いた時の1回だけ）・outfitCell の `wearing == o && owned`。
- 起きる手順：黒紋付（広告カットの購入に付く）を着たままガチャ画面を開く→開いている間に払い戻しが届く（Transaction.updates→StoreManager.ownedIDs が外れる）→実際は `current` が標準に戻るが、画面は黒紋付が「？」のままで、どの衣装にも「着用中」が付かない。起動直後に StoreKit の読み込みが遅い場合は逆（`current` が一瞬標準→画面を開いた時に標準を「着用中」と表示→読み込み後に黒紋付へ戻る）も理屈では起きる（キャッシュ `store_owned_ids` があるので通常は起きない）。
- 直し方の案：`wearing` を持たず、各セルで `StageOutfit.current` を引く（`store.ownedIDs` の変化で再描画される）。

### #3 着ている衣装は iCloud に載らない（重さ 低・確信度 高）
- 場所：StageOutfit.swift の `wear`（UserDefaults のみ）・GachaRatesView の「衣装・かけら・ポイントは iCloud に保存され、機種変更でも引き継がれます」。
- 起きる手順：機種変更・再インストール→所有（owned）は iCloud から戻るが、着用は標準に戻る。説明の文言は所有の話だけなので嘘ではない。実害は「着直す1タップ」。
- 直し方の案：①今のまま（据え置き）②GachaState に `wearing` を足して合流（Codable の既定値付きで旧データ互換）。推奨①。

### #4 ログインボーナス：時刻の前進で連取り・タイムゾーン移動の取りこぼし・日付またぎで札が古いまま（重さ 低・確信度 高）
- 場所：GachaState.swift:154 dayKey（`Calendar.current` の端末日付）・:159 canClaimLogin（`today > lastLoginDay` の文字列比較）・GachaView.swift:74（`today` を body 内で計算）。
- 起きる手順：①端末の日付を1日ずつ進めて毎回取ると7日ぶんが数分で無料1回に替わる（設定で時計を進めるだけ・戻すと取れなくなる＝既出 #2 の逆側）。②東へ移動して日付が進むと24時間以内に2回取れ、西へ移動して日付が戻ると1日ぶん取れない。③ガチャ画面を開いたまま0時をまたぐと、画面が再描画されるまで「今日の札はもらいました」のまま（押せない）。閉じて開き直せば直る。
- 直し方の案（判断が要る）：①今のまま（無料の券は1日1枚の弱い仕組み・課金の収益に影響しない側）。②最後に取った実時刻も持ち「24時間未満は取れない・日付も進む」の両方を要求する。③0時をまたいだら再描画（`.onReceive(NotificationCenter ... .NSCalendarDayChanged)`）。推奨①＋③。

## §2 既出（grep で確かめた）
- 無料券を先に使う（有料10回を買うと有料1回分が「未開封」に残る）＝AUTOPILOT 229・code_review_2026-11-09 #1・storekit_edge_audit_1108 #15。派生：未開封が残る時の「未開封のN回を回す」ボタン（GachaView.swift:124 run(nil)→pull(count: paidPending)）も、無料券を持っていれば先に1回ぶん使うので、押した回数と減る有料分がずれる（同じ根）。
- 【仮】印が遊ぶ人に見える＝AUTOPILOT 142。
- 台帳が読めない時に空で上書き＝code_review_unreviewed_1115 #3・AUTOPILOT 463（候補ブランチ待ち）。
- iCloud 合流で paidOpened／freeTickets が端末ごとの足し算にならない＝code_review_unreviewed_1115 #1。
- 日付を未来に進めると以後ずっと取れない＝同 #2・AUTOPILOT 464 #4。
- 旧の衣装課金 ID の削除＝AUTOPILOT 231・code_review_2026-11-09 #6。
- 未使用の `pendingNote`＝code_review_2026-11-09 #8（今のコードでは見当たらず＝直済の可能性）。
- 台帳の肥大・`_set` 行の本番残り＝storekit_edge_audit_1108 #4・#18。

## §3 問題なし（1行ずつ）
- 持っている衣装の表示：GachaView の closet は `gacha.owns`（standard 常時・黒紋付は isAdFree・他は owned）＝台帳そのもの。
- 着ている衣装が台帳から消えた時：`StageOutfit.current` が未所有なら standard に戻す（OutfitScene1109Tests が全衣装で確認）。保存値は残るので所有が戻れば元の衣装に戻る。
- 次の周（解散・やり直し）：GameSession の削除は save・EndingBook のみ（GameSession.swift:1043,1862,1945）。衣装・ガチャの鍵 `gacha_state_v1`・`stage_outfit` には触れない＝残る（設定の文言「図鑑・衣装・購入は残ります」と一致）。
- 中断復元：衣装はセーブに含まれず別鍵＝復元で変わらない・消えない。
- iCloud 合流後の所有：`owned` は和集合で減らない（GachaState.swift merged）。合流で着ている衣装が消える経路なし。
- 効果の有無：衣装は OutfitColors（色・髪型）だけを返し、GameCore・能力・知名度・勝敗に接続なし。画面に「見た目だけ／強さや成績には関係しません」（GachaView:35・ShopView:30・GachaRatesView 「衣装ガチャとは」）＝説明と実際が一致。
- 舞台・結果・初舞台・決勝：StageFrame.duo が `StageOutfit.current` を毎回描画時に引く（FinalsPresentationView:116・FirstStageView:31・TournamentResultView:108）＝前の衣装が残る経路なし。客席観戦（spectator）は他組の色で自組の衣装を使わない（意図どおり）。
- 年末・共有カード・エンディング：年末（YearResultView）・ShareCard は人形を描かない（コンビ名・結果の文字だけ）。EndingViews の「二着の衣装」は固定の紋付・羽織の絵＝反映対象外で矛盾なし。
- 表示値：ログインの札の丸（`i < loginStamps`）・「残りN回」・かけら・天井（`min(pity, goal)`）は state の値そのもの。7枚で `loginStamps -= 7` と無料1回が同時＝取りこぼしなし。
- 同じ日の連打：`lastLoginDay = today` を更新して返すので同日2回目は false。ボタンも `can` で無効。
- 時刻を戻した時：`today > lastLoginDay` なので取れない（仕様どおり）。iCloud の「後の日を組で採る」合流で7枚目の二重取りも防がれている。
- 割合表示：GachaCatalog から生成・切り捨てで合計が100%を超えない。
