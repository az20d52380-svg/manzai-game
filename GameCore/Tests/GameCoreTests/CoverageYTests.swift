// CoverageYTests.swift
// カレンダー（大会の出場資格の境界・週引き・GPの週の並び）と、WeekAction/Travel/Eligibility の Codable 往復の固定。
// Sources は不変。

import XCTest
@testable import GameCore

final class CoverageYTests: XCTestCase {
    let cal = CalendarConfig()

    private func spec(_ e: TournamentSpec.Eligibility) -> TournamentSpec {
        TournamentSpec(name: "t", week: 1, line: 10, prize: 0, fame: 0, osaka: false, eligibility: e)
    }

    // MARK: 出場資格の境界

    func testFameAtLeastBoundaryIsInclusive() {
        let t = spec(.fameAtLeast(30))
        var s = GameState(config: GameConfig())
        s.fame = 29.999
        XCTAssertFalse(t.isEligible(year: 1, state: s))
        s.fame = 30
        XCTAssertTrue(t.isEligible(year: 1, state: s))
        s.fame = 100
        XCTAssertTrue(t.isEligible(year: 1, state: s))
    }

    func testCareerYearAtMostBoundaryAndAlwaysIgnoreState() {
        let s = GameState(config: GameConfig())
        let t = spec(.careerYearAtMost(3))
        XCTAssertTrue(t.isEligible(year: 3, state: s))
        XCTAssertFalse(t.isEligible(year: 4, state: s))
        XCTAssertFalse(spec(.careerYearAtMost(0)).isEligible(year: 1, state: s))
        XCTAssertTrue(spec(.always).isEligible(year: 999, state: s))
    }

    // MARK: 週引き

    func testTournamentInWeekFindsEachAndNilOtherwise() {
        for t in cal.tournaments {
            XCTAssertEqual(cal.tournament(inWeek: t.week)?.name, t.name)
        }
        XCTAssertNil(cal.tournament(inWeek: 1))
        XCTAssertNil(cal.tournament(inWeek: 0))
        XCTAssertNil(cal.tournament(inWeek: 49))
        XCTAssertNil(cal.tournament(inWeek: cal.gpFinalWeek))   // GP決勝週は道中の大会ではない
    }

    func testTournamentWeeksAreUniqueAndAvoidGPWeeks() {
        let weeks = cal.tournaments.map { $0.week }
        XCTAssertEqual(Set(weeks).count, weeks.count)
        let gpWeeks = Set(cal.gpRounds.map { $0.week } + [cal.gpFinalWeek])
        XCTAssertTrue(gpWeeks.isDisjoint(with: weeks))
    }

    func testGPRoundsAscendingWithMatchingNamesAndRevivalBelowFinal() {
        let weeks = cal.gpRounds.map { $0.week }, lines = cal.gpRounds.map { $0.line }
        XCTAssertEqual(weeks, weeks.sorted())
        XCTAssertEqual(lines, lines.sorted())
        XCTAssertEqual(cal.gpRoundNames.count, cal.gpRounds.count)
        XCTAssertGreaterThan(cal.gpFinalWeek, weeks.last!)
        XCTAssertLessThan(cal.gpRevivalLine, cal.gpFinalLine)
        XCTAssertGreaterThan(cal.gpRevivalLine, lines.last!)
    }

    // MARK: Codable 往復

    func testEligibilityCodableRoundTrip() throws {
        let cases: [TournamentSpec.Eligibility] = [.always, .careerYearAtMost(7), .fameAtLeast(42.5)]
        for e in cases {
            let d = try JSONDecoder().decode(TournamentSpec.Eligibility.self, from: JSONEncoder().encode(e))
            let s = GameState(config: GameConfig())
            XCTAssertEqual(spec(d).isEligible(year: 7, state: s), spec(e).isEligible(year: 7, state: s))
            XCTAssertEqual(spec(d).isEligible(year: 8, state: s), spec(e).isEligible(year: 8, state: s))
        }
        let e = try JSONDecoder().decode(TournamentSpec.Eligibility.self,
                                         from: JSONEncoder().encode(TournamentSpec.Eligibility.careerYearAtMost(7)))
        guard case .careerYearAtMost(let n) = e else { return XCTFail("case lost") }
        XCTAssertEqual(n, 7)
    }

    func testTournamentSpecCodableRoundTrip() throws {
        let src = cal.tournaments[0]
        let o = try JSONDecoder().decode(TournamentSpec.self, from: JSONEncoder().encode(src))
        XCTAssertEqual(o.name, src.name)
        XCTAssertEqual(o.week, src.week)
        XCTAssertEqual(o.line, src.line)
        XCTAssertEqual(o.prize, src.prize)
        XCTAssertEqual(o.fame, src.fame)
        XCTAssertEqual(o.osaka, src.osaka)
    }

    func testWeekActionAndTravelCodableRoundTrip() throws {
        let acts: [WeekAction] = [.train(.ネタ合わせ), .job(.楽), .rest(.完全休養), .acceptOffer]
        for a in acts {
            let o = try JSONDecoder().decode(WeekAction.self, from: JSONEncoder().encode(a))
            XCTAssertEqual(String(describing: o), String(describing: a))
        }
        for t in [Travel.夜行バス, .新幹線] {
            let o = try JSONDecoder().decode(Travel.self, from: JSONEncoder().encode(t))
            XCTAssertEqual(cal.travelSpec(o).cost, cal.travelSpec(t).cost)
        }
    }
}
