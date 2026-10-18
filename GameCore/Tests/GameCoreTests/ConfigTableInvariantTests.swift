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
    func testActionSigns() {
        for (t, spec) in cfg.trainings {
            XCTAssertGreaterThan(spec.main.1, 0, "\(t)")
            XCTAssertGreaterThanOrEqual(spec.cost, 0, "\(t)")
            XCTAssertLessThan(spec.stamina, 0, "\(t)")
        }
        // バイト：キツいほど稼げて体力も減る
        let k = cfg.jobs[.キツい]!, m = cfg.jobs[.標準]!, e = cfg.jobs[.楽]!
        XCTAssertGreaterThan(k.income, m.income); XCTAssertGreaterThan(m.income, e.income); XCTAssertGreaterThan(e.income, 0)
        XCTAssertLessThan(k.stamina, m.stamina); XCTAssertLessThan(m.stamina, e.stamina); XCTAssertLessThan(e.stamina, 0)
        // 休み：有料は無料の完全休養より戻りが大きい
        for (r, v) in cfg.rests { XCTAssertGreaterThan(v.recovery, 0, "\(r)") }
        for (r, cost) in cfg.restCosts {
            XCTAssertGreaterThan(cost, 0, "\(r)")
            XCTAssertGreaterThan(cfg.rests[r]!.recovery, cfg.rests[.完全休養]!.recovery, "\(r)")
        }
        for (i, spec) in cfg.items {
            XCTAssertGreaterThan(spec.price, 0, "\(i)")
            XCTAssertFalse(spec.summary.isEmpty, "\(i)")
        }
    }
}
