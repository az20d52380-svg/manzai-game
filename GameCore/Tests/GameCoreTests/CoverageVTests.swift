// CoverageVTests.swift
// 薄い所の補強（5回目）：EventEffect の凍結/ブースト/拘束/成長天井、Item の購入境界、部屋の移動と休養への効き方。
import XCTest
@testable import GameCore

final class CoverageVTests: XCTestCase {
    private let cfg = GameConfig()

    // MARK: EventEffect

    func testFreezeBoostPreoccupyKeepLongerAndStartFromZero() {
        var s = GameState(config: cfg)
        XCTAssertEqual(s.compatFreezeWeeks, 0)
        s.applyEventEffect(.compatFreeze(3), config: cfg)
        s.applyEventEffect(.compatFreeze(2), config: cfg)      // 短い方では上書きしない
        XCTAssertEqual(s.compatFreezeWeeks, 3)
        s.applyEventEffect(.compatFreeze(5), config: cfg)
        XCTAssertEqual(s.compatFreezeWeeks, 5)

        s.applyEventEffect(.netaBoostNextWeek(4), config: cfg)
        s.applyEventEffect(.netaBoostNextWeek(1), config: cfg)
        XCTAssertEqual(s.netaBoostWeeks, 4)
        s.applyEventEffect(.netaBoostNextWeek(6), config: cfg)
        XCTAssertEqual(s.netaBoostWeeks, 6)

        s.applyEventEffect(.preoccupyNextWeek(2), config: cfg)
        s.applyEventEffect(.preoccupyNextWeek(1), config: cfg)
        XCTAssertEqual(s.preoccupiedWeeks, 2)
        s.applyEventEffect(.preoccupyNextWeek(7), config: cfg)
        XCTAssertEqual(s.preoccupiedWeeks, 7)
    }

    func testGrowthCeilingAdjustsFloorsAtZeroAndNilIsNoop() {
        var s = GameState(config: cfg)
        s.growthBudget = nil
        s.applyEventEffect(.growthCeiling(10), config: cfg)
        XCTAssertNil(s.growthBudget)                            // 無制限は対象外
        s.growthBudget = 5
        s.applyEventEffect(.growthCeiling(2.5), config: cfg)
        XCTAssertEqual(s.growthBudget ?? -1, 7.5, accuracy: 1e-9)
        s.applyEventEffect(.growthCeiling(-3), config: cfg)
        XCTAssertEqual(s.growthBudget ?? -1, 4.5, accuracy: 1e-9)
        s.applyEventEffect(.growthCeiling(-100), config: cfg)
        XCTAssertEqual(s.growthBudget ?? -1, 0, accuracy: 1e-9)  // 下限0
    }

    func testStaminaCompatAbilityClampBothEnds() {
        var s = GameState(config: cfg)
        s.stamina = 95; s.compat = cfg.compatCap - 1; s.センス = cfg.abilityCap - 1
        s.applyEventEffect(.stamina(50), config: cfg)
        s.applyEventEffect(.compat(50), config: cfg)
        s.applyEventEffect(.ability(.センス, 50), config: cfg)
        XCTAssertEqual(s.stamina, 100, accuracy: 1e-9)
        XCTAssertEqual(s.compat, cfg.compatCap, accuracy: 1e-9)
        XCTAssertEqual(s.センス, cfg.abilityCap, accuracy: 1e-9)
        s.applyEventEffect(.stamina(-500), config: cfg)
        s.applyEventEffect(.compat(-500), config: cfg)
        s.applyEventEffect(.ability(.センス, -500), config: cfg)
        XCTAssertEqual(s.stamina, 0, accuracy: 1e-9)
        XCTAssertEqual(s.compat, 0, accuracy: 1e-9)
        XCTAssertEqual(s.センス, 0, accuracy: 1e-9)
    }

    func testRiftNegativeFromExistingValueAndTieBreaks() {
        var s = GameState(config: cfg)
        s.rift = 40
        s.applyEventEffect(.rift(-15), config: cfg)
        XCTAssertEqual(s.rift ?? -1, 25, accuracy: 1e-9)
        s.applyEventEffect(.rift(-100), config: cfg)
        XCTAssertEqual(s.rift ?? -1, 0, accuracy: 1e-9)
        // センス==発想 の同値はセンスへ（<=）
        s.センス = 20; s.発想 = 20
        s.applyEventEffect(.weakerSenseIdeaPlus(3), config: cfg)
        XCTAssertEqual(s.センス, 23, accuracy: 1e-9)
        XCTAssertEqual(s.発想, 20, accuracy: 1e-9)
    }

    func testWeakestSkillPlusTargetsLowestIncludingHana() {
        var s = GameState(config: cfg)
        s.センス = 30; s.発想 = 25; s.表現 = 20; s.華 = 5; s.メンタル = 0
        s.applyEventEffect(.weakestSkillPlus(4), config: cfg)
        XCTAssertEqual(s.華, 9, accuracy: 1e-9)                 // メンタル0でも対象外
        XCTAssertEqual(s.メンタル, 0, accuracy: 1e-9)
    }

    // MARK: Item

    func testCannotBuyWithoutEnoughMoneyOrOffLineup() {
        var s = GameState(config: cfg)
        s.money = 2_999
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, 2_999)
        XCTAssertNil(s.itemCounts)
        s.money = 3_000                                          // ちょうどなら買える
        XCTAssertTrue(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, 0)
        XCTAssertEqual(s.itemCounts?[ShopItem.栄養ドリンク.rawValue], 1)
    }

    func testDrinkStaminaClampsAtHundred() {
        var s = GameState(config: cfg); s.money = 100_000; s.stamina = 98
        XCTAssertTrue(GameEngine.buy(.回復ドリンク大, to: &s, config: cfg))
        XCTAssertEqual(s.stamina, 100, accuracy: 1e-9)
    }

    func testShinkansenBlockedWhileActiveAndYearlyLimit() {
        var s = GameState(config: cfg); s.money = 1_000_000
        XCTAssertTrue(GameEngine.buy(.新幹線回数券, to: &s, config: cfg))
        XCTAssertEqual(s.shinkansenActive, true)
        XCTAssertFalse(GameEngine.canBuy(.新幹線回数券, state: s, config: cfg))
        GameEngine.resetYearlyItems(&s)
        XCTAssertNil(s.shinkansenActive)
        XCTAssertTrue(GameEngine.canBuy(.新幹線回数券, state: s, config: cfg))
        XCTAssertEqual(s.money, 1_000_000 - 200_000)
    }

    func testSentoTicketsRunOutThenRebuyable() {
        var s = GameState(config: cfg); s.money = 100_000; s.stamina = 0
        XCTAssertTrue(GameEngine.buy(.銭湯の回数券, to: &s, config: cfg))
        XCTAssertEqual(s.sentoTickets, cfg.itemSentoTickets)
        for _ in 0..<cfg.itemSentoTickets { GameEngine.applyRest(.完全休養, to: &s, config: cfg) }
        XCTAssertEqual(s.sentoTickets, 0)
        XCTAssertTrue(GameEngine.canBuy(.銭湯の回数券, state: s, config: cfg))   // 使い切れば買い直せる
        // useTicket: false なら消費しない
        s.sentoTickets = 2
        GameEngine.applyRest(.完全休養, to: &s, config: cfg, useTicket: false)
        XCTAssertEqual(s.sentoTickets, 2)
    }

    func testRelistedStudyAndVoiceGiveCurrencyAndRespectLimits() {
        var c = GameConfig(); c.shopLineup = ShopItem.allCases
        var s = GameState(config: c); s.money = 10_000_000
        let h0 = s[currency: .閃き], g0 = s[currency: .語彙], m0 = s[currency: .間合い]
        XCTAssertTrue(GameEngine.buy(.ネタ作家の勉強会, to: &s, config: c))
        XCTAssertEqual(s[currency: .閃き] - h0, c.itemStudyHirameki, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .語彙] - g0, c.itemStudyGoi, accuracy: 1e-9)
        XCTAssertTrue(GameEngine.buy(.ネタ作家の勉強会, to: &s, config: c))
        XCTAssertFalse(GameEngine.buy(.ネタ作家の勉強会, to: &s, config: c))      // 年2回
        let g1 = s[currency: .語彙]
        XCTAssertTrue(GameEngine.buy(.ボイトレ短期集中, to: &s, config: c))
        XCTAssertEqual(s[currency: .間合い] - m0, c.itemVoiceMaai, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .語彙] - g1, c.itemVoiceGoi, accuracy: 1e-9)
        XCTAssertFalse(GameEngine.buy(.ボイトレ短期集中, to: &s, config: c))      // 年1回
    }

    // MARK: Room

    func testMoveRoomBoundaries() {
        var s = GameState(config: cfg)
        s.money = cfg.roomRents[1] - 1
        XCTAssertFalse(GameEngine.canMoveRoom(to: 1, state: s, config: cfg))
        XCTAssertFalse(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertNil(s.room)
        s.money = cfg.roomRents[1]
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertEqual(s.room, 1)
        XCTAssertEqual(s.money, cfg.roomRents[1])               // お金は引かない
        XCTAssertFalse(GameEngine.canMoveRoom(to: -1, state: s, config: cfg))
        XCTAssertFalse(GameEngine.canMoveRoom(to: cfg.roomRents.count, state: s, config: cfg))
        s.money = 0
        XCTAssertTrue(GameEngine.canMoveRoom(to: 1, state: s, config: cfg))   // 同じ段は無料
        XCTAssertTrue(GameEngine.moveRoom(to: 0, state: &s, config: cfg))     // 下げるのも無料
        XCTAssertNil(s.room)                                                 // 0 は nil に戻る
        XCTAssertEqual(GameEngine.roomRent(s, config: cfg), 0)
    }

    func testBestRoomRestAddsMentalAndHealOnlyForHomeRests() {
        var plain = GameState(config: cfg), best = GameState(config: cfg)
        plain.stamina = 0; best.stamina = 0; best.room = 2
        plain.メンタル = 10; best.メンタル = 10
        GameEngine.applyRest(.完全休養, to: &plain, config: cfg)
        GameEngine.applyRest(.完全休養, to: &best, config: cfg)
        XCTAssertEqual(best.stamina - plain.stamina, cfg.roomHeals[2], accuracy: 1e-9)
        let dm = best.メンタル - plain.メンタル   // 成長逓減がかかるので +1 ちょうどにはならない
        XCTAssertGreaterThan(dm, 0); XCTAssertLessThanOrEqual(dm, cfg.roomBestMental)
        // 部屋1は体力だけ（メンタル上乗せなし）
        var mid = GameState(config: cfg); mid.stamina = 0; mid.room = 1; mid.メンタル = 10
        GameEngine.applyRest(.完全休養, to: &mid, config: cfg)
        XCTAssertEqual(mid.stamina - plain.stamina, cfg.roomHeals[1], accuracy: 1e-9)
        XCTAssertEqual(mid.メンタル, plain.メンタル, accuracy: 1e-9)
    }
}
