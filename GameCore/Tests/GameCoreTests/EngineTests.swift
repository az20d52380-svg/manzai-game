// EngineTests.swift
// 数式・分岐の単体テスト（乱数はスタブを注入）

import XCTest
@testable import GameCore

struct FixedRandom: RandomSource {
    var value: Double
    mutating func nextUniform() -> Double { value }
}

struct SeqRandom: RandomSource {
    var values: [Double]
    var index = 0
    mutating func nextUniform() -> Double {
        defer { index += 1 }
        return values[index]
    }
}

final class EngineTests: XCTestCase {

    func makeState(ability: Double, compat: Double, stamina: Double) -> GameState {
        var s = GameState()
        for a in Ability.allCases {
            s[a] = ability
        }
        s.compat = compat
        s.stamina = stamina
        return s
    }

    func testBlurWidth() {
        XCTAssertEqual(GameEngine.blurWidth(mental: 100), 5, accuracy: 1e-12)
        XCTAssertEqual(GameEngine.blurWidth(mental: 0), 20, accuracy: 1e-12)
    }

    func testPerformScoreAndStaminaPenalty() {
        let config = GameConfig()
        // u=0.5 → ブレ0。能力一律50 → 実力値50、相性10 → 素点60
        var rng = FixedRandom(value: 0.5)

        let full = makeState(ability: 50, compat: 10, stamina: 100)
        var r = GameEngine.perform(full, line: 60, config: config, rng: &rng)
        XCTAssertEqual(r.score, 60, accuracy: 1e-9)
        XCTAssertTrue(r.passed)   // ライン60ちょうどは通過（>=）
        r = GameEngine.perform(full, line: 60.0001, config: config, rng: &rng)
        XCTAssertFalse(r.passed)

        // 体力45 → -5
        let tired = makeState(ability: 50, compat: 10, stamina: 45)
        r = GameEngine.perform(tired, line: 0, config: config, rng: &rng)
        XCTAssertEqual(r.score, 55, accuracy: 1e-9)

        // 体力25 → -10（先頭の閾値30が先に適用される）
        let exhausted = makeState(ability: 50, compat: 10, stamina: 25)
        r = GameEngine.perform(exhausted, line: 0, config: config, rng: &rng)
        XCTAssertEqual(r.score, 50, accuracy: 1e-9)
    }

    func testGrowthDecay() {
        var config = GameConfig()
        config.growthDecayD = 120
        var s = GameState(config: config)
        // 10 + 3×(1−10/120) = 12.75
        GameEngine.add(.ability(.発想), 3, to: &s, config: config)
        XCTAssertEqual(s.発想, 12.75, accuracy: 1e-12)

        // 逓減なしなら +3 そのまま
        config.growthDecayD = nil
        var s2 = GameState(config: config)
        GameEngine.add(.ability(.発想), 3, to: &s2, config: config)
        XCTAssertEqual(s2.発想, 13, accuracy: 1e-12)
    }

    func testAbilityCaps() {
        var config = GameConfig()
        config.growthDecayD = nil   // クランプだけを見る
        var s = GameState(config: config)
        GameEngine.add(.ability(.センス), 500, to: &s, config: config)
        XCTAssertEqual(s.センス, config.abilityCap, accuracy: 1e-12)   // 演技系は120
        GameEngine.add(.ability(.メンタル), 500, to: &s, config: config)
        XCTAssertEqual(s.メンタル, config.mentalCap, accuracy: 1e-12)  // メンタルは100
    }

    func testCompatGrowthFlagAndCap() {
        var config = GameConfig()
        var s = GameState(config: config)
        GameEngine.applyRest(.相方と過ごす, to: &s, config: config)
        XCTAssertEqual(s.compat, config.compatInit + 1, accuracy: 1e-12)

        // 成長OFFなら変化しない
        config.compatGrows = false
        var s2 = GameState(config: config)
        GameEngine.applyRest(.相方と過ごす, to: &s2, config: config)
        XCTAssertEqual(s2.compat, config.compatInit, accuracy: 1e-12)

        // 上限20でクランプ
        config.compatGrows = true
        var s3 = GameState(config: config)
        s3.compat = config.compatCap
        GameEngine.add(.コンビ相性, 1, to: &s3, config: config)
        XCTAssertEqual(s3.compat, config.compatCap, accuracy: 1e-12)
    }

    func testPaidTrainingRequiresCash() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = 50_000   // 舞台稽古の8万に足りない
        let before = s
        XCTAssertFalse(GameEngine.applyTraining(.舞台稽古, to: &s, config: config))
        XCTAssertEqual(s.money, before.money)
        XCTAssertEqual(s.表現, before.表現, accuracy: 1e-12)

        // 無料稽古は所持金マイナスでも可（仕様: 有料行動のみ現金必須【仮】）
        s.money = -10_000
        XCTAssertTrue(GameEngine.applyTraining(.ネタ作り, to: &s, config: config))
    }

    func testRollOffer() {
        let config = GameConfig()
        let s = GameState(config: config)   // 知名度3 → 発生率0.05帯

        var hit = SeqRandom(values: [0.049, 0.4])
        let offer = GameEngine.rollOffer(state: s, config: config, rng: &hit)
        XCTAssertEqual(offer?.name, config.offerMoney.name)

        var hitExp = SeqRandom(values: [0.049, 0.6])
        let offer2 = GameEngine.rollOffer(state: s, config: config, rng: &hitExp)
        XCTAssertEqual(offer2?.name, config.offerExp.name)

        var miss = SeqRandom(values: [0.051])
        XCTAssertNil(GameEngine.rollOffer(state: s, config: config, rng: &miss))
    }

    func testLivingCostInterval() {
        let config = GameConfig()
        var s = GameState(config: config)
        let start = s.money
        GameEngine.applyWeekEnd(week: 3, to: &s, config: config)
        XCTAssertEqual(s.money, start)
        GameEngine.applyWeekEnd(week: 4, to: &s, config: config)
        XCTAssertEqual(s.money, start - config.livingCost)
    }

    func testSplitMix64Deterministic() {
        var a = SplitMix64(seed: 20_260_704)
        var b = SplitMix64(seed: 20_260_704)
        for _ in 0..<100 {
            let x = a.nextUniform()
            XCTAssertEqual(x, b.nextUniform())
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, 1)
        }
        var c = SplitMix64(seed: 1)
        XCTAssertNotEqual(a.nextUniform(), c.nextUniform())
    }
}
