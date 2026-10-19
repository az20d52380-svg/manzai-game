// CoverageXTests.swift
// テストから直接触られていなかった内部関数（affordableRaw / creditCurrency / jitsuryoku / applyTraining の借金・不足分岐）の
// 振る舞い固定。Sources は不変。

import XCTest
@testable import GameCore

final class CoverageXTests: XCTestCase {
    let cfg = GameConfig()

    // MARK: affordableRaw（Leontief のボトルネック＋allocationStep 上限）

    func testAffordableRawZeroWhenAnyCurrencyEmpty() {
        var s = GameState(config: cfg)
        s.センス = 10   // 倍率1.0の帯
        s.exp閃き = 100; s.exp間合い = 100; s.exp胆力 = 0   // 胆力だけ空
        XCTAssertEqual(GameEngine.affordableRaw(.センス, state: s, config: cfg), 0, accuracy: 1e-12)
    }

    func testAffordableRawIsBottleneckBelowStep() {
        var s = GameState(config: cfg)
        s.発想 = 10     // 倍率1.0（レシピ 閃き0.65 / 語彙0.35）
        s.exp閃き = 100
        s.exp語彙 = 0.175   // 0.175/0.35 = 0.5 がボトルネック
        XCTAssertEqual(GameEngine.affordableRaw(.発想, state: s, config: cfg), 0.5, accuracy: 1e-12)
    }

    func testAffordableRawClampedToAllocationStep() {
        var s = GameState(config: cfg)
        s.発想 = 10
        s.exp閃き = 1_000; s.exp語彙 = 1_000
        XCTAssertEqual(GameEngine.affordableRaw(.発想, state: s, config: cfg), cfg.allocationStep, accuracy: 1e-12)
    }

    func testAffordableRawShrinksAsRankRises() {
        var lo = GameState(config: cfg), hi = GameState(config: cfg)
        lo.発想 = 10; hi.発想 = 60   // 倍率 1.0 と 2.5（55〜70未満の帯）
        lo.exp閃き = 100; hi.exp閃き = 100
        lo.exp語彙 = 0.175; hi.exp語彙 = 0.175
        let a = GameEngine.affordableRaw(.発想, state: lo, config: cfg)
        let b = GameEngine.affordableRaw(.発想, state: hi, config: cfg)
        XCTAssertEqual(a, 0.5, accuracy: 1e-12)
        XCTAssertEqual(b, 0.5 / 2.5, accuracy: 1e-9)
        XCTAssertLessThan(b, a)
    }

    // MARK: creditCurrency

    func testCreditCurrencyScalesBySupplyAndIgnoresNonPositive() {
        var s = GameState(config: cfg)
        let before = s.exp語彙
        GameEngine.creditCurrency(.語彙, 10, to: &s, config: cfg)
        XCTAssertEqual(s.exp語彙, before + 10 * cfg.expSupplyScale, accuracy: 1e-12)
        let mid = s.exp語彙
        GameEngine.creditCurrency(.語彙, 0, to: &s, config: cfg)
        GameEngine.creditCurrency(.語彙, -5, to: &s, config: cfg)
        XCTAssertEqual(s.exp語彙, mid, accuracy: 1e-12)
    }

    // MARK: jitsuryoku

    func testJitsuryokuIsWeightedSumOfFourAbilitiesIgnoringMental() {
        var s = GameState(config: cfg)
        s.センス = 10; s.発想 = 20; s.表現 = 30; s.華 = 40; s.メンタル = 99
        let expected = 10 * cfg.weightSense + 20 * cfg.weightIdea + 30 * cfg.weightExpr + 40 * cfg.weightChara
        XCTAssertEqual(GameEngine.jitsuryoku(s, config: cfg), expected, accuracy: 1e-12)
        s.メンタル = 0
        XCTAssertEqual(GameEngine.jitsuryoku(s, config: cfg), expected, accuracy: 1e-12)
    }

    func testJitsuryokuWeightsSumToOne() {
        let sum = cfg.weightSense + cfg.weightIdea + cfg.weightExpr + cfg.weightChara
        XCTAssertEqual(sum, 1.0, accuracy: 1e-12)
    }

    // MARK: applyTraining

    func testApplyTrainingUnaffordableReturnsFalseAndLeavesStateUntouched() {
        var s = GameState(config: cfg)
        s.money = 79_999
        let snap = s
        XCTAssertFalse(GameEngine.applyTraining(.ネタ見せ会, to: &s, config: cfg))
        XCTAssertEqual(s.money, snap.money)
        XCTAssertEqual(s.stamina, snap.stamina, accuracy: 1e-12)
        XCTAssertEqual(s.exp間合い, snap.exp間合い, accuracy: 1e-12)
        XCTAssertEqual(s.exp胆力, snap.exp胆力, accuracy: 1e-12)
    }

    func testApplyTrainingPaidChargesCostWhenExactlyAffordable() {
        var s = GameState(config: cfg)
        s.money = 80_000; s.stamina = 100
        XCTAssertTrue(GameEngine.applyTraining(.ネタ見せ会, to: &s, config: cfg))
        XCTAssertEqual(s.money, 0)
        XCTAssertEqual(s.stamina, 70, accuracy: 1e-12)
        XCTAssertEqual(s.exp間合い, 6 * cfg.expSupplyScale, accuracy: 1e-12)
        XCTAssertEqual(s.exp胆力, 3 * cfg.expSupplyScale, accuracy: 1e-12)
    }

    func testApplyTrainingInDebtHalvesCurrencyGainButNotStamina() {
        var s = GameState(config: cfg)
        s.money = -1; s.stamina = 100
        XCTAssertTrue(GameEngine.applyTraining(.ネタ作り, to: &s, config: cfg))
        let f = cfg.debtTrainFactor ?? 1
        XCTAssertEqual(s.exp閃き, 3 * f * cfg.expSupplyScale, accuracy: 1e-12)
        XCTAssertEqual(s.exp語彙, 1 * f * cfg.expSupplyScale, accuracy: 1e-12)
        XCTAssertEqual(s.stamina, 80, accuracy: 1e-12)
    }

    func testApplyTrainingCompatSubBypassesCurrencyEconomy() {
        var s = GameState(config: cfg)
        s.money = 0; s.stamina = 100
        let c0 = s.compat
        XCTAssertTrue(GameEngine.applyTraining(.ネタ合わせ, to: &s, config: cfg))
        XCTAssertGreaterThan(s.compat, c0)       // 相性は通貨でなく add 直結
        XCTAssertEqual(s.exp間合い, 3 * cfg.expSupplyScale, accuracy: 1e-12)
    }
}
