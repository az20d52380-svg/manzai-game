# 未レビュー12ファイルの正しさ点検（2026-11-15 v0）

対象: StageScene / S6bView / NetaCatalog / GachaRatesView / Store/GachaStore（＋中で使う Store/GachaState）/ FinalsTalk / Store/AdProvider / FontLoader / JudgeData / MZSpeed / ChoiceEventEffect / RandomSource。
範囲: 正しさのバグのみ。編集・コミット・実機確認なし（読み取りと grep だけ。実行はしていない）。既知2件（無料券先消費・【仮】表示）は除外。

## §1 指摘（計5件・クラッシュ級は0件・最も重いのは #1）

### #1 iCloud 合流で「開封済み回数」が最大値になり、複数端末で券が増える/戻る（重さ 中〜低・確信度 中）
- 場所: Store/GachaState.swift:183（totalPulls）・:194（paidOpened）。呼び出しは GachaStore.swift:20, 39（merged）。
- 何が起きるか: 台帳（ledger）は取引IDごとの和集合なのに、開封数 paidOpened は端末ごとの累計を max で合流する。別端末で別々に回した分が足し算にならず、片方の開封が「無かったこと」になって未開封（paidPending＝付与−開封）が実際より多く見える。
- 手順: 端末Aで10回券を買って10回開封（paidOpened=10）→オフラインの端末Bで別の10回券を買って4回開封（paidOpened=4）→合流。ledger=20・paidOpened=max(10,4)=10 → 未開封10。実際の残りは6なので4回ぶん多く回せる。逆向き（課金した人が損をする向き）は起きない＝過剰付与の向き。
- 同じ構造: freeTickets は newer 側を採るだけ（:187）。新端末で iCloud が同期される前に「はじめての1回」を回した場合、2端末が各1回ぶん特別を引ける（totalPulls も max）。
- 備考: 設計上の割り切り（コメントに「増える一方の値は大きい方」）の範囲。直すなら開封も取引ID単位（ledger と同じ形）で持つ。収益側は損をしない向きなので優先度は低め。

### #2 端末の日付を未来に一度でも進めると、ログインボーナスが以後ずっと取れない（重さ 低・確信度 高）
- 場所: GachaState.swift:159 canClaimLogin（`today > lastLoginDay` の文字列比較）・:163 lastLoginDay = today・:189 merge は「後の日」を優先。
- 起きる手順: 端末日付を 2099-01-01 にして札を取る → 日付を戻す → 以後 today が lastLoginDay より前なので取れない。iCloud 合流も後の日を採るので他端末にも伝わり、元に戻らない（自力で直す手段なし）。
- 備考: 「日付が戻された時は取れない」は意図した仕様。ただ誤設定・タイムゾーン跨ぎの一時的な進みでも固まる。上限（例: 実時刻+1日超は無視）の有無はオーナー判断。

### #3 GachaStore が両方壊れた/読めないデータで黙って初期化する（重さ 低・確信度 低）
- 場所: GachaStore.swift:31-34 decode（デコード失敗→`GachaState()`）。
- 何が起きるか: JSON が壊れている/将来のスキーマで読めない場合、ledger（有料券の台帳）・owned が空の新規状態になり、次の mutate の persist で端末側・iCloud 側とも上書きされる。cloud が有効で片方が読めるなら merged で復元されるので、両方失敗した時だけ。再現は難しい（現状のエンコードは自前の encode で安定）。

### #4 AdGate の completion に「必ず1回だけ」の保証がない（重さ 低・確信度 中・現状どの画面にもつないでいない）
- 場所: AdProvider.swift:33-37。
- 何が起きるか: 実 SDK を差した時に、広告が表示に失敗して completion が呼ばれない（画面が先へ進めない）／二重に呼ばれる（結果画面の遷移・週送りが二重実行）可能性。タイムアウトも1回限りの保護もない。NoAdProvider は即時なので今は無害。つなぐ時に必要。

### #5 MZSpeed.sleep はキャンセルで throw するが、呼び出し側が try? で握りつぶしている箇所がある（重さ 低・確信度 中）
- 場所: MZSpeed.swift:11（helper は正しい）。呼び出し側の例: FinalsPresentationView.swift:279-281（`.task(id: autoKey)` の最初の sleep のあとに Task.isCancelled の確認なしで `doorsOpen = true` と Haptics.confirm()）。
- 何が起きるか: autoKey が変わって task が取り消されると、sleep が即 return し、前の拍の続き（扉が開く・ハプティクス）が1回余計に走る。見た目の一瞬のずれ。ほかの呼び出し（WeekMainView の .task、FinalsBroadcastIntro）は isCancelled を見ているので問題なし。
- 注: 対象外ファイルの話なので参考扱い。

## §2 問題なしと確かめた点
- RandomSource.swift: SplitMix64 は &+ / &* の wrap 演算で桁あふれのクラッシュなし。nextUniform は上位53bit÷2^53 で [0,1) を外さない（1.0 にならない）。Codable は state だけを保存＝再開で列がずれない。uniform(in:) も乱数1回だけ消費。
- ChoiceEventEffect.swift: 全ケース RNG 非消費。clamp は ability/mental/compat/stamina/fame/rift で上下限あり。growthBudget が nil の時は no-op、負の下限は0。weakestSkillPlus の min は配列が固定4要素で nil にならない。money だけクランプ無し（Int 溢れは現実の額では起きない）。
- GachaStore/GachaState: pull(count:) の呼び出し（GachaView:150/154/156）は 0 以上のみ＝`0..<count` の負数クラッシュなし。購入付与は取引IDで冪等（credit は ledger[txID] 既存なら false）。pullOne の券消費は free→paid の順で paidOpened は増えるだけ。pity は交換で40引くだけで負にならない。StoreManager.handle は revocationDate 付きでは付与しない。Notification の observer は [weak self]・main で受ける。
- S6bView: `Self.venueNames[venueTier]` の tier は 0..3 に収まる。onAppear の Task は reduceMotion 時のみで、遅れて counted を立てるだけ（画面外でも無害）。phase の enum は Equatable で .animation(value:) 可。DustField の period は size.height+40>0 で割り算安全。
- StageScene: GeometryReader の割り算なし・Canvas の loop 範囲固定・force unwrap なし。
- NetaCatalog: autoKata/autoName は負の id でも ((id%n)+n)%n で範囲内。affinity は欠けても "○" にフォールバック。審査員名は JudgeTalk.judgeNames と一致、型7種を全て網羅。
- GachaRatesView: 表示割合は GachaCatalog から生成。切り捨て表示の合計は 100% を超えない。ForEach の id は重複しない（文面固有・enum）。
- FinalsTalk / JudgeData: split.first は Substring フォールバックあり。stars は max(1,min(5,…)) で範囲内（NaN が入らない限り）。
- FontLoader: PostScript 名（RoundedMplus1c-Black/ExtraBold/Bold/Medium）を mdls で4ファイルとも実在確認。登録失敗は continue で無害。
