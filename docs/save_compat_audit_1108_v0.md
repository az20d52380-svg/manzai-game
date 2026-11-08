# セーブ読み込み互換の静的点検（2026-11-08・v0）

読むだけの点検（コード変更・ビルド・テスト実行なし）。対象は「古い版のセーブを新しい版で開いた時」の ①デコード失敗でセーブが消える／初期化される ②落ちる。

## 結論
1. **危険度「高」は 1 件**：中断セーブ（`manzai.save.v1`）に載る enum（特に `ChoiceEventKind` の `firedWeeklyEvents`／`pendingChoiceEvent`）の case を 1 つでも消す・名前を変えると、旧セーブ全体が復号失敗→新規になる。現に 10/15 に 2 件消えた（後で戻した）実績あり。ガードは 10/25 のフィクスチャだけ。
2. 追加フィールドの規約（SaveData／GameState／WeekRunnerSnapshot／StageResult／YearOutcome／YearRecord／CareerRecords は Optional か独自 init）は **10/25 以降は守られている**。落ちる所（復元経路の強制アンラップ・添字）は見つからず。
3. 読めなかった時は「黙って捨てず `manzai.save.v1.broken` に 1 枠だけ退避→新規」だが、**退避から戻す処理が無く・2 回目の失敗で上書き・画面に何も出ない**。周回メタ（図鑑・トロフィー・戦績・ガチャ）は失敗すると無言で空になり、次の保存で上書きされる。

## 保存される物と保存先
| 保存先キー | 型 | 保存/読込 |
|---|---|---|
| `manzai.save.v1`（`.broken` に退避） | `GameSession.SaveData`（中に `WeekRunnerSnapshot<SplitMix64>`→`GameState`・`Phase`・`WeekSummary`・`YearRecord` など） | GameSession.swift:1330 / 1342 |
| `mz.endingsSeen` | `[String: EndingRecord]` | Endings.swift:198 / 210 |
| `mz.trophies` | `[String]`（TrophyID.rawValue） | Meta.swift:99 / 108 |
| `mz.careerRecords` | `CareerRecords` | Meta.swift:132 / 141 |
| `mz.trophyCounters` | 辞書（plist） | Meta.swift 付近・型安全で低リスク |
| ガチャ（GachaStore のキー・iCloud にも） | `GachaState`（独自 decode） | Store/GachaStore.swift:32 / 44 |
| 衣装 `StageOutfit` | rawValue 文字列 | Store/StageOutfit.swift:61（未知なら `.standard`＝安全） |
| 音量・初回フラグ等 | 単純値 | 低リスク |

セーブの初出は 2026-07-07。以降に足された非 Optional（`GameState` の `netas`／`archivedNetas`／`nextNetaID`＝07-18、`compatFreezeWeeks`＝07-20、`netaBoostWeeks`、`preoccupiedWeeks`＝07-21、`exp閃き` ほか＝08-03）は **合成 Decodable のため旧セーブにキーが無いと失敗**する。ただし規約（G-03）が入った 10/06 より前で、10/25 のフィクスチャ以降は凍結されている。

## 表（型・プロパティ・ファイル:行・キー欠落時の挙動・危険度・直すなら）
| 型 | プロパティ／要素 | ファイル:行 | キー欠落・未知値の時 | 危険度 | 直すなら（1 行） |
|---|---|---|---|---|---|
| `SaveData` | 後付けの `version`〜`writeNetaID`（約 25 個） | GameSession.swift:1211-1252 | すべて Optional＋`?? 既定値`（復元 :280-316）で安全。`SaveDataConventionTests` が非 Optional の増減を検知 | 低 | 現状維持 |
| `SaveData` | 初版からの非 Optional 20 個（`firedWeeklyEvents` ほか） | GameSession.swift:1212-1233 | 欠落すれば全体失敗。ただし凍結済み・テストあり | 低 | 現状維持（凍結リストを触らない） |
| `ChoiceEventKind`（`firedWeeklyEvents: Set<…>`、`pendingChoiceEvent`） | enum case | GameCore/ChoiceEvent.swift:7、SaveData :1224/:1228 | **未知の rawValue 1 つで Set 全体＝SaveData 全体が失敗→新規**。10/15 に `taniguchiShortJob`／`regularEmployment` が一度削除された履歴あり（今は復活） | **高** | `firedWeeklyEvents` を `[String]?` で持って読込時に `compactMap`、`pendingChoiceEvent` も String で保持、または `init(from:)` で未知値を捨てる |
| `Skill`（`GameState.skills: [Skill]?`） | enum case | GameCore/Skill.swift:7、GameState.swift | 未知 case で GameState 全体→SaveData 全体が失敗 | 中 | 同上（lossy 配列デコード） |
| `NetaKata`／`NetaLength`（`Neta`・`GameState.netas`） | enum case | GameCore/Neta.swift:10/21/38 | 未知 case でネタ全体→全体失敗。`Neta` の新規フィールドは Optional 運用（`tiredYears` など）で OK | 中 | 型は Optional 運用を維持＋未知 case 用の既定値（`init(from:)`） |
| `BandCategory`（`categoryLog: [Int: BandCategory]`） | enum case | RadarChart.swift:11 | 未知 case で全体失敗（`[Int: …]` は JSON 配列形式） | 中 | `[Int: String]` で保存して読込時に変換 |
| `Phase`／`TournamentSpec.Eligibility`／`Section`／`AutoStage`／`Job`／`Rest`／`Training`／`Travel`／`Ability`／`ExpCurrency`（関連値つき enum・合成） | case 名・関連値ラベル | WeekRunner.swift:54/99/107、Calendar.swift:16/22、GameConfig.swift | case の削除・改名・関連値のラベル変更で失敗。**新 case を足す分には旧セーブは読める**（`.hana` は 11/02 追加＝問題なし）。逆に新セーブを旧アプリで開く（ダウングレード）と失敗 | 中 | case を消さない／改名しない（フィクスチャ化）。`Phase` は復元時に `sameStep` で取り直すので、壊れたら `freeAction` へ戻す手もある |
| `GameState` | 非 Optional で後付けの 8 項目（`growthUsed`／`recoveryWeeks`／`bankrupt`／`netas`／`archivedNetas`／`nextNetaID`／`compatFreezeWeeks`／`netaBoostWeeks`／`preoccupiedWeeks`／`exp*` 5 個） | GameCore/GameState.swift:26-90 | **独自 init なし＝合成。キー無しで keyNotFound**。7/18〜8/3 より前のセーブは全部失敗。10/25 以降の GameState 追加は全て Optional（`rift`／`metaPoints`／`hana*` など）で OK | 中（出荷済みの旧セーブが 8 月前に遡るなら高） | `init(from:)` を足して `decodeIfPresent ?? 0/[]`（エンコードは合成のまま）。出荷版が 10/06 以降なら不要 |
| `WeekRunnerSnapshot` | `inviteSeed`／`pendingInvite`／`offerChoices`／`weekClosed` | WeekRunner.swift:631-657 | Optional で OK。初版からの項目は凍結（`SaveFixtureTests`） | 低 | 現状維持 |
| `StageResult` | `margin`／`burst` | WeekRunner.swift:11-34 | Optional で OK（`Coverage1019Tests` にテストあり） | 低 | 現状維持 |
| `YearOutcome` | `bankrupt`／`dissolved` | Career.swift:28-52 | 独自 init＋`decodeIfPresent`。テストあり | 低 | 現状維持 |
| `YearRecord` | `enteredGP`〜`smallWins` | GameSession.swift:1087-1108 | Optional で OK。`year`〜`prize` は非 Optional（凍結扱いだがテストが無い） | 低 | `year`〜`prize` の増減を規約テストに加える |
| `Advice`（`weekBanter`） | `name`／`text` | DialogueData.swift:9 | 凍結。足すなら Optional | 低 | 現状維持 |
| `ComboKind`／`MeetingKind`（SaveData には String で保持） | rawValue | ComboKind.swift:10、MeetingKind.swift:11 | `from()` が未知値・欠落を既定へ落とす | 低 | 現状維持（良い設計。上の enum もこの形に寄せる） |
| `CareerRecords` | `bestStreak`／`totalWins` が非 Optional、`hanaWins` は Optional | Meta.swift:80-85 | 新しい非 Optional を足すと失敗→`CareerRecords()` に黙って初期化→次の優勝で上書き（通算優勝が消える） | 中 | `init(from:)` で全部 `decodeIfPresent`、または足す物は常に Optional |
| `EndingRecord`／`[String: EndingRecord]` | `count`／`firstSeenAt`／`lastPartnerName` 全て非 Optional | Endings.swift:177-181、読込 :198 | 1 件でも形が変わると辞書全体が失敗→空→次の記録で上書き（図鑑が全消し）。未知の `EndingID` は :200 で捨てるだけで安全 | 中 | 値を足すなら Optional。読込は要素ごとに `try?` で拾う |
| `TrophyBook.load`（`[String]`→`TrophyID(rawValue:)`） | — | Meta.swift:99-100 | 未知 ID は捨てるだけ。配列が壊れていれば空→次の取得で上書き | 低 | 現状維持（壊れた時の退避だけ足すと良い） |
| `GachaState` | 全項目 `decodeIfPresent ?? 既定`＋旧形式（`paidPending`／`creditedTx`）の移行あり | Store/GachaState.swift:79-98 | キー欠落は安全（`{}` でも復号するテストあり）。型違いで throw→`GachaStore.decode` が `GachaState()` を返し、次の `persist` が上書き（購入の台帳が消える。iCloud 側とは merge で救える可能性） | 低〜中 | 失敗時は上書きせず別キーへ退避 |
| `GachaState.owned: Set<String>` | 衣装の rawValue 文字列 | Store/GachaState.swift:48 | 文字列保持なので `StageOutfit` の case 削除でも復号は成功。ただし表示対象から外れる（持ち物が見えなくなる） | 低 | case を消さない |
| `GameSession.init(restoring:)` | 復元経路の強制アンラップ・添字 | GameSession.swift:257-316、WeekRunner.swift（restoring） | 強制アンラップ・範囲外は見当たらない。`gpStage` は `min` で丸め済み、`phase` は `sameStep` で config から取り直し、`week` は `min(…, cfg.weeks)` で丸め済み | 低 | 現状維持 |

## 読込失敗時の扱い
- **中断セーブ**（GameSession.swift:1338-1352）：`catch` で `manzai.save.v1.broken` に元データを `set` し、本キーを消して新規セッションを返す。**黙って消さない点は良い**。
  - 問題 1：退避は **1 枠だけ**。2 回目の失敗（例：次の版でも読めない）で前の退避を上書きする。
  - 問題 2：`.broken` を**読んで戻す処理がどこにも無い**（grep で書き込みのみ）。救出は将来の版任せ。
  - 問題 3：画面にエラー表示・案内が出ない。プレイヤーには「セーブが消えた」ように見える。
  - 問題 4：新規で遊び始めると `saveNow()` が本キーに書く（`.broken` は残る）。
- **周回メタ**（図鑑・トロフィー・戦績）：`try?` で握りつぶして空を返す。**退避なし**。次の記録で上書きされる。
- **ガチャ**：失敗で `GachaState()`（無料 1 回つき）。次の `persist` で端末・iCloud の両方を上書き。merge があるので iCloud 側が正常なら救える。

## 既存テスト
- あり：`SaveDataConventionTests`（SaveData の非 Optional 凍結）／`SaveFixtureTests`（2026-10-25 の `WeekRunnerSnapshot` の固定 JSON）／`AppSaveFixtureTests` + `TestFixtures/save_1025.json`（SaveData 全体・`ChoiceEventKind` 全 case を含む）／`ManzaiGameTests`（旧セーブの comboKind・meetingKind・debtTier・writeNetaID）／`SessionGap1025dTests.testBrokenSaveMovedAsideAndNewSessionReturned`／`StoreMeta1107Tests`（壊れたトロフィー・戦績・ガチャの復号、`{}` の GachaState）／`CareerSkillGapTests`・`CoverageWTests`（YearOutcome の旧形式）／`Coverage1019Tests`（StageResult）／`TrophyHana1107Tests.testOldRecordsDecode`。
- 無い：①**フィクスチャが 10/25 の 1 本だけ**（それ以前＝7〜10 月の旧セーブの再現が無い）。②`GameState` の非 Optional（8 項目）を欠落させた JSON のテスト。③**未知の enum 値**（`firedWeeklyEvents` に消えた case 名・`categoryLog` に未知帯・`skills` に未知特技）を含む SaveData のテスト。④`EndingRecord` の欠落キー・1 件だけ壊れた辞書。⑤`.broken` の 2 回目上書きの挙動。⑥新しいセーブ→古い版（ダウングレード）。

## 足すべきテストの案
1. **未知 enum 値テスト**（最優先）：`save_1025.json` を辞書で読み、`firedWeeklyEvents` に `"removedEvent"`、`categoryLog` の値に `"zzz"`、`skills` に `"消えた特技"` を入れて `loadedOrNew()` した時に `isRestored == true`（直す前は赤＝現状の穴の証明）。
2. **GameState 欠落キーテスト**：`save_1025.json` の `runner.state` から `netas`／`exp閃き`／`compatFreezeWeeks`／`preoccupiedWeeks` などを消して復号できるか（出荷が 10/06 以降ならスキップ可・方針をオーナーに確認）。
3. **フィクスチャの世代を増やす**：節目ごとに `save_<日付>.json` を凍結して、全部を `loadedOrNew()` で通す（今の 1 本に足す形）。
4. **`.broken` の運用テスト**：2 回続けて壊れたセーブを渡した時の退避の中身（上書きか追記か）と、`.broken` から戻す関数（作った場合）の往復。
5. **メタ系の欠落キーテスト**：`EndingRecord` の `count` だけ欠落／1 件だけ型違いの辞書で、他の要素が残るか。`CareerRecords` に未知キーを足した JSON が読めるか。
6. **保存される enum の全 case 列挙テスト**：`ChoiceEventKind`／`Skill`／`NetaKata`／`NetaLength`／`BandCategory`／`TrophyID`／`EndingID` の rawValue 一覧を固定ファイルと比べ、case が減る・改名すると赤（増えるのは許可）。`SaveFixtureTests` の方針を enum 全体に広げる。

## 補足（直すかどうかはオーナー判断）
- 一番効く直し方は「保存する enum を String で持って読込時に変換、未知なら捨てる／既定値」（`ComboKind.from` と同じ形）。セーブ形式（JSON）は変えずに読み取りだけ寛容にできる。
- 出荷済みの最古の版がいつかで、`GameState` 非 Optional の件（中）が高に上がるか不要になるかが決まる。
