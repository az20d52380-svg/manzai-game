// LateCareerCalendar1108Tests.swift
// 結成15年（GameConfig.careerYears=15）に延びた後の、既定のカレンダーで「その年に出られる道中の大会」を年ごとに固定する。
// 11年目以降は結成10年以内の4大会（春新人A/B・夏中堅・寒梅）が外れ、大阪戎と推薦制中堅賞（知名度30以上）だけが残る。
// Sources は不変（表の値を変えたらここも合わせる＝意図した変更かを確かめるための鍵）。

import XCTest
@testable import GameCore

final class LateCareerCalendar1108Tests: XCTestCase {
    let cal = CalendarConfig()

    private func eligibleNames(year: Int, fame: Double) -> [String] {
        var s = GameState(config: GameConfig())
        s.fame = fame
        return cal.tournaments.filter { $0.isEligible(year: year, state: s) }.map(\.name)
    }

    func testCareerLengthIsFifteen() {
        XCTAssertEqual(GameConfig().careerYears, 15)
    }

    func testEligibleSetByYearWithLowFame() {
        let early = ["春新人賞A", "春新人賞B", "夏中堅賞", "大阪戎コンクール", "若手限定賞", "寒梅漫才杯"]
        let mid = ["春新人賞A", "春新人賞B", "夏中堅賞", "大阪戎コンクール", "寒梅漫才杯"]
        for y in 1...5 { XCTAssertEqual(eligibleNames(year: y, fame: 0), early, "year \(y)") }
        for y in 6...10 { XCTAssertEqual(eligibleNames(year: y, fame: 0), mid, "year \(y)") }
        for y in 11...15 { XCTAssertEqual(eligibleNames(year: y, fame: 0), ["大阪戎コンクール"], "year \(y)") }
    }

    func testLateYearsKeepRecommendedTournamentWithFame() {
        for y in 11...15 {
            XCTAssertEqual(eligibleNames(year: y, fame: 30), ["大阪戎コンクール", "推薦制中堅賞"], "year \(y)")
        }
    }

    func testEveryYearHasAtLeastOneRoadTournament() {
        for y in 1...GameConfig().careerYears {
            XCTAssertFalse(eligibleNames(year: y, fame: 0).isEmpty, "year \(y)")
        }
    }
}
