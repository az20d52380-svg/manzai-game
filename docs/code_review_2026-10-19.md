# コードレビュー 2026-10-19（93b9512^..HEAD の ManzaiGame/Sources・GameCore/Sources）

**要点3行**
1. 確実2件・たぶん3件・要確認4件。セーブ互換（新フィールドは全部 Optional／スナップショットも nil 既定）と規律A（乱数の追加消費は rollOffer の1回だけで Python と同順）は問題なし。
2. いちばん重いのは「お店の『戻す』が部屋の引っ越しまで巻き戻す」（§1-1）。次点は「やりくり上手を覚えると生活費の画面表示が実額と食い違う」（§1-2）。
3. 部屋は家賃が「月末週にいる部屋」だけで決まるため、月末の週だけ安い部屋に戻れば体力回復の恩恵をほぼ家賃なしで受けられる穴がある（§2-1）。

**節構成**：§1 確実／§2 たぶん／§3 要確認／§4 見たが問題なかった所

> 【10/19 反映】§1-1・§1-2 を直した（次のコミット）。§1-1 は定期タスクの回でシミュレータのタップが使えず、押しての確認は未（オーナーが戻った対話の回で「引っ越し→買う→戻す」を確かめる）。§2 はどれも仕様の判断が要る＝判断待ちへ。

## §1 確実

1. **「戻す」で部屋の引っ越しが黙って巻き戻る**
   - ShopView.swift:13-14,37,170 ＋ WeekRunner.swift `replayItemPurchases`（state = start に戻して購入だけ再生）
   - 入力：店に入る（room=nil）→「マンション」へ引っ越す（moveRoom は state.room を直す）→栄養ドリンクを買う→「戻す」。結果：start（room=nil）に戻され、購入を再生するだけなので room も nil に戻る。画面は「いま住んでいる」がボロアパートに戻り、引っ越しだけ消える。逆に上の部屋から下げた後に戻すと家賃上乗せが復活する。
   - 直し案：replayItemPurchases の後で `state.room = 戻す前の room` を入れ直す（または visitStart.room を引っ越しの度に更新）。

2. **特技「やりくり上手」を覚えると生活費の表示が実際の引き落としと合わない**
   - GameSession.swift:347（lastLivingPaid）、WeekMainView.swift:482（WeekHint の livingCost）・:1217（RentStatement）・:1421（用語ヒント）
   - 実際は GameEngine.applyWeekEnd で `livingCost×0.95`（140,000→133,000）＋部屋の上乗せを引くが、表示側は `config.livingCost + roomRent` 固定。結果：支払い明細の合計が7,000円多く出て「支払い前の所持金」(moneyAfter+livingCost) も7,000円多く表示、Beat2 の収支（lastMoneyDelta）も7,000円過大。再来週の予告・用語ヒントの万円表記もずれる。
   - 直し案：`GameEngine.livingCostPaid(state, config)`（スキル込み）を1つ作り、表示側の4か所すべてでそれを使う。

## §2 たぶん

1. **部屋の家賃は月末週にいる部屋だけで決まる＝月末だけ下げれば回避できる**
   - GameEngine.swift `applyWeekEnd`（roomRent(s) を week%4==0 で読む）＋ canMoveRoom / moveRoom（お金を引かず、下げは常に無料）
   - 入力：150,000円持ってタワーに引っ越し→週1〜3は完全休養で回復+20・メンタル+1→月末の週頭にボロアパートへ戻る→家賃上乗せ0。毎月繰り返すと家賃なしで「3/4の休みは最高の部屋」。Python 側（balance_sim の ROOM_*）も同じ式なので実測が拾っていない可能性。
   - 直し案：引っ越しで当月分の上乗せ（または日割り）を即引く／下げた月は上乗せを払う、などオーナー判断。

2. **誘い「行く」は所持金・体力に関わらず選べる**
   - ChoiceEvent.swift:364（weekendInvite は gate なし）、GameSession.swift:700
   - 所持金3,000円でも「先輩と飲みに行く（5,000円）」を選べて -2,000円になる。借金可の仕様（夜逃げ線 -100万）なので破綻ではないが、他の飲み系イベント（0011 など）は金欠で出さない設計との整合は要判断。
   - 直し案：gate に `state.money >= config.inviteMoney` を足す、または仕様として許容する。

3. **誘いの発想フラグは保留中にアプリを落とすと失われる**
   - GameSession.swift:94-95（inviteWaiting／inviteIdea はメモリのみ）、:512（pendingChoiceEvent は保存される）
   - 入力：誘いの札が出ている状態で終了→再開。pendingChoiceEvent=.weekendInvite は復元されるが inviteIdea=false に戻る＝「行く」を選んでも発想+0.5が付かない（半分の確率の得を取りこぼす）。逆に札が出る前に落とすと誘い自体が流れる（コメントどおり許容）。
   - 直し案：許容するなら現状のまま。直すなら inviteIdea を GameSession のセーブに載せる。

## §3 要確認

1. **ChoiceEventOverlay の isFlavor（ChoiceEventOverlay.swift:49）**：`availableEventChoices().isEmpty` だけで「選択肢なしフレーバー」と判定。選択肢はあるが全部 gate で閉じているイベントがあれば、台詞を全部並べて1タップで閉じる。現行の全イベントで全閉じが起きるかは未確認（weekendInvite は両方開く）。直し案：`ChoiceEventTable.choices(for:).isEmpty` で判定。
2. **オファー受諾のプレビューにテレビ慣れが乗らない**：GameSession.previewState（:395-397）は applyOffer を atWeek なしで呼ぶため、センス・表現の -0.5 が予告に出ない（実際の受諾は WeekRunner が atWeek を渡す）。表示のみ。直し案：atWeek を渡す。
3. **部屋の引っ越しで夜逃げ方向に自分で進める**：上げる条件は「上乗せ1回分の所持金」だけ。タワーは上乗せ150,000＋生活費で4週ごと約29万の出費なので、150,000円ちょうどで引っ越すと次の月末で所持金が約 -14万。夜逃げ線 -100万までは数か月。意図なら問題なし、「あと¥」の案内文だけでは危険が伝わらない点の確認。
4. **古いセーブのオファー・誘い**：WeekRunnerSnapshot.inviteSeed が nil の旧セーブは、年が替わってもずっと誘いなし・札1枚のまま（startNextYear は runner.inviteSeed を引き継ぐため）。互換としては安全。新機能を旧セーブに出すかはオーナー判断。

## §4 見たが問題なかった所

- GameState の新フィールド（offerWeeks, riftJointWeek, skills, room）は全て Optional・独自 init(from:) なし＝旧セーブが読める。WeekRunnerSnapshot の inviteSeed／pendingInvite／offerChoices も Optional で保存・復元済み。pendingOffer の復元は offersNamed を含む名前引きに更新済み。
- 規律A：rollOffer の追加乱数1回（名前）は balance_sim.roll_offer に同じ位置で同期済み。誘い（rollInvite）・追加の札（extraOffers）は SplitMix64 の別系統で本編 rng 非消費、Python の invite_roll／extra_offers と式・定数（0xD1B54A32D192ED03・塩）が一致。injury 係数・特技の係数・部屋・GP 予選相性・GP ライン・寒梅漫才杯（週46）も Python と同値。ボットの acceptInvite 既定は true、golden 経路は inviteSeed=nil で不変。
- お金：購入は canBuy（money>=price・年回数）、引っ越しは canMoveRoom、特技は canLearn（全通貨が費用以上）で、マイナスにならない／二重に引かれない。喉のケア用品の回数は itemCounts が年初に消える（resetYearlyItems）ので年をまたいで残らない。回復ドリンク大・喉のケアは shopLineup に入り上限（4／1）あり。
- UI：特技の「覚える」は allocate で押した段を先に確定してから learnSkill（pv は preview 込みで判定）、強制アンラップ・配列範囲外は新規差分に見当たらない（offers.indices.contains／roomRents の添字ガード済み）。offerPick は週替わりで 0 に戻る。オファー札の選択は受諾直前に chooseOffer。
- 文言：新規の表示文字列（特技・誘い・部屋・体調ダウン・司会・購入復元）に％表記や実在名は無し（「吉竹興行」は架空）。
