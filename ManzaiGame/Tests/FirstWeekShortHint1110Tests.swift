import XCTest
@testable import ManzaiGame

/// キュー144 案③：初回に自動で出す「はじめに」は2語だけ、左上の「？」は5語のまま。
final class FirstWeekShortHint1110Tests: XCTestCase {
    func testShortHintKeepsTwoTermsAndSameKey() {
        let short = WeekMainView.firstWeekShortHint, full = WeekMainView.firstWeekHint
        XCTAssertEqual(short.rows.map(\.term), ["体力", "知名度"])
        XCTAssertEqual(short.key, full.key, "既読の印は同じ鍵（短い版を見たら5語の版は自動で出ない）")
        XCTAssertEqual(full.rows.count, 5, "「？」の読み返しは5語のまま")
        XCTAssertTrue(short.rows.allSatisfy { r in full.rows.contains(r) }, "文面は5語の版と同じ")
    }
}
