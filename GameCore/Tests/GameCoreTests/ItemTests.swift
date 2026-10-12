import XCTest
@testable import GameCore

final class ItemTests: XCTestCase {
    let config = GameConfig()

    func testDrinkYearlyLimitAndReset() {
        var s = GameState(config: config); s.money = 1_000_000; s.stamina = 50
        for _ in 0..<6 { XCTAssertTrue(GameEngine.buy(.栄養ドリンク, to: &s, config: config)) }
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: config))
        XCTAssertEqual(s.money, 1_000_000 - 6 * 3_000)
        GameEngine.resetYearlyItems(&s)
        XCTAssertTrue(GameEngine.canBuy(.栄養ドリンク, state: s, config: config))
    }

    func testRecorderOnceAndBoostsNetaWriting() {
        var a = GameState(config: config), b = GameState(config: config)
        b.money = 100_000
        XCTAssertTrue(GameEngine.buy(.中古のICレコーダー, to: &b, config: config))
        XCTAssertFalse(GameEngine.canBuy(.中古のICレコーダー, state: b, config: config))
        GameEngine.applyTraining(.ネタ作り, to: &a, config: config)
        GameEngine.applyTraining(.ネタ作り, to: &b, config: config)
        XCTAssertEqual(b[currency: .閃き] - a[currency: .閃き], config.itemRecorderBonus * config.expSupplyScale, accuracy: 1e-9)
    }

    func testSentoTicketsAddRecovery() {
        var s = GameState(config: config); s.money = 50_000; s.stamina = 10
        XCTAssertTrue(GameEngine.buy(.銭湯の回数券, to: &s, config: config))
        XCTAssertFalse(GameEngine.canBuy(.銭湯の回数券, state: s, config: config))
        var plain = GameState(config: config); plain.stamina = 10
        GameEngine.applyRest(.気分転換, to: &s, config: config)
        GameEngine.applyRest(.気分転換, to: &plain, config: config)
        XCTAssertEqual(s.stamina - plain.stamina, config.itemSentoRecovery, accuracy: 1e-9)
        XCTAssertEqual(s.sentoTickets, config.itemSentoTickets - 1)
    }

    func testYearlyEffectsClearedByNewYear() {
        var s = GameState(config: config); s.money = 3_000_000
        XCTAssertTrue(GameEngine.buy(.新幹線回数券, to: &s, config: config))
        XCTAssertTrue(GameEngine.buy(.稽古場の年契約, to: &s, config: config))
        let r = WeekRunner(state: s, year: 2, config: config, rng: SplitMix64(seed: 1))
        XCTAssertNil(r.state.shinkansenActive)
        XCTAssertNil(r.state.studioActive)
        XCTAssertNil(r.state.itemCounts)
    }

    func testUnboughtIsInert() {
        var a = GameState(config: config), b = GameState(config: config)
        GameEngine.resetYearlyItems(&b)
        GameEngine.applyTraining(.ネタ見せ会, to: &a, config: config)
        GameEngine.applyTraining(.ネタ見せ会, to: &b, config: config)
        XCTAssertEqual(a[currency: .間合い], b[currency: .間合い])
        XCTAssertNil(b.itemCounts)
    }
}
