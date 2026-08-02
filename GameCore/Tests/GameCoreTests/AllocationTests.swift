// AllocationTests.swift
// 割り振り（Allocation.swift）の同値性・会計則の単体保証。正典v3: docs/exp_currency_redesign_v0.md
// （パワプロ式5通貨・オーナー指示2026-08-02への対応。旧・同色ロック+共通枠2グループ方式を置換）。
// 核は testProjectedGainMatchesAdd: 見積もり純関数が add()（①逓減→②予算→③clamp）と全分岐で
// 厳密一致すること＝UI見積もり・確定・sim較正の3所が食い違わないことの担保。
// 新設: testRecipeIsGenuineManyToMany（1通貨が複数能力へ・1能力が複数通貨から＝旧1:1からの脱却を固定）。
// これらは golden（3年ビット一致）とは独立の追加テスト——既存 golden には一切触れない。

import XCTest
@testable import GameCore

final class AllocationTests: XCTestCase {

    /// projectedGain == add() の見える伸び。逓減あり/なし・予算 nil/満杯/残りわずか/十分・
    /// cap際・メンタル（予算除外）の全グリッドで厳密一致（同一式・同一演算順なのでビット一致を要求）。
    /// 通貨変換とは独立の関数＝正典v3でも不変（amount は既に能力への生の伸び試行量）。
    func testProjectedGainMatchesAdd() {
        var config = GameConfig()
        let values: [Double] = [0, 10, 60, 115, 119.5, 120]
        let budgets: [Double?] = [nil, 0, 0.05, 6]
        let amounts: [Double] = [0.4, 1, 5]
        for decay in [config.growthDecayD, nil] {
            config.growthDecayD = decay
            for a in Ability.allCases {
                for v in values {
                    for b in budgets {
                        for amt in amounts {
                            var s = GameState(config: config)
                            s[a] = min(v, a == .メンタル ? config.mentalCap : config.abilityCap)
                            s.growthBudget = b
                            s.growthUsed = 1.0   // b=0 のとき remaining<0 の分岐も踏む
                            let projected = GameEngine.projectedGain(a, amount: amt, state: s, config: config)
                            var applied = s
                            GameEngine.add(.ability(a), amt, to: &applied, config: config)
                            XCTAssertEqual(projected, applied[a] - s[a],
                                           "projectedGain が add() とずれた: \(a) v=\(v) budget=\(String(describing: b)) amt=\(amt) decay=\(String(describing: decay))")
                        }
                    }
                }
            }
        }
    }

    /// 正典v3の核: 1通貨（閃き）は複数能力（センス/発想/華）に、1能力（センス）は複数通貨（閃き/間合い/胆力）
    /// に依存する＝旧1:1（同色ロック）からの脱却。GameConfig.abilityRecipes の構造そのものを固定するテスト。
    func testRecipeIsGenuineManyToMany() {
        let config = GameConfig()
        let recipes = config.abilityRecipes
        // 1通貨が複数能力に寄与しているか（閃きを例に）
        let abilitiesUsingHirameki = Ability.allCases.filter { a in
            (recipes[a] ?? []).contains { $0.0 == .閃き }
        }
        XCTAssertGreaterThanOrEqual(abilitiesUsingHirameki.count, 2, "閃きは複数能力に寄与するはず（多対多の核）")
        // 1能力が複数通貨から構成されているか（センスを例に）
        XCTAssertGreaterThanOrEqual(recipes[.センス]?.count ?? 0, 2, "センスは複数通貨のブレンドで伸びるはず")
        // 全能力がレシピを持つ（空レシピ＝絶対に伸びない能力があってはならない）
        for a in Ability.allCases {
            XCTAssertFalse((recipes[a] ?? []).isEmpty, "\(a) のレシピが空＝永久に伸びない")
        }
    }

    /// pourStep はレシピの全通貨を同じ比率（Leontief）で同時消費する。単一通貨だけを払う旧仕様には戻れない。
    func testPourStepConsumesAllRecipeCurrenciesProportionally() {
        let config = GameConfig()   // センス: 閃き0.45 / 間合い0.35 / 胆力0.20
        var s = GameState(config: config)
        s.growthBudget = nil        // 予算の影響を切って支払い比率だけ見る
        s.exp閃き = 10; s.exp間合い = 10; s.exp胆力 = 10   // 全通貨に余裕＝ボトルネックはallocationStep側
        let gain = GameEngine.pourStep(.センス, to: &s, config: config)
        XCTAssertGreaterThan(gain, 0)
        // allocationStep=1.0 を各重みで按分して消費（10-1×0.45=9.55 等）
        XCTAssertEqual(s.exp閃き, 10 - 1.0 * 0.45, accuracy: 1e-9)
        XCTAssertEqual(s.exp間合い, 10 - 1.0 * 0.35, accuracy: 1e-9)
        XCTAssertEqual(s.exp胆力, 10 - 1.0 * 0.20, accuracy: 1e-9)
    }

    /// 通貨のどれか1つでも0なら、その能力は一切伸びない（ボトルネック＝全通貨が揃って初めて伸びる）。
    /// これが「1つの稽古だけでは全能力を伸ばせない」の実体＝ユーザー指摘への正面対応。
    func testPourStepBottlenecksOnScarcestCurrency() {
        let config = GameConfig()   // 発想: 閃き0.65 / 語彙0.35
        var s = GameState(config: config)
        s.exp閃き = 10   // 語彙が0＝発想は伸びないはず
        let gain = GameEngine.pourStep(.発想, to: &s, config: config)
        XCTAssertEqual(gain, 0, "レシピの一部通貨が0なら伸びない（ボトルネック）")
        XCTAssertEqual(s.exp閃き, 10, "伸びなかった段は通貨を消費しない（余剰許容）")
    }

    /// ゼロ利得段は通貨を消費しない（余剰許容: 器が満ちたら残高・能力・帳簿とも一切動かない）
    func testPourStepRefusesWhenBudgetFull() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.growthBudget = 6
        s.growthUsed = 6            // 器が満ちている
        s.exp閃き = 3; s.exp語彙 = 3   // 発想のレシピを満たす
        let before = s
        let gain = GameEngine.pourStep(.発想, to: &s, config: config)
        XCTAssertEqual(gain, 0)
        XCTAssertEqual(s.exp閃き, before.exp閃き, "通貨は減らない")
        XCTAssertEqual(s.exp語彙, before.exp語彙)
        XCTAssertEqual(s.発想, before.発想, "能力も動かない")
        XCTAssertEqual(s.growthUsed, before.growthUsed, "帳簿も動かない")
    }

    /// メンタルは予算②を通らない（正典v2不変）＝メンタルのレシピ通貨（存在感/胆力）を注いでも器は消費しない
    func testMentalDoesNotConsumeGrowthBudget() {
        let config = GameConfig()   // メンタル: 存在感0.25 / 胆力0.75
        var s = GameState(config: config)
        s.growthBudget = 100
        s.exp存在感 = 2; s.exp胆力 = 2
        let used = s.growthUsed
        let gain = GameEngine.pourStep(.メンタル, to: &s, config: config)
        XCTAssertGreaterThan(gain, 0)
        XCTAssertEqual(s.growthUsed, used, "メンタル注入は器を消費しない")
    }

    /// 段刻みループは一括 add() を決して上回らない（貯め込みの1点評価上振れが構造的に消えている）
    func testStepLoopNeverExceedsSingleShot() {
        let config = GameConfig()   // 発想: 閃き0.65 / 語彙0.35
        var single = GameState(config: config)
        single.growthBudget = 100   // 予算で切られない条件で逓減複利だけを見る
        GameEngine.add(.ability(.発想), 6, to: &single, config: config)

        var looped = GameState(config: config)
        looped.growthBudget = 100
        looped.exp閃き = 6 * 0.65; looped.exp語彙 = 6 * 0.35   // ちょうど生量6ぶんの通貨を両方揃えて注ぐ
        while GameEngine.pourStep(.発想, to: &looped, config: config) > 0 {}
        XCTAssertLessThanOrEqual(looped.発想, single.発想, "段刻みが一括評価を上回ったら1点評価ガードが壊れている")
        XCTAssertGreaterThan(looped.発想, GameState(config: config).発想, "注げてはいる")
    }

    /// 同じタップ列の再生は常に同じ結果（プレビュー=確定のリプレイ決定論・RNG非消費）
    func testReplayDeterminism() {
        let config = GameConfig()
        var base = GameState(config: config)
        base.growthBudget = 6
        base.exp閃き = 4; base.exp語彙 = 4; base.exp間合い = 4; base.exp存在感 = 4; base.exp胆力 = 4
        let taps: [Ability] = [.センス, .表現, .発想, .メンタル, .センス, .華, .発想]
        var a = base, b = base
        for t in taps { GameEngine.pourStep(t, to: &a, config: config) }
        for t in taps { GameEngine.pourStep(t, to: &b, config: config) }
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        XCTAssertEqual(try? enc.encode(a), try? enc.encode(b), "同一タップ列の再生が非決定的")
    }

    /// おすすめ注ぎ: 決定論・注げる通貨を残さない（器と上限とレシピが許す限り）・現在値が低い能力を優先
    func testRecommendedPlanIsDeterministicAndDrains() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.growthBudget = 100
        s.センス = 40; s.発想 = 10   // 発想が低い→優先されるはず
        s.exp閃き = 5; s.exp語彙 = 5; s.exp間合い = 5; s.exp胆力 = 5   // センス・発想とも伸ばせる通貨を用意
        let plan1 = GameEngine.recommendedPlan(state: s, config: config)
        let plan2 = GameEngine.recommendedPlan(state: s, config: config)
        XCTAssertEqual(plan1, plan2, "おすすめ注ぎが非決定的")
        XCTAssertFalse(plan1.isEmpty)
        var after = s
        for t in plan1 { GameEngine.pourStep(t, to: &after, config: config) }
        // 発想（低い方）が最初に選ばれ続けるはず＝センスより多く注がれる
        let ideaTaps = plan1.filter { $0 == .発想 }.count
        let senseTaps = plan1.filter { $0 == .センス }.count
        XCTAssertGreaterThan(ideaTaps, senseTaps, "現在値が低い能力（発想）へ多く向かう")
    }
}
