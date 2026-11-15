# クラッシュ監査 2026-11-15（v0）

対象：ManzaiGame/Sources と GameCore/Sources（DEBUG・MZ_*・テストは除外）。読むだけ・コードは未変更。
結論：**「普通の遊び方で落ちる」指摘（重さ＝高）は0件。** 中も0件。低（理屈だけ・定数や不変条件に依存）が4件。

## §1 指摘（すべて低）

### 1. TournamentResultView.swift:52　`summary.results.last!`
- 危ない値：`summary.results` が空の WeekSummary が表示に渡った時。
- 経路：GameSession.swift:1405 は `big`（大会結果）が非空の時だけ pendingResult を作る（コメントどおり）。ただし pendingResult はセーブにも入る（GameSession.swift:298 で復元）。通常は非空のものしか保存されないので、壊れたセーブ・手編集・将来の別経路でのみ落ちる。
- 重さ：低／確信度：高（不変条件で守られている）
- 直し方：`private var result: StageResult? { summary.results.last }` にして nil なら閉じる、または復元時（:298）に `results.isEmpty` の pendingResult を捨てる1行。

### 2. ShopView.swift:73,119　`session.config.roomRents[i]`（i は `roomNames.count` ＝3 まで）
- 危ない値：config.roomRents が3要素未満になった時。既定は `[0, 50_000, 150_000]`（GameConfig.swift:282）で一致している。
- 重さ：低（定数どうしの結びつき）／確信度：高
- 直し方：`i < config.roomRents.count` のガード、または ForEach を `roomRents.indices` に。

### 3. GameEngine.swift:227　`config.offersNamed[(isMoney ? 2 : 0) + sub]`
- 危ない値：offersNamed が4件未満。既定は4件（GameConfig.swift:329）。
- 重さ：低／確信度：高
- 直し方：`guard config.offersNamed.count >= 4 else { return nil }`。（乱数の消費順は変えないこと＝ガードは乱数を引いた後ろに置く）

### 4. WeekRunner.swift:130　`precondition(year >= 1)`
- 呼び元は `year: 1`（GameSession.swift:253）と `year + 1`（:1171）だけ。year が0以下になる経路は無い。復元セーブの year が0・負だと落ちるが、Codable で正の値しか書かない。
- 重さ：低／確信度：高
- 直し方：復元側で `max(1, year)` に丸める（precondition は仕様のまま残してよい）。

## §2 問題なしと確かめた主な所（届かない理由つき）

### Double→Int
- GameEngine.swift:183（livingCost×定数）・:240（`Int(nextUniform*count)` を `min(count-1, …)` で頭打ち。nextUniform は 53bit÷2^53 で1.0未満）／GameSession.swift:637 も同じ形で頭打ちあり。
- ChoiceEvent.swift:398 `Int(state.compat)`：compat は `compatCap=20` で clamp 済み。NaN になるのは compatCap=0 の時だけ（GameEngine.swift:299 の 0除算）が、既定は 20.0 の定数。
- 画面の `Int(x.rounded())`（体力・知名度・完成度・能力値・実力：NotebookView／WeekMainView／NetaSelectionView／RadarChart／AbilityUpView／TournamentResultView／RootView 他）：体力は0〜100、能力・完成度は clamp(0,100)、知名度は有限で小さい（15年・加算のみで Int 範囲に届かない）。0除算を含む式は無い。
- DialogueData.swift:55,62：`fame.isFinite` ガードあり。
- FinalsPresentationView.swift:1215 `Int((-m-4)/3)`：margin は有限値の差。`min(10,max(4,…))` で頭打ち。:1245 は `max(50,min(99,…))`。
- YoseYearTurnCurtain.swift:435 `Int(man)`：`man == man.rounded()` を確かめた後で、値は yen÷1000（万円）。Int範囲内。
- RentStatement.swift:87 `Int(money)`：money は Int（GameState.swift:11）。お金の加減算は Int で、15年で桁あふれする額は無い。負の所持金も Int のまま安全。
- AbilityUpView.swift:429／:515,524：`rankBounds[i+1]` は `i+1 < count` を確かめてから。`Int(raw*10+1e-6)` の raw は能力値（0〜100級）。
- YearResultView.swift:593／YoseMilestoneFX.swift:268／SoundManager.swift:179／FinalistAnnounceView.swift:204／TournamentResultView.swift:403／WeekMainView.swift:1313：割る数・掛ける数は固定の定数（steps=20 等）。`Int(sec*20)` は `max(1, steps)` 付き。
- Meta.swift:219／GameState.swift:137 の `pow(P/定数, 指数)`：P は0以上で、割る数は config の定数（非0）。

### 配列・範囲
- 乱数で配列を引く所は全部、剰余か clamp：JudgeTalk（list は `!isEmpty` を確認後に `% count`。:158 は guard あり、:484 の judgeNames は定数の非空配列）／DialogueData（`pool.isEmpty` ガード・banter は `!pools.isEmpty`）／FanReportData:58,423（`n>0` ガード）／ChoiceEventData:54／NetaCatalog:36,55（NetaKata.allCases・names は定数の非空）／GachaState.swift:129（各段の着数は1以上：iro5・gara4・tokubetsu3）。
- GameSession.swift:718 `gpRoundsPassed..<gpRounds.count`：`isGPAlive`（gpStage < gpRounds.count）の中だけで回る＝lower ≤ upper。
- FinalsPresentationView：`judges` は specs 7件固定で `4..<min(7, 7)` は常に成立（:860）。`entries` は非観客=自組+9組＝10件・観客=10件。`entries[shown-1]` は `shown < entries.count` ガード後の `+= 1`（:469-472）／`shown>0` ガード（:608,970）。`orders[i]`：観客は myOrder=0 で1…10の10件残り、非観客は9件で names と同数。stride の `through: 1, by: -1` は空配列でも空範囲で安全（:1199,1279,1369,1404）。FinalistAnnounceView.swift:49 の `nx() % (i+1)` も同じ。
- GameCore の `roomHeals[room]`（GameEngine.swift:162／WeekRunner の同等箇所）は `room < count` ガードあり。`roomRent` は `r < roomRents.count`。`canMoveRoom` は `target < count` を先に確認。`gpLossCompat[gpStage]` は `< count` ガード（WeekRunner.swift:273）。
- netas の `[i]` は `firstIndex(where:)` や `indices` から得た添字（WeekRunner.swift:537-560）。ネタ0本でも nil で何もしない。`rest.remove(at:)`（GameEngine.swift:240）は `!rest.isEmpty` ガード。
- GameSession.swift:140 `removeFirst(count-600)` は `count>600` の時だけ。
- Calendar／週・年を添字にする配列は無い（`categoryLog[w]` は辞書）。15年目の最後でも年・週で配列を引く所は無い。
- Theme.swift:139 は `lastIndex` が nil なら guard で抜ける。

### 強制アンラップ・fatalError など（非DEBUG）
- `!` は5箇所のみ：上の指摘1、GachaView.swift:154 の `plan!`（`.paid1/.paid10` の case の中＝非nil）、GameEngine.swift:281 `second!`（直前の `second == nil ||` の短絡で安全）、JudgeTalk.swift:142 `vocab[nil]!`（static 定数に nil キーがある）、GameSession.swift:1920 の `try!`（DEBUG の目視フック内＝対象外）。
- `as!`・`fatalError`・`try!`（非DEBUG）は0件。`precondition` は指摘4の1件のみ。
- `stride(by:)` は by が定数（0.25／22.5／-1／28）で0にならない。

### 0除算・剰余
- Int の `%` の右辺：`livingInterval`（config 既定4・非0）、`count` 系は直前に `> 0` かプール非空を確認、色配列（`colors[i % colors.count]`）は定数の非空配列。YoseEffects は `max(1, count)` 付き。
- Double の割り算は 0除算でも inf/NaN になるだけで落ちない。そのまま `Int()` に渡る経路は上の「Double→Int」で確認済み。

## 備考
- 落ちやすさの上位は、いずれも「定数配列の長さ」や「画面に渡す値の不変条件」に頼っている所（指摘1〜3）。直すなら指摘1（セーブ復元時の pendingResult 検証）が最も実害に近い。
- 実機・シミュレータでの再現はしていない（コード読みのみ）。
