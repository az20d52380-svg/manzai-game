# GameCore 設計メモ v0

- 日付: 2026-07-03
- 対象: `GameCore/`（SwiftPMパッケージ）。実装順の1〜5段階（週送り・パラメータ・稽古・バイト休む・生活費知名度オファー）の数式基盤。
- CLAUDE.md絶対ルールとの対応:
  - ルール1: GameCore は SwiftUI 非依存の純 Swift。UIターゲットからは `import GameCore` のみ許可
  - ルール2: 乱数は `RandomSource` プロトコル注入。製品では `SplitMix64(seed:)`、テストではスタブ
  - ルール3: バランス数値は `GameConfig` に集約（全て【仮】）
  - ルール5: Python検証機との同期は golden テストで担保（後述）

## 構成

```
GameCore/
├── Package.swift
├── Sources/GameCore/
│   ├── GameConfig.swift    … 全バランス数値・行動定義（balance_sim.py CONFIG と1対1）
│   ├── GameState.swift     … コンビ1組の状態（所持金・体力・知名度・能力5種・相性）
│   ├── RandomSource.swift  … シード固定可能な乱数の注入点（SplitMix64）
│   └── GameEngine.swift    … 週次行動・本番スコア・生活費（balance_sim.py の関数群と同値）
└── Tests/GameCoreTests/
    ├── GoldenTests.swift   … Python生成の12週期待値との一致（数式同期の要）
    └── EngineTests.swift   … 分岐・クランプ・乱数スタブの単体テスト
```

## Python ↔ Swift 対応表

| Python (`tools/balance_sim.py`) | Swift (`GameCore`) |
|---|---|
| `WEEKS` / `INIT_*` / `COMPAT_*` | `GameConfig.weeks` / `init*` / `compat*` |
| `LIVING_COST` / `LIVING_INTERVAL` | `GameConfig.livingCost` / `livingInterval` |
| `TRAININGS` / `JOBS` / `RESTS` | `GameConfig.trainings` / `jobs` / `rests` |
| `OFFER_MONEY` / `OFFER_EXP` / `OFFER_RATES` | `GameConfig.offerMoney` / `offerExp` / `offerRates` |
| `W_SENSE`〜`W_CHARA` / `STAM_PEN` | `GameConfig.weight*` / `staminaPenalties` |
| `blur_width` / `jitsuryoku` | `GameEngine.blurWidth` / `jitsuryoku` |
| `add` / `do_training` / `do_job` / `do_rest` / `do_offer` / `roll_offer` / `perform` | `GameEngine.add` / `applyTraining` / `applyJob` / `applyRest` / `applyOffer` / `rollOffer` / `perform` |
| 生活費（`run_one` 末尾） | `GameEngine.applyWeekEnd` |
| 成長逓減（`tools/exp_decay.py` のパッチ） | `GameConfig.growthDecayD`（既定 120） |

能力5種の対応: sense=センス / idea=発想 / expr=表現 / chara=華 / mental=メンタル。

## 乱数の同期方針

PythonのMTとSwiftのSplitMix64は列が異なるため、**乱数を消費する経路の数値一致は求めない**。同期は次の2段で担保する:

1. 乱数を使わない経路（稽古・バイト・休む・生活費・逓減・クランプ）→ `GoldenTests` でPython生成値と1e-9一致
2. 乱数を使う経路（ブレ・オファー抽選）→ 式の形をテストで固定（`FixedRandom(0.5)`でブレ0になる、など）＋統計比較は tools 側のシミュレータで行う

## golden値の再生成

数式・数値を変えたら以下で期待値を再生成し、`GoldenTests.swift` の表を更新する:

```python
# tools/ で実行
import balance_sim as B
import exp_decay
exp_decay.install_decay(120)   # GameConfig.growthDecayD と揃える
s = B.S()
# GoldenTests.swift の script と同じ12手を実行し、各週の全フィールドを repr で出力
```

（実行済みスクリプトはコミット `docs/gamecore_design.md` 追加時のメッセージ参照。手順化が必要になったら tools/gen_golden.py に切り出す）

## 【設計上の懸念】

1. **成長逓減の正式採用**: `GameConfig.growthDecayD = 120` を既定にした（根拠: `docs/career_report_v1.md`）。ただし Python 側の `balance_sim.py` 本体には未組み込みで、`exp_decay.py` のパッチ注入で揃えている。逓減を正式確定したら `balance_sim.py` の `add()` に組み込み、golden 値を再生成すること。ここがズレたままだと以後の全バランス実験が実装と乖離する。
2. **Linux環境のためSwiftビルド未検証**: この環境ではSwiftツールチェーンが取得できない（ネットワークポリシーで遮断）。Mac側で最初に `cd GameCore && swift test` を実行し、コンパイル・全テスト通過を確認してから積み上げること。GoldenTests が通れば数式同期は保証される。
3. **enum名を日本語にした**: 稽古・バイト・休む・能力のenumケースは仕様書の日本語名をそのまま使用（`case ネタ作り` 等）。Python辞書キーとの目視対照を優先した。ローカライズや保存形式（rawValue）を考える段階で英語ID＋表示名の分離に変える可能性がある。

## 次にやること（実装順に沿って）

1. Macで `swift test` → コンパイル&golden一致の確認
2. 週送りループ（`TurnController`: 1〜48週・年またぎ・体力年初回復）
3. 大会カレンダーと多段階グランプリ（`tools/sim_career.py` の構造を移植）
4. 突発イベント・リザルト
5. SwiftUI側（別ターゲット）はGameCore安定後
