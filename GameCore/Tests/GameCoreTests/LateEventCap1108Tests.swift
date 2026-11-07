import XCTest
@testable import GameCore

/// 週次イベントの通算上限（6年目以降は年ごとに +3・年は1始まり）。late_events_cand_1108
final class LateEventCap1108Tests: XCTestCase {
    func testCapFlatUpToYear5() {
        let c = GameConfig()
        for y in 1...5 { XCTAssertEqual(c.weeklyEventCap(year: y), 15, "\(y)年目まで15固定") }
    }
    func testCapGrowsFromYear6() {
        let c = GameConfig()
        XCTAssertEqual(c.weeklyEventCap(year: 6), 18)
        XCTAssertEqual(c.weeklyEventCap(year: 10), 30)
        XCTAssertEqual(c.weeklyEventCap(year: 15), 45)
    }
}
