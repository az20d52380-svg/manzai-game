# コード点検：DialogueData / YoseMotion / YoseCatalog（2026-11-17・読み取り専用）
対象: ManzaiGame/Sources/DialogueData.swift, Design/YoseMotion.swift, Design/YoseCatalog.swift ＋ 呼び出し側（GameSession.pickIndex/banterBand、WeekMainView、Names）。
結論: 落ちる穴・乱数消費・女性形の男性語の生出しは見つからず（§確認済み）。状況と台詞のずれが中2・低2、動きが中1。

## 指摘
| # | 重さ | 場所 | 状態 → 結果 | 直し方の案 | 既知? |
|---|---|---|---|---|---|
| 1 | 中 | DialogueData.swift:55,215-216,208-213 / GameSession.swift:1435-1438 | 第47週（最後の大会）で負け→ justLostStage=true のまま第48週に入る。その週は nextMilestone=nil なのに「また落ちた。今年の残りの大会を数えておこう。」(連敗時) 「次の大会がいつか、確かめておこう。」(単発) が出る＝残りの大会は無い | innerVoice に nextMilestone==nil を見る分岐を足し、残り大会に触れる行（justLostSingle の「次の大会」、justLostRepeat の「今年の残りの大会」「次に出る大会」）を除いたプールを使う（YearResultView:386 の「来年」除外と同じ作り） | 新規（dialogue_score_1019h #43 は文体採点のみ） |
| 2 | 中 | DialogueData.swift:154-206（losing）／:59 | lossStreak≥2 なら justLost でない週にも losing プールを使う。「大会が近い。体調だけは気をつけよう。」(L160)「次の大会まで、毎日同じ時間に起きよう。」「次の大会の申込締切だけは確かめておこう。」が、次の大会が6週以上先・または今年もう無い週でも出る | losing も nextMilestone で絞る（weeksLeft>2 なら「近い」行を外す・nil なら「次の大会」行を外す） | 新規（dialogue_score_1019 L22 は採点のみ） |
| 3 | 低 | DialogueData.swift:222-241（passedLines）/ :62 | 「次の会場」「次の本番に向けて」「次の交通費」等。通過直後に今年の大会が残っていない場合（noStagesLeft）に出うる。決勝通過＝優勝は別演出のはずなので実害は小さい | 要確認：決勝以外で「通過後に今年の大会ゼロ」になる配置が無いか実測。あれば #1 と同じ絞り | 新規・要確認 |
| 4 | 低 | GameSession.swift:690-697（banterBand）vs DialogueData.swift:44-53 | 閾値が不一致：掛け合い .broke は money<50,000、独白 lowMoney は <30,000。さらに掛け合いは体力<25・療養・justLost を見ない（連敗1回の翌週は .plain 等）。体力が低い週に「体力はつけておきたい」型の掛け合いが出うる | banterBand に stamina<25／recovery を入れて掛け合いを抑止（独白へフォールバック）。閾値は定数を共有 | 新規 |
| 5 | 低 | DialogueData.swift:58（fame）/ :62 / YearResultView:~398 | `Int(state.fame.isFinite ? state.fame : 0)` は有限でも |fame|≥9.2e18 で Int 変換がトラップ。現実の fame は小さく到達しない | `Int(max(-1e9, min(1e9, fame)))` に丸める | 既知（crash_audit_1115 / fame_audit_1115 系） |
| 6 | 中 | Design/YoseMotion.swift:43-50（YoseRowGlowModifier） | onChange 内で `glow = true` の直後に同じ処理内で `withAnimation { glow = false }`。描画されるのは最終値(false)だけ＝光が一度も見えない。現状はアプリ本体からの呼び出し無し（Catalog のみ）なので実害は見本の死んだ動き | YoseExpPing と同様に `glow = true` → `DispatchQueue.main.async { withAnimation { glow = false } }` にする（または phaseAnimator） | 新規（code_review_2026-10-19l は bounce 側のみ） |
| 7 | 低 | Design/YoseMotion.swift:34,81 | asyncAfter の `bump=false` をキャンセルしない。0.08秒以内に値が連続変化すると、先の戻しが後の跳ねを早く消す（見た目が一瞬欠けるだけ・落ちない）。表示のみ | Task を保持して cancel、または無視でよい | 既知寄り（stale_timer_audit_1115 / delayed_callback_audit_1108 の同種） |
| 8 | 低 | GameSession.swift:128-134（pickIndex）/ セーブ:1296 | stablePicks は保存されない（usedPicks のみ保存）。週の途中でセーブ復元すると、その週に既に「使用済み」に入った行を避けて別の行が出る＝再開で独白が差し替わる。乱数は不使用・golden 無影響 | stablePicks も任意で保存（key,idx）。軽微なので放置も可 | 既知寄り（save_restore_audit_1115） |

## 確認済み（問題なし）
- 配列範囲外：pick/banter/reaction/choose はすべて `((salt%count)+count)%count` か picker 経由。pickIndex は count>0 ガード、`used` を `<count` で絞り、プール尽きは used.first で循環。空プールは pick/choose/banter が guard。reaction のプールは空配列なし・未登録 ID は1行フォールバック。負の salt は剰余補正済み（`&+` でオーバーフローも回避）。
- 強制アンラップ：DialogueData.swift に `!` の強制アンラップ無し。
- 乱数：DialogueData は乱数 API を一切呼ばない。picker は GameSession.pickIndex（usedPicks/stablePicks は @ObservationIgnored の辞書操作のみ）＝GameCore の RNG 非消費。banter の発火は week ガード（lastBanterRollWeek）で1週1回・年替わりでリセット。
- 年前提：独白の「今年」「来年」は DialogueData 内に「今年の残りの大会」(#1) と谷口の弟の話（L443「来年こっちで働く」＝人物の事情で career 年とは無関係）のみ。年末独白の最終年「来年」除外は YearResultView:386 で対応済み。10年/4月前提の数字は DialogueData に無い（コメントのみ）。
- 女性形：DialogueData 内の台詞に生の「俺」「僕」「だぜ」「おまえ」等は無い（話者名 name:"俺" とコメントのみ）。一人称は {me} 経由（20箇所）。話者札の「俺」「谷口」は Text(String) の Names.show を通る（YoseSpeechBox は Text(text)/Text(speaker)＝Names.show 経由）。
- YoseMotion/YoseCatalog：乱数・ゲーム状態の読み書き無し。StampImpact の触覚は isStamped が true になった時のみ、reduceMotion 分岐あり。Catalog は DEBUG 専用の静的見本。
