// TrophyLastYear1108Tests.swift
// t18（優勝しないまま最後の年まで走り切る）は既定の結成15年の年末だけで取れる（10年目では取れない）。
import XCTest
import GameCore
@testable import ManzaiGame

final class TrophyLastYear1108Tests: IsolatedStoreTestCase {
    private let cy = GameConfig().careerYears
    private func out(champ: Bool = false, bank: Bool = false, diss: Bool = false) -> YearOutcome {
        YearOutcome(champion: champ, roundsPassed: 0, reachedFinal: false, bankrupt: bank, dissolved: diss)
    }
    private func end(_ o: YearOutcome, year: Int, wonBefore: Bool = false) {
        TrophyBook.onYearEnd(outcome: o, year: year, careerYears: cy, smallEntered: 0, smallWon: 0, wonBefore: wonBefore)
    }

    func testYearTenDoesNotAward() {
        end(out(), year: 10)
        XCTAssertFalse(TrophyBook.load().contains(.t18))
    }

    func testLastYearAwards() {
        end(out(), year: cy)
        XCTAssertTrue(TrophyBook.load().contains(.t18))
    }

    func testLastYearAfterEarlierWinDoesNotAward() {
        end(out(), year: cy, wonBefore: true)
        XCTAssertFalse(TrophyBook.load().contains(.t18))
    }

    func testBankruptOrDissolvedInLastYearDoesNotAward() {
        end(out(bank: true), year: cy)
        end(out(diss: true), year: cy)
        XCTAssertFalse(TrophyBook.load().contains(.t18))
    }
}
