// ConfigTableInvariantTests.swift
// GameConfig の表の整合（昇順・抜け・重みの合計）を固定する。式・乱数・golden・ソースは不変。

import XCTest
@testable import GameCore

final class ConfigTableInvariantTests: XCTestCase {
    private let cfg = GameConfig()

    func testAbilityRecipesCoverAllAndSumToOne() {
        for a in Ability.allCases {
            let r = cfg.abilityRecipes[a]
            XCTAssertNotNil(r, "\(a)")
            let total = (r ?? []).reduce(0) { $0 + $1.1 }
            XCTAssertEqual(total, 1.0, accuracy: 1e-9, "\(a)")
            XCTAssertTrue((r ?? []).allSatisfy { $0.1 > 0 }, "\(a)")
        }
    }

    func testRankCostBandsAscendBelowS() {
        let b = cfg.abilityRankCostBands
        XCTAssertEqual(b.map(\.threshold), b.map(\.threshold).sorted())
        XCTAssertEqual(b.map(\.multiplier), b.map(\.multiplier).sorted())
        XCTAssertLessThan(b.last!.multiplier, cfg.abilityRankCostMultS)
    }

    func testStepTablesAscend() {
        XCTAssertEqual(cfg.offerRates.map(\.fameBelow), cfg.offerRates.map(\.fameBelow).sorted())
        XCTAssertEqual(cfg.offerRates.map(\.rate), cfg.offerRates.map(\.rate).sorted())
        let p = cfg.staminaPenalties
        XCTAssertEqual(p.map(\.below), p.map(\.below).sorted())
        XCTAssertEqual(p.map(\.penalty), p.map(\.penalty).sorted())   // 体力が低いほど罰が重い
    }

    func testEveryActionHasSpec() {
        for t in Training.allCases { XCTAssertNotNil(cfg.trainings[t], "\(t)") }
        for j in Job.allCases { XCTAssertNotNil(cfg.jobs[j], "\(j)") }
        for r in Rest.allCases { XCTAssertNotNil(cfg.rests[r], "\(r)") }
        for s in cfg.shopLineup { XCTAssertNotNil(cfg.items[s], "\(s)") }
    }
}
