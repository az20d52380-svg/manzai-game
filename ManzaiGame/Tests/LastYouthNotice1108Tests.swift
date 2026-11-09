// LastYouthNotice1108Tests.swift
// 芸歴の上限がある大会の「今年が最後」の一言：結成15年では5年目（若手限定賞）と10年目（春新人A/B・夏中堅・寒梅）の2回出る。
import XCTest
import GameCore
@testable import ManzaiGame

final class LastYouthNotice1108Tests: XCTestCase {
    func testYearFiveKeepsOriginalLine() {
        XCTAssertEqual(WeekMainView.lastYouthNoticeText(year: 5, config: GameConfig()),
                       "谷口「若手限定の大会に出られるのは、今年が最後だ」")
    }

    func testYearTenNamesTheFourCappedTournaments() {
        XCTAssertEqual(WeekMainView.lastYouthNoticeText(year: 10, config: GameConfig()),
                       "谷口「春の新人賞、夏中堅賞、寒梅漫才杯。どれも出られるのは今年が最後だ」")
    }

    func testOtherYearsHaveNoLine() {
        for y in [1, 4, 6, 9, 11, 15] {
            XCTAssertNil(WeekMainView.lastYouthNoticeText(year: y, config: GameConfig()), "year \(y)")
        }
    }

    func testCapEqualToCareerLengthIsSilent() {
        var c = GameConfig()
        c.careerYears = 10   // 旧10年制：10年目は最終年なので出さない（従来どおり）
        XCTAssertNil(WeekMainView.lastYouthNoticeText(year: 10, config: c))
    }
}
