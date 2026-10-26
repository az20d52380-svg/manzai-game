// CoverageAB1025Tests.swift
// 薄かった公開関数（rollInvite / offerFatigued / netaScoreBonus / extraOffers / rollOffer / pourable）の不変条件。Sources は不変。

import XCTest
@testable import GameCore

final class CoverageAB1025Tests: XCTestCase {
    let cfg = GameConfig()

    func testRollInviteDeterministicAndRateZeroIsNil() {
        for w in 1...48 {
            XCTAssertEqual(GameEngine.rollInvite(seed: 7, year: 2, week: w, config: cfg),
                           GameEngine.rollInvite(seed: 7, year: 2, week: w, config: cfg))
        }
        var off = cfg; off.inviteRate = 0
        for w in 1...48 { XCTAssertNil(GameEngine.rollInvite(seed: 7, year: 1, week: w, config: off)) }
    }

    func testRollInviteRateOneAlwaysInvitesAndIdeaPExtremes() {
        var c = cfg; c.inviteRate = 1.0; c.inviteIdeaP = 1.0
        for w in 1...20 { XCTAssertEqual(GameEngine.rollInvite(seed: 99, year: 1, week: w, config: c), true) }
        c.inviteIdeaP = 0.0
        for w in 1...20 { XCTAssertEqual(GameEngine.rollInvite(seed: 99, year: 1, week: w, config: c), false) }
    }

    func testOfferFatiguedThresholdAndWindow() {
        var s = GameState(config: cfg)
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 10, config: cfg))
        let k = cfg.offerFatigueK
        s.offerWeeks = Array(repeating: 10, count: k - 1)
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 10, config: cfg))
        s.offerWeeks = Array(repeating: 10, count: k)
        XCTAssertTrue(GameEngine.offerFatigued(state: s, atWeek: 10, config: cfg))
        // 窓の外に出れば解消
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 10 + cfg.offerFatigueWindow, config: cfg))
    }

    func testNetaScoreBonusNoSelectionIsZero() {
        let s = GameState(config: cfg)
        XCTAssertEqual(GameEngine.netaScoreBonus(s, isFinal: false, config: cfg), 0)
        XCTAssertEqual(GameEngine.netaScoreBonus(s, isFinal: true, config: cfg), 0)
    }

    func testNetaScoreBonusClampedAndFinalPenalty() {
        var s = GameState(config: cfg)
        var n = Neta(id: 1, name: "テスト", kata: NetaKata.allCases[0], lengthFit: [], bornYear: 1)
        n.polish = 100; n.buzz = 100
        s.netas = [n]; s.selectedNetaID = 1
        let hi = GameEngine.netaScoreBonus(s, isFinal: false, config: cfg)
        XCTAssertLessThanOrEqual(hi, cfg.netaScoreClamp + 1e-12)
        n.polish = 0; n.buzz = 0
        s.netas = [n]
        let lo = GameEngine.netaScoreBonus(s, isFinal: false, config: cfg)
        XCTAssertGreaterThanOrEqual(lo, -cfg.netaScoreClamp - 1e-12)
        XCTAssertLessThan(lo, hi)
        // 決勝で2本目なしなら減点される
        let fin = GameEngine.netaScoreBonus(s, isFinal: true, config: cfg)
        XCTAssertEqual(fin, lo - cfg.netaSecondPenalty, accuracy: 1e-12)
    }

    func testExtraOffersDeterministicDistinctAndEmptyBelowThreshold() {
        let first = cfg.offersNamed[0]
        XCTAssertTrue(GameEngine.extraOffers(first: first, fame: 0, seed: 1, year: 1, week: 1, config: cfg).isEmpty)
        let a = GameEngine.extraOffers(first: first, fame: 100, seed: 5, year: 3, week: 9, config: cfg)
        let b = GameEngine.extraOffers(first: first, fame: 100, seed: 5, year: 3, week: 9, config: cfg)
        XCTAssertEqual(a.map { $0.name }, b.map { $0.name })
        XCTAssertEqual(a.count, cfg.offerCardFames.count)
        XCTAssertFalse(a.contains { $0.name == first.name })
        XCTAssertEqual(Set(a.map { $0.name }).count, a.count)
    }

    func testRollOfferNeverFiresWhenRngAboveAnyRateAndAlwaysWhenZero() {
        let s = GameState(config: cfg)
        var hi = FixedRandom(value: 0.999999)
        XCTAssertNil(GameEngine.rollOffer(state: s, config: cfg, rng: &hi))
        var lo = FixedRandom(value: 0.0)
        let o = GameEngine.rollOffer(state: s, config: cfg, rng: &lo)
        XCTAssertNotNil(o)
        XCTAssertTrue(cfg.offersNamed.contains { $0.name == o!.name })
    }

    func testPourRecommendedKeepsAbilitiesFiniteAndNonDecreasing() {
        var s = GameState(config: cfg)
        let before = Ability.allCases.map { s[$0] }
        GameEngine.pourRecommended(to: &s, config: cfg)
        let after = Ability.allCases.map { s[$0] }
        for (b, a) in zip(before, after) { XCTAssertTrue(a.isFinite); XCTAssertGreaterThanOrEqual(a, b - 1e-9) }
    }
}
