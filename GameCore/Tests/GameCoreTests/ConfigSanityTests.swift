// ConfigSanityTests.swift
// 設定表の健全性（週の重なり・昇順・件数の一致・重みの合計）を固定する。Sources・golden は不変。

import XCTest
@testable import GameCore

final class ConfigSanityTests: XCTestCase {
    private let cfg = GameConfig()

    func testTournamentWeeksUniqueAndInYear() {
        let ws = cfg.calendar.tournaments.map(\.week)
        XCTAssertEqual(Set(ws).count, ws.count, "大会の週が重なっている")
        for w in ws { XCTAssertTrue((1...cfg.weeks).contains(w), "week \(w)") }
        for t in cfg.calendar.tournaments {
            XCTAssertGreaterThan(t.line, 0, t.name)
            XCTAssertGreaterThan(t.prize, 0, t.name)
        }
    }

    func testGpRoundsAscendAndFinalAfter() {
        let c = cfg.calendar
        XCTAssertEqual(c.gpRounds.count, c.gpRoundNames.count)
        XCTAssertEqual(c.gpRounds.map(\.week), c.gpRounds.map(\.week).sorted())
        XCTAssertEqual(Set(c.gpRounds.map(\.week)).count, c.gpRounds.count)
        XCTAssertEqual(c.gpRounds.map(\.line), c.gpRounds.map(\.line).sorted())
        XCTAssertGreaterThan(c.gpFinalWeek, c.gpRounds.last!.week)
        XCTAssertLessThanOrEqual(c.gpFinalWeek, cfg.weeks)
        XCTAssertLessThan(c.gpRevivalLine, c.gpFinalLine)
        XCTAssertGreaterThan(c.gpFinalLine, c.gpRounds.last!.line)
    }

    func testGpWeeksDoNotCollideWithTournaments() {
        let c = cfg.calendar
        let gpWeeks = Set(c.gpRounds.map(\.week) + [c.gpFinalWeek])
        for t in c.tournaments { XCTAssertFalse(gpWeeks.contains(t.week), t.name) }
    }

    func testGpLossCompatNonIncreasingAndCoversRounds() {
        let l = cfg.gpLossCompat
        XCTAssertGreaterThanOrEqual(l.count, cfg.calendar.gpRounds.count)
        XCTAssertEqual(l, l.sorted(by: >))
        XCTAssertTrue(l.allSatisfy { $0 >= 0 })
    }

    func testOfferCardFamesAscendAndRatesCoverFame() {
        XCTAssertEqual(cfg.offerCardFames, cfg.offerCardFames.sorted())
        XCTAssertEqual(Set(cfg.offerCardFames).count, cfg.offerCardFames.count)
        XCTAssertGreaterThanOrEqual(cfg.offerRates.last!.fameBelow, 100)   // 最後の帯が知名度の上限を覆う
        XCTAssertTrue(cfg.offerRates.allSatisfy { $0.rate > 0 && $0.rate <= 1 })
        XCTAssertTrue(cfg.offersNamed.allSatisfy { $0.income > 0 && $0.stamina < 0 })
    }

    func testRoomTablesAlignAndAscend() {
        XCTAssertEqual(cfg.roomRents.count, cfg.roomHeals.count)
        XCTAssertEqual(cfg.roomRents, cfg.roomRents.sorted())
        XCTAssertEqual(cfg.roomHeals, cfg.roomHeals.sorted())
        XCTAssertEqual(cfg.roomRents.first, 0)
    }

    func testVenueTiersAscendAndScoreWeightsSumToOne() {
        XCTAssertLessThan(cfg.venueTier1Money, cfg.venueTier2Money)
        XCTAssertLessThan(cfg.venueTier2Money, cfg.venueTier3Money)
        let w = cfg.weightSense + cfg.weightIdea + cfg.weightExpr + cfg.weightChara
        XCTAssertEqual(w, 1.0, accuracy: 1e-9)
    }

    func testCapsAndThresholdsOrdered() {
        XCTAssertLessThan(cfg.initAbility, cfg.abilityCap)
        XCTAssertLessThanOrEqual(cfg.initStamina, 100)
        XCTAssertLessThan(cfg.compatInit, cfg.compatCap)
        XCTAssertLessThan(cfg.bankruptLine, 0)
        XCTAssertLessThan(cfg.staminaGate, cfg.injuryThreshold)
    }
}
