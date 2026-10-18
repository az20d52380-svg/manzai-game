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
        // 2026-10-12 原則「アイテムで能力は上がらない」：もう売らない。前のセーブで持っている人の効果は残す
        XCTAssertFalse(GameEngine.canBuy(.中古のICレコーダー, state: b, config: config))
        b.hasRecorder = true
        GameEngine.applyTraining(.ネタ作り, to: &a, config: config)
        GameEngine.applyTraining(.ネタ作り, to: &b, config: config)
        XCTAssertEqual(b[currency: .閃き] - a[currency: .閃き], config.itemRecorderBonus * config.expSupplyScale, accuracy: 1e-9)
    }

    func testAbilityItemsAreNotSold() {
        var s = GameState(config: config); s.money = 10_000_000
        for item in [ShopItem.中古のICレコーダー, .ネタ作家の勉強会, .ボイトレ短期集中, .稽古場の年契約] {
            XCTAssertFalse(GameEngine.canBuy(item, state: s, config: config), "\(item) は売らない")
            XCTAssertFalse(GameEngine.buy(item, to: &s, config: config))
        }
        XCTAssertEqual(s.money, 10_000_000)
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
        s.studioActive = true   // 稽古場の年契約はもう売らない（前のセーブで持っている場合の年明けの後始末だけ確かめる）
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

    func testBigDrinkStaminaAndYearlyLimit() {
        var s = GameState(config: config); s.money = 1_000_000; s.stamina = 10
        XCTAssertTrue(GameEngine.buy(.回復ドリンク大, to: &s, config: config))
        XCTAssertEqual(s.stamina, 30)
        for _ in 0..<3 { XCTAssertTrue(GameEngine.buy(.回復ドリンク大, to: &s, config: config)) }
        XCTAssertFalse(GameEngine.buy(.回復ドリンク大, to: &s, config: config))   // 年4本まで
        XCTAssertEqual(s.money, 1_000_000 - 4 * 20_000)
        GameEngine.resetYearlyItems(&s)
        XCTAssertTrue(GameEngine.canBuy(.回復ドリンク大, state: s, config: config))
    }

    func testThroatCareHalvesInjuryProbThisYearOnly() {
        var s = GameState(config: config); s.money = 100_000
        XCTAssertEqual(GameEngine.injuryProbMultiplier(state: s, config: config), 1.0)
        XCTAssertTrue(GameEngine.buy(.喉のケア用品, to: &s, config: config))
        XCTAssertFalse(GameEngine.buy(.喉のケア用品, to: &s, config: config))   // 年1つ
        XCTAssertEqual(GameEngine.injuryProbMultiplier(state: s, config: config), 0.5)
        GameEngine.resetYearlyItems(&s)
        XCTAssertEqual(GameEngine.injuryProbMultiplier(state: s, config: config), 1.0)
    }
}
