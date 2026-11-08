// EndingJudge15Years1108Tests.swift
// 既定の結成15年（GameConfig.careerYears）でエンディングの判定を固定する（既存のテストは careerYears: 10 固定だった）。
import XCTest
import GameCore
@testable import ManzaiGame

final class EndingJudge15Years1108Tests: XCTestCase {
    private let cy = GameConfig().careerYears
    private func rec(_ y: Int, final f: Bool = false, champ: Bool = false) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: 1, reachedFinal: f, champion: champ, bankrupt: false, prize: 0)
    }
    private func out() -> YearOutcome {
        YearOutcome(champion: false, roundsPassed: 0, reachedFinal: false, bankrupt: false, dissolved: false)
    }

    func testDefaultIsFifteen() { XCTAssertEqual(cy, 15) }

    func testYearsTenToFourteenStillContinue() {
        for y in 10..<cy {
            XCTAssertNil(EndingID.judge(outcome: out(), compat: 99, history: [rec(3, final: true)], year: y, careerYears: cy), "year \(y)")
        }
    }

    func testLastYearPicksByFinalsAndCompat() {
        let withFinal = [rec(12, final: true)]
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 15, history: withFinal, year: cy, careerYears: cy), .tenYearsTrue)
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 14.9, history: withFinal, year: cy, careerYears: cy), .tenYearsClose)
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 15, history: [rec(1)], year: cy, careerYears: cy), .keptGoing)
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 14.9, history: [rec(1)], year: cy, careerYears: cy), .gaveUp)
    }

    func testWonEarlierThenRanToLastYear() {
        let h = [rec(11, final: true, champ: true), rec(14)]
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 15, history: h, year: cy, careerYears: cy), .championPair)
        XCTAssertEqual(EndingID.judge(outcome: out(), compat: 14.9, history: h, year: cy, careerYears: cy), .championRetire)
    }
}
