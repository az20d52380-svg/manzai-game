# コード点検 11/07（Meta・Gacha・FirstStage・THE HANA・ComboKind・経験点の行）

| # | 場所 | 何が起きる | 重さ |
|---|---|---|---|
| 1 | GachaState.merged（paidPending = max） | 端末Aが購入分を回し終えても、同期前の端末Bに未開封が残っていると合流で戻り、1回の購入が二重に回せる（Aへも書き戻る）。新しい側を採ると古い側の購入が消えるため、通算の購入数／通算の使用数を別に持つ形式への変更が要る | 中（判断が要る） |
| 2 | GachaState.merged（かけら・天井の交換） | 交換は回数（totalPulls）が増えないので、古い側の残高が採られ交換後の残高が戻り二重に使えた → 持ち物の数も新旧判定に加えて**修正済み**（テスト testMergeDoesNotRefundExchangedShards） | 中（直した） |
| 3 | GachaState.canClaimLogin（today > lastLoginDay） | 時計を戻しても取れないのは正しいが、一度未来の日付で取ると lastLoginDay が未来になり、時計を戻すと実日付まで取れない（iCloudで他端末にも伝わる）。進めて何度も取る不正は端末時計だけでは防げない | 低（判断が要る） |
| 4 | GachaView.run（.paid1/.paid10） | 無料券を持っている時に購入すると、先に無料券から消費され、買った分が未開封に残る。損は無いが、押した直後の表示と回数が合わない | 低 |
| 5 | GachaView（.pending の購入） | 承認待ちの購入は後で Transaction.updates から付与されるが、画面の「未開封」案内は開いた時だけ更新される（残数の表示自体は即反映） | 低 |
| 6 | TournamentResultView.expGainRow | 5種＋合計＋「負けても入る」が1行（縮小0.7まで）。幅が狭い端末では全部入ると小さくなる | 低 |
| 7 | MetaBook／TrophyBook | 周回の点は GameSession 新規作成時に1度だけ読む。もう一度・解散後も二重加算なし。復元は pump を通らず recordChampion／bump の二重なし。T19・T20 は未配線（obtainable=false で明示済み） | 問題なし |
| 8 | THE HANA | femaleCombo は comboKind==.femaleFemale のみ（男・男女は出ない）。旧セーブは Optional で nil=男コンビ | 問題なし |
| 9 | 黒紋付 | owns は isAdFree に連動し、未所有の着用は standard に戻る | 問題なし |
| 10 | ％表示・関西弁・実在名 | ％は GachaRatesView のみ。追加差分に関西弁・実在の大会／事務所名なし | 問題なし |
| 11 | 乱数 | ガチャは SystemRandomNumberGenerator で本編 RNG と別 | 問題なし |
| 12 | セーブ形式 | 周回の保存は別キー（UserDefaults）。SaveData に今回の追加なし＝旧形式のまま開ける | 問題なし |

高：なし。判断が要る：#1（形式変更）、#3（時計の扱い）。
