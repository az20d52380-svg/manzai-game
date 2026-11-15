// 端末の日付を一度未来へ進めて札を取っても、以後ずっと取れなくならない（code_review_unreviewed_1115 #2・AUTOPILOT 439②）
import XCTest
@testable import ManzaiGame

final class GachaLoginFutureDay1116Tests: XCTestCase {
    func testFutureDayDoesNotLockOut() {
        var s = GachaState()
        XCTAssertTrue(s.claimLogin(today: "2027-03-01"))   // 未来へ進めて取った
        XCTAssertTrue(s.claimLogin(today: "2026-11-16"))   // 戻した後も取れる
        XCTAssertFalse(s.claimLogin(today: "2026-11-16"))  // 同じ日の二度目は取れない
        XCTAssertTrue(s.claimLogin(today: "2026-11-17"))
    }
    func testOneDayBackStillBlocked() {
        var s = GachaState()
        XCTAssertTrue(s.claimLogin(today: "2026-11-02"))
        XCTAssertFalse(s.canClaimLogin(today: "2026-11-01"))   // 時差の1日戻りは取れない（今までどおり）
    }
    func testNextDayKeyAcrossMonthAndYear() {
        XCTAssertEqual(GachaState.nextDayKey("2026-12-31"), "2027-01-01")
        XCTAssertEqual(GachaState.nextDayKey("2028-02-28"), "2028-02-29")
        XCTAssertNil(GachaState.nextDayKey(""))
    }
}
