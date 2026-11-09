import XCTest
@testable import ManzaiGame

/// お店の最上段の衣装ガチャの札：未受取の印の出し分け（表示だけ）
final class GachaEntry1107Tests: XCTestCase {
    func testBadgeFollowsLoginClaimability() {
        var g = GachaState()
        XCTAssertTrue(g.canClaimLogin(today: "2026-11-07"))
        XCTAssertEqual(ShopView.gachaBadge(canClaimToday: g.canClaimLogin(today: "2026-11-07")), "今日の札")
        g.claimLogin(today: "2026-11-07")
        XCTAssertEqual(ShopView.gachaBadge(canClaimToday: g.canClaimLogin(today: "2026-11-07")), "新")
        XCTAssertEqual(ShopView.gachaBadge(canClaimToday: g.canClaimLogin(today: "2026-11-08")), "今日の札")
    }
}
