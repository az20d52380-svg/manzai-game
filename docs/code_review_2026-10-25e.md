# コード点検 10/25e（アプリ更新後に古い中断セーブを読み込む時）

対象: `GameSession.SaveData`／`saveNow`／`init(restoring:)`、`WeekRunnerSnapshot`／`WeekRunner.init(restoring:)`、およびその保存値（添字・週・段・id・enum の rawValue・配列長）が使われる所。読むだけでコードは未修正。先例: 10/25d §2（gpStage、673f7a2 で丸め済み）。

## §1 結論
確度 高 は 0 件（先例と同じ「復元後に配列の外を指す」型は、残りを見た範囲では無い）。確度 中 は 4 件。うち最も危ないのは、保存に載る enum の case を消す／名前を変えると、セーブ全体が読めず黙って新規ゲームに戻る件（GameSession.swift:1227）。落ちはしないが、キャリアが消えて見える。
残りは `min`/`?? 0`/`filter { $0 < count }` で守られている。

## §2 確度 高（0 件）
なし。
- 確認した「保存した Int を添字・Range に使う所」はすべて守られている（§4）。

## §3 確度 中（4 件）
1. **GameSession.swift:1227-1235 `loadedOrNew` の decode 失敗 → 新規へ**（原因は各 enum）
   - 落ちる状態: 更新で、保存に載る enum の case を消す／rename すると JSON 復号が throw し、セーブ全体が読めない。対象: `ChoiceEventKind`（ChoiceEvent.swift:7・`firedWeeklyEvents` Set／`pendingChoiceEvent`）、`Skill`（Skill.swift:7・`state.skills`）、`NetaKata`／`NetaLength`（Neta.swift:10,21・全ネタ）、`BandCategory`（RadarChart.swift:11・`categoryLog`）、合成 Codable の `Phase`／`Section`／`AutoStage`（WeekRunner.swift:52,97,105）・`TournamentSpec.Eligibility`（Calendar.swift:22）・`Ability`（OfferSpec 内）。合成 Codable は case 名がキーなので rename も同じ。
   - 結果: クラッシュではなく、`manzai.save.v1.broken` に退避して新規ゲーム（キャリア消失に見える）。退避データを戻す経路は無い。1件でも未知の case があると丸ごと失敗する（配列・Set は1要素でも）。
   - 現状の守り: ChoiceEvent.swift:28 のコメント（case を消さない）だけ。強制する仕組み・テストは無い（DEBUG の旧セーブ試験 GameSession.swift:1754 はキー欠落だけで、未知 case は見ない）。
   - 直し案（案のみ）: ①未知 case を捨てる/既定値にする復号（`Set`・`[Skill]`・`[NetaLength]` は要素ごとに `try?` する薄い Decodable ラッパ）。②enum の全 case を固定した JSON を fixture にして、現行コードで復号できるかを見るテスト（case を消すと赤）。③退避セーブの救出は後回しでよい。

2. **WeekRunner.swift:647 と 365-376（gpStage 丸めの後始末）**
   - 落ちる状態: 回戦数が減り、保存の `gpStage` が新しい回戦数以上になった場合。丸めた後は `gpAlive == true`・`finalist == false`・`gpStage == count`。`proceed()` は回戦に入らず、決勝週も `revival`／`finalist` が偽なので何も起きず、全回戦通過のはずが決勝へ進まず年が終わる（`YearOutcome.roundsPassed == count`・`reachedFinal == false`）。落ちはしない。
   - 逆（回戦が増えた）: 通過済み `gpStage == 旧count` でも `finalist` は保存どおり真・`gpAlive` 真のまま `gpStage < 新count` になり、新しい回戦の週が未来なら追加の回戦が出る（週が過去なら出ない）。クラッシュなし、進行の食い違いのみ。
   - 直し案: 丸めで `snap.gpStage > count`（または `==` で `pendingAuto == .round` だった）のとき `finalist = snap.gpAlive || snap.finalist`（決勝進出扱い）にするか、`gpAlive = false` にして `isGPAlive` と揃える。方針はオーナー判断（設計）なので案のみ。

3. **GameSession.swift:259 `self.phase = save.phase` と WeekRunner.swift:657-664**
   - 落ちる状態: 保存の `Phase` に埋まった `tournamentDecision(spec)`／`freeAction(offer:)`／`gpRound(index:name:)` は保存時の値のまま画面に出る。runner 側の `pendingSpec`／`pendingOffer`／`offerChoices` は新しい config から取り直す（A-4）。更新で賞金・ライン・オファー額・回戦名が変わると、画面の数字と実際に適用される数字が食い違う。新しい暦に該当週の大会が無い場合は、古い spec のまま残る。
   - クラッシュなし。表示と実効値のずれ。
   - 直し案: 復元時に `phase` の中身も runner の `pendingSpec`／`pendingOffer` から作り直す（`WeekRunner` に `currentPhase()` を公開するか、復元後の `begin` 相当で組み直す）。

4. **GameState／Neta／TournamentSpec／OfferSpec／WeekRunnerSnapshot などに非 Optional のフィールドを足す将来の更新**
   - 落ちる状態: 合成 Decodable は `var x = 0` のような既定値付きでも、旧セーブにキーが無いと keyNotFound で失敗する（GameState.swift:3-5 の規約、SaveData 1129 行目以下の Optional 運用）。規約はコメントのみで、SaveData 以外（Neta／TournamentSpec 等の入れ子）に対するテストは見当たらない。失敗すると 1. と同じく新規へ。
   - 直し案: 現行の `GameState`／`Neta`／`WeekRunnerSnapshot` の JSON を fixture に保存し、`swift test` で現行型へ復号するテスト（キーを足すと赤）。

## §4 確度 低（前提で守られている）
- `state.room`（部屋の段）: GameEngine.swift:152,161,168 は `room < roomHeals.count`／`< roomRents.count` で守る。WeekMainView.swift:1036 も同様。WeekMainView.swift:1255 は `min(max(room,0), roomNames.count-1)`。範囲外の保存値でも落ちない。ShopView.swift:56 `config.roomRents[i]`（`i` は 0..<roomNames.count=3）は config の長さが 3 未満になった時だけ（セーブ無関係・config の変更時の注意）。
- `usedPicks`（使った文の番号）: GameSession.swift:118 で `filter { $0 < count }`、DialogueData.swift:23 の `indexAvoidingUsed` も `count > 0` ガードと `used.first(where: 範囲内)`。プールが縮んでも安全。
- `gpRoundsPassed..<gpRounds.count`（GameSession.swift:676）: gpStage は丸め済み（WeekRunner.swift:647）で下端 ≤ 上端。`NetaCatalog.lengthForGPRound(index:)` は default 付き switch。
- `cal.gpRounds[gpStage]`（WeekRunner.swift:233）: 入口の `pendingAuto == .round` は丸めた段なら外す（667）。375 は `gpStage < count` を先に見る。`gpLossCompat[gpStage]`（256 付近）も `< count` ガード。
- `week > config.weeks`（週数が減った時）: `begin()`（WeekRunner.swift:170）が `yearDone` を返す。表示側は `weeks - week` が負になるが、添字・Range には使っていない（YearResultView／CalendarView は 1...weeks の走査と辞書引き）。
- `categoryLog`（辞書 `[Int: BandCategory]`）・`offerWeeks`・`firedWeeklyEvents`・`shownOnce`・`usedFanLines`: 添字に使わず辞書引き／集合のみ。`offerWeeks` は `(year-1)*weeks+week` の通算週で、`weeks` を変えると疲れ判定（GameEngine.swift:204）が一時的にずれるだけ。
- `selectedNetaID`／`selectedNetaID2`／`writeNetaID`: `firstIndex(where:)` で引く（WeekRunner.swift:159,521,527 付近）。存在しない id でも nil 扱い。
- `pendingOffer`／`offerChoices`: 名前で config から引き、無ければ保存値（WeekRunner.swift:660-662, 674）。
- `ComboKind.from`／`MeetingKind.from`: 未知の rawValue は既定値（ComboKind.swift:10・MeetingKind.swift:11）。
- `ChoiceEventKind` の `switch`（GameSession.swift:730-）: `regularEmployment` を残す互換が入っている。`ChoiceEventTable.choices` が空の種類でも `dismissChoiceEvent` がある（RootView.swift:436）。
- `careerYears` を減らした時: `year >= careerYears`（GameSession.swift:1045）で年末が即区切りになるだけ。`growthEndYear` は `min(year, …)` で守る（WeekRunner.swift:128 付近）。
- ゲージ類（能力が新しい上限を超えている）: 値の clamp は `add` 経由のみ。上限を下げると保存値が上限超過のまま。画面の割合は Double なので落ちない（RadarChart の `/ cap`）。整数の段への変換は未確認。

## §5 見た範囲
- `SaveData`（GameSession.swift:1100-1146）の全項目と `saveNow`（1184-）、`loadedOrNew`（1222-）、`init(restoring:)`（244-318）。`WeekRunnerSnapshot`（WeekRunner.swift:599-）と `init(restoring:)`（639-）。
- 保存値の使われ方: `gpStage`／`week`／`year`／`room`／`itemCounts`（キーは `ShopItem.rawValue` の文字列・Item.swift）／`skills`／`netas`／`categoryLog`／`usedPicks`／`pendingChoiceEvent`／`Phase`／`pendingAuto`。
- Codable な型の一覧（GameCore の `Codable` 全件・ManzaiGame の `BandCategory`／`Advice`／`YearRecord`）。
- 見ていない: ShopView／WeekMainView の整数化（ゲージの段）全件、Endings の年表走査の細部、`YearRecord` を使うエンディング文の分岐。
