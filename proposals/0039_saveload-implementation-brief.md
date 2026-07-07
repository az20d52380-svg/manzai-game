<!-- 提案 0039 / セーブ/ロード（中断復帰）実装ブリーフ / 0024と同種＝MVP側CLIへの引き継ぎ・コード改変なし・設計のみ -->

# セーブ/ロード（中断復帰）実装ブリーフ v0（2026-07-07）

- 位置づけ：`0024_choice-event-mvp-framework.md`と同種の**実装ブリーフ**（会話/イベント本文ではない）。「アプリを閉じたら進行が消える」という土台の欠落に対する具体的な実装手順。
- **本ドキュメントの限界（重要）**：このクラウド環境にはSwiftツールチェーンが存在せず、`swift test`/`xcodebuild`を一切実行できない。以下はコードを読んだ上での設計（実在のAPI・型名を正確に踏まえている）だが、**未コンパイル・未検証**。Mac/CLI側で実装する際は、まず本ブリーフをレビューし、実装後に必ず`swift test`をgreenにすること。
- 好材料：`docs/ui_design_v0.md §5`が最初からこれを見込んで設計されており、`GameState`と`SplitMix64`は**既にCodable対応済み・ラウンドトリップテスト済み**（`GameCore/Tests/GameCoreTests/CodableTests.swift`）。土台の半分はもう存在する。

## 狙い

`GameSession`は`WeekRunner<SplitMix64>`を保持するだけの薄いViewModelで、アプリプロセスが終了すると全て消える。48週×1年のプレイ中にアプリが落ちる（OSの都合・誤操作含む）と、それまでの進行が丸ごと失われる。これは「ゲームとして動かない」レベルの欠落。

## 現状の型を踏まえた設計

### 1. `WeekRunner`（GameCore・`Sources/GameCore/WeekRunner.swift`）に持たせる追加API

`WeekRunner<R>`の内部状態（`state`/`rng`は`public private(set)`だが、`gpStage`/`gpEntryPaid`/`gpAlive`/`finalist`/`revival`/`section`/`acted`/`weekResults`/`pendingSpec`/`pendingOffer`/`pendingAuto`/`revivalTried`/`finalTried`/`finished`/`finalLine`は全て`private`）をまるごとCodableにしたいが、`private let config: GameConfig`が含まれているため単純に`WeekRunner: Codable`にはできない（`GameConfig`はプレイヤーごとに変わらない固定バランス値＝**永続化不要**。むしろ永続化すべきでない＝将来バランス値を更新したとき古いセーブに古い値が固定化されるのを防ぐ）。

対応：`config`を除いた**スナップショット構造体**を新設し、`WeekRunner`に「取り出す」「（configを外から注入して）復元する」の2つのAPIを追加する。**`Section`/`AutoStage`は現在`private enum`なので`public enum`に上げる必要がある**（挙動は変えない・可視性のみの変更）。

```swift
// WeekRunner.swift 内・同一ファイルの extension として追加（private フィールドへのアクセスに同一ファイル内特権が必要）

// private enum Section { ... } → public enum Section: Codable { ... }  ※可視性のみ変更
// private enum AutoStage { ... } → public enum AutoStage: Codable { ... }  ※可視性のみ変更

/// 中断セーブ用のスナップショット。GameConfigは含まない（アプリ起動時に固定値から再構築する）。
public struct WeekRunnerSnapshot<R: RandomSource & Codable>: Codable {
    public var state: GameState
    public var rng: R
    public var year: Int
    public var week: Int
    public var finalLine: Double
    public var gpStage: Int
    public var gpEntryPaid: Bool
    public var gpAlive: Bool
    public var finalist: Bool
    public var revival: Bool
    public var section: WeekRunner<R>.Section
    public var acted: Bool
    public var weekResults: [StageResult]
    public var pendingSpec: TournamentSpec?
    public var pendingOffer: OfferSpec?
    public var pendingAuto: WeekRunner<R>.AutoStage?
    public var revivalTried: Bool
    public var finalTried: Bool
    public var finished: YearOutcome?
}

extension WeekRunner {
    /// 現在の内部状態を取り出す（セーブ用・非破壊）
    public func snapshot() -> WeekRunnerSnapshot<R> {
        WeekRunnerSnapshot(state: state, rng: rng, year: year, week: week, finalLine: finalLine,
                           gpStage: gpStage, gpEntryPaid: gpEntryPaid, gpAlive: gpAlive,
                           finalist: finalist, revival: revival, section: section, acted: acted,
                           weekResults: weekResults, pendingSpec: pendingSpec, pendingOffer: pendingOffer,
                           pendingAuto: pendingAuto, revivalTried: revivalTried, finalTried: finalTried,
                           finished: finished)
    }

    /// スナップショットから復元する（ロード用）。config はアプリ起動時に生成した固定値を渡す。
    public init(restoring snap: WeekRunnerSnapshot<R>, config: GameConfig) {
        self.state = snap.state
        self.rng = snap.rng
        self.year = snap.year
        self.week = snap.week
        self.config = config
        self.finalLine = snap.finalLine
        self.gpStage = snap.gpStage
        self.gpEntryPaid = snap.gpEntryPaid
        self.gpAlive = snap.gpAlive
        self.finalist = snap.finalist
        self.revival = snap.revival
        self.section = snap.section
        self.acted = snap.acted
        self.weekResults = snap.weekResults
        self.pendingSpec = snap.pendingSpec
        self.pendingOffer = snap.pendingOffer
        self.pendingAuto = snap.pendingAuto
        self.revivalTried = snap.revivalTried
        self.finalTried = snap.finalTried
        self.finished = snap.finished
    }
}
```

**この拡張は同一ファイル（`WeekRunner.swift`）内に書くこと**——Swiftの`private`はファイルスコープなので、別ファイルのextensionからは`gpStage`等に触れない。

### 2. 依存する型にCodableを追加する（既存の公開APIは変えない）

| 型 | 変更内容 | 破壊的変更か |
|---|---|---|
| `Ability`（GameConfig.swift） | `: CaseIterable, Hashable` → `: CaseIterable, Hashable, Codable` | なし（列挙子のみ・連想値なし） |
| `Travel`（Calendar.swift） | `enum Travel` → `enum Travel: Codable` | なし |
| `TournamentSpec.Eligibility`（Calendar.swift） | `: Codable` 追加（連想値`Int`/`Double`のみ・自動合成可） | なし |
| `TournamentSpec`（Calendar.swift） | `: Codable` 追加（全フィールドがString/Int/Double/Bool/Eligibility＝自動合成可） | なし |
| `OfferSpec`（GameConfig.swift） | **要注意**：`public let ability: (Ability, Double)?` はタプルでCodable非対応。下記の通り内部表現だけ変える | **公開APIは無変更**（`.ability`は計算プロパティとして同じ型を返す） |
| `StageResult`（WeekRunner.swift） | `: Codable` 追加（全フィールドがString/Bool/Int＝自動合成可） | なし |
| `WeekSummary`（WeekRunner.swift） | `: Codable` 追加（`year`/`week`/`[StageResult]`/`GameState`＝自動合成可） | なし |
| `YearOutcome`（Career.swift） | `: Codable` 追加（全フィールドBool/Int＝自動合成可） | なし |
| `WeekRunner.Phase`（WeekRunner.swift） | `: Codable` 追加（連想値が上記の型のみになった後なら自動合成可。`gpRound(index: Int, name: String)`は連想値2つの列挙ケースであり要素自体はタプルでないため合成対象） | なし |
| `WeekAction`（Career.swift） | `: Codable` 追加（`Training`/`Job`/`Rest`は連想値なし列挙・Codable追加が要る） | なし |
| `Training`/`Job`/`Rest`（GameConfig.swift） | `: Codable` 追加 | なし |

**`OfferSpec`の書き換え例**（公開イニシャライザ・`.ability`の型は完全に同じまま）：

```swift
public struct OfferSpec: Codable {
    public let name: String
    public let income: Int
    public let fame: Double
    private let abilityKind: Ability?
    private let abilityAmount: Double?
    public let stamina: Double

    public var ability: (Ability, Double)? {
        guard let k = abilityKind, let a = abilityAmount else { return nil }
        return (k, a)
    }

    public init(name: String, income: Int, fame: Double, ability: (Ability, Double)?, stamina: Double) {
        self.name = name
        self.income = income
        self.fame = fame
        self.abilityKind = ability?.0
        self.abilityAmount = ability?.1
        self.stamina = stamina
    }
}
```

`GameEngine.swift`の`applyOffer`（`o.ability?.0`/`.1`を読むだけ）・`GameConfig.swift`の`offerMoney`/`offerExp`（`init`呼び出しは同じ引数）はどちらも**無修正で動く**（計算プロパティが同じ型を返すため）。

**`GameConfig`自体はCodableにしない**（`trainings`/`jobs`/`rests`等のDictionary値にタプルが使われており、Codable化には広範な書き換えが要る。かつ固定バランス値なので永続化する意味がない＝GameConfigはロード時に`GameConfig()`で毎回新規生成すればよい）。

### 3. `GameSession`（ManzaiGame・`Sources/GameSession.swift`）への追加

```swift
/// 中断セーブの完全な内容（GameSessionの表示用状態のうち、resume に要る部分のみ）
public struct SaveData: Codable {
    public var runner: WeekRunnerSnapshot<SplitMix64>
    public var phase: WeekRunner<SplitMix64>.Phase
    public var pendingResult: WeekSummary?
    public var log: [String]
    public var lossStreak: Int
    public var justPassedStage: Bool
}
```

`lastAction`/`lastGains`/`lastCompatGain`/`winFinale`/`finished`/`outcome`は**永続化しない**（「直前の選択への反応バッジ」等のUI装飾フラグであり、再開直後は「直前の選択」自体が存在しないため意味を持たない。宣言済みのデフォルト値`false`/`nil`/`[]`/`0`がそのまま使われる）。

```swift
extension GameSession {
    private static let saveKey = "manzai.save.v1"

    /// 中断セーブを試みる（pump()の最後・acknowledgeWin()で呼ぶ）。年が終わっていれば逆にセーブを消す。
    func autosave() {
        guard !finished else {
            UserDefaults.standard.removeObject(forKey: Self.saveKey)
            return
        }
        let save = SaveData(runner: runner.snapshot(), phase: phase, pendingResult: pendingResult,
                            log: log, lossStreak: lossStreak, justPassedStage: justPassedStage)
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    static func loadSave() -> SaveData? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: data)
    }

    /// セーブがあれば復元、無ければ新規（起動時のエントリポイント）
    static func loadedOrNew(config: GameConfig = GameConfig()) -> GameSession {
        if let save = loadSave() {
            return GameSession(restoring: save, config: config)
        }
        return GameSession(config: config)
    }

    /// 復元用の指定イニシャライザ（既存の init(seed:config:startState:) とは別枠）
    convenience init(restoring save: SaveData, config: GameConfig) {
        // 実装詳細はMac側で既存initの構造に合わせて調整（このクラスがfinal class＝convenience不可なので
        // 実際には designated init を1本追加する形になる。上記は意図の記述であり実コードではない）
    }
}
```

（`GameSession`は`final class`なので`convenience init`は書けない——上記は意図を示すための擬似コードで、実装時は既存の`init(seed:config:startState:)`と同じ形の**designated init**を1本追加し、`runner`/`state`/`phase`/`week`/`log`/`lossStreak`/`justPassedStage`/`pendingResult`を直接セットし、`config`/`lastAction`等その他は宣言済みデフォルト値に委ねる形にすること。）

**呼び出し箇所**：`pump()`メソッド（`GameSession.swift`）の最後に`autosave()`を1行追加するだけで、`decideTournament`/`choose`/`advanceAuto`/`acknowledgeResult`/`init`の全経路をカバーできる（全てpump()を経由するため）。`acknowledgeWin()`（`winFinale=false; finished=true`を直接セットし、pump()を経由しない）にも1行`autosave()`を追加し、優勝確定時点で速やかにセーブを消す。

### 4. `RootView`（ManzaiGame・`Sources/RootView.swift`）の変更点

現在：`@State private var session = GameSession()`

変更後：`@State private var session = GameSession.loadedOrNew()`

**これだけ**。`ui_design_v0.md §5`にある「タイトル画面の『つづきから』ボタン」等のUIは**本ブリーフの対象外**（タイトル/オンボーディング画面自体が現在未実装であり、UIが無い以上『つづきから』の選択肢を出す必要もない。セーブがあれば自動でその週へ直行する形で十分。タイトル画面が実装されるフェーズで初めて「はじめから/つづきから」の分岐UIが要る）。

## テスト（Mac側で必須）

1. `GameCore/Tests/GameCoreTests/CodableTests.swift`に**ラウンドトリップテストを追加**：`WeekRunner`を数週進めてから`snapshot()`→JSON encode→decode→`init(restoring:config:)`で復元し、続く`resolveAction`/`resolveTournament`の呼び出し結果が復元前と完全一致することを確認（`SplitMix64`の既存テストと同じ発想）。
2. `swift test`が全green（既存の`CareerGoldenTests`/`WeekRunnerGoldenTests`が�各れていないことも含めて確認——本ブリーフはRNG消費順・数式を一切変えていないので理論上goldenは無傷のはずだが、Codable合成のtypoやSection/AutoStageの可視性変更ミスで**コンパイルが通らない**リスクが一番高い。まずビルドが通ることを確認）。
3. シミュレータでの目視：アプリを週の途中（例：大会入口画面）で強制終了→再起動→同じ画面に復帰することを確認。

## golden・CLAUDE.md適合

- **golden**：RNG消費順・数式は一切変更なし。`WeekRunner`の既存メソッド（`begin`/`resolveTournament`/`resolveAction`/`resolveAuto`）は無修正。新設するのは「今の内部状態を読み出す／書き込む」だけの非破壊API。**golden不変**（tools/*.py同期は不要）。
- **§B-4（バランス数値）**：本ブリーフはバランス数値を一切追加しない。
- **§D-9（xcodegen）**：`SaveData`等を独立ファイルに切るなら`ManzaiGame`に新規Swiftファイルが増えるため`xcodegen generate`が要る。既存ファイルへの追記のみで済ませる選択も可（judgment委任）。
- **§D-10（UI変更は目視必須）**：本ブリーフ自体はUIを追加しないが、動作確認は上記テスト3の通りシミュレータ目視が要る。

## リスク・注意

- **【最重要・未検証】** このブリーフはSwiftコンパイラなしで書かれた。特に以下は実装時に要確認：
  - `WeekRunner<R>.Section`/`AutoStage`を`private`→`public`にする際、他の箇所で`Section`という識別子が衝突していないか（Swift標準の`Calendar`とは別のCalendar.swift独自型が既にあるため名前衝突リスクは低いはずだが確認要）。
  - `WeekRunner.Phase`のCodable自動合成が、ネストされたジェネリック型（`WeekRunner<R>.Phase`）で問題なく通るか（合成自体は通常問題ないはずだが、Swiftバージョン依存の挙動差がありうる）。
  - `OfferSpec`の書き換えで`GameConfig.swift`内の`offerMoney`/`offerExp`の初期化・`GameEngine.swift`の`applyOffer`の呼び出しが本当に無修正で通るか（型は変えていないので通るはずだが要確認）。
- **セーブは1スロットのみ**（`UserDefaults`の単一キー）。複数コンビの並行育成等はMVP範囲外。
- **バランス数値変更時の互換性**：`GameConfig`は永続化しないため、開発中に`GameConfig`の値を変えても既存セーブは（内部状態のみ復元するため）**壊れず動く**。ただし挙動は新しい数値で進行することになる（例："成長予算"の再計算は`WeekRunner.init(restoring:)`ではなく通常の`init(state:year:config:...)`で行われる年初のロジックなので、セーブ内の`growthBudget`は既に確定した値のまま——年をまたぐ処理は本ブリーフの対象外＝MVPは1年完結のため未検証）。
- **タイトル/オンボーディング画面（`ui_design_v0.md §5`「つづきから」UI）は対象外**（UI実装は別途・オーナー指示により今回のブリーフから除外）。
