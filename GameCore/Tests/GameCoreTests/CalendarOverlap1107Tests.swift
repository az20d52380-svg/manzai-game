// 年間の日程の週の重なり（code_review_1107c「週を動かした時の重なり検出テストは無い」）。
// tournament(inWeek:state:) は道中を先に返すので、同じ週に大会を置くと後の大会が黙って消える。

import XCTest
@testable import GameCore

final class CalendarOverlap1107Tests: XCTestCase {
    func testNoTwoStagesShareAWeek() {
        let cal = GameConfig().calendar
        let weeks = cal.tournaments.map(\.week) + cal.hanaTournaments.map(\.week) + cal.gpRounds.map(\.week) + [cal.gpFinalWeek]
        let dup = Dictionary(grouping: weeks, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        XCTAssertEqual(dup, [], "同じ週に大会が2つある: \(dup)")
    }
    func testAllStagesInsideTheYear() {
        let c = GameConfig()
        let cal = c.calendar
        for w in cal.tournaments.map(\.week) + cal.hanaTournaments.map(\.week) + cal.gpRounds.map(\.week) + [cal.gpFinalWeek] {
            XCTAssertTrue((1...c.weeks).contains(w), "週 \(w) が年の外")
        }
    }
    func testGPRoundNamesMatchRounds() {
        let cal = GameConfig().calendar
        XCTAssertEqual(cal.gpRoundNames.count, cal.gpRounds.count)
    }
}
