// CoverageGaps1025Tests.swift
// 薄かった所（SplitMix64 の再開・uniform(in:)・TravelSpec・ItemSpec・EventEffect の clamp・JudgeTalk の決定性）。Sources/式/golden は不変。

import XCTest
@testable import GameCore

final class CoverageGaps1025Tests: XCTestCase {
    let cfg = GameConfig()

    func testUniformInRangeBoundsAndDeterminism() {
        var a = SplitMix64(seed: 42), b = SplitMix64(seed: 42)
        for _ in 0..<200 {
            let x = a.uniform(in: -3.0...5.0)
            XCTAssertGreaterThanOrEqual(x, -3.0)
            XCTAssertLessThan(x, 5.0)
            XCTAssertEqual(x, b.uniform(in: -3.0...5.0))
        }
    }

    func testUniformDegenerateRangeReturnsBound() {
        var r = SplitMix64(seed: 1)
        XCTAssertEqual(r.uniform(in: 2.5...2.5), 2.5)
    }

    func testSplitMixCodableResumeKeepsSequence() throws {
        var r = SplitMix64(seed: 99)
        for _ in 0..<5 { _ = r.nextUInt64() }
        var copy = try JSONDecoder().decode(SplitMix64.self, from: JSONEncoder().encode(r))
        for _ in 0..<20 { XCTAssertEqual(r.nextUInt64(), copy.nextUInt64()) }
    }

    func testTravelSpecInitAndConfigLookup() {
        let t = TravelSpec(cost: 123, stamina: -4)
        XCTAssertEqual(t.cost, 123)
        XCTAssertEqual(t.stamina, -4)
        XCTAssertEqual(cfg.calendar.travelSpec(.夜行バス).cost, cfg.calendar.busTravel.cost)
        XCTAssertEqual(cfg.calendar.travelSpec(.新幹線).cost, cfg.calendar.trainTravel.cost)
        XCTAssertGreaterThan(cfg.calendar.trainTravel.cost, cfg.calendar.busTravel.cost)
    }

    func testItemSpecInitStoresFields() {
        let s = ItemSpec(price: 500, yearlyLimit: nil, summary: "x")
        XCTAssertEqual(s.price, 500)
        XCTAssertNil(s.yearlyLimit)
        XCTAssertEqual(s.summary, "x")
    }

    func testEventEffectClampsAtBounds() {
        var s = GameState(config: cfg)
        s.applyEventEffect(.compat(1_000), config: cfg)
        XCTAssertEqual(s.compat, cfg.compatCap)
        s.applyEventEffect(.compat(-1_000), config: cfg)
        XCTAssertEqual(s.compat, 0)
        s.applyEventEffect(.stamina(1_000), config: cfg)
        XCTAssertEqual(s.stamina, 100)
        s.applyEventEffect(.fame(-1_000), config: cfg)
        XCTAssertEqual(s.fame, 0)
        s.applyEventEffect(.ability(.メンタル, 1_000), config: cfg)
        XCTAssertEqual(s[.メンタル], cfg.mentalCap)
        s.applyEventEffect(.ability(.センス, 1_000), config: cfg)
        XCTAssertEqual(s[.センス], cfg.abilityCap)
    }

    func testEventEffectMoneyUnclampedAndRiftFromNil() {
        var s = GameState(config: cfg)
        let m0 = s.money
        s.applyEventEffect(.money(-(m0 + 777)), config: cfg)
        XCTAssertEqual(s.money, -777)
        s.rift = nil
        s.applyEventEffect(.rift(-5), config: cfg)
        XCTAssertEqual(s.rift, 0)
        s.applyEventEffect(.rift(500), config: cfg)
        XCTAssertEqual(s.rift, 100)
    }

    func testGrowthCeilingNilNoopAndFloorZero() {
        var s = GameState(config: cfg)
        s.growthBudget = nil
        s.applyEventEffect(.growthCeiling(-10), config: cfg)
        XCTAssertNil(s.growthBudget)
        s.growthBudget = 5
        s.applyEventEffect(.growthCeiling(-100), config: cfg)
        XCTAssertEqual(s.growthBudget, 0)
    }

    func testFreezeAndBoostKeepLongerValue() {
        var s = GameState(config: cfg)
        s.applyEventEffect(.compatFreeze(3), config: cfg)
        s.applyEventEffect(.compatFreeze(1), config: cfg)
        XCTAssertEqual(s.compatFreezeWeeks, 3)
        s.applyEventEffect(.netaBoostNextWeek(2), config: cfg)
        s.applyEventEffect(.netaBoostNextWeek(1), config: cfg)
        XCTAssertEqual(s.netaBoostWeeks, 2)
    }

    func testFinalCommentDeterministicNonEmptyForAllJudges() {
        let scene = JudgeTalk.Scene(netaName: "商店街の福引", kata: .伏線回収)
        for j in JudgeTalk.judgeNames {
            for high in [true, false] {
                let a = JudgeTalk.finalComment(judge: j, score: 85, high: high, scene: scene, salt: 3)
                let b = JudgeTalk.finalComment(judge: j, score: 85, high: high, scene: scene, salt: 3)
                XCTAssertEqual(a, b)
                XCTAssertFalse(a.text.isEmpty)
            }
        }
    }

    func testPickupNilForUnknownText() {
        XCTAssertNil(JudgeTalk.pickup(after: ""))
        XCTAssertNil(JudgeTalk.pickup(after: "どの行頭にも当たらない文章。"))
    }
}
