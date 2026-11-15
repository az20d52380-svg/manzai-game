import XCTest
@testable import ManzaiGame

/// 候補 rift-again-hint：予告の後にすれ違いがまた高い週は、週の上の一言で知らせる
final class RiftAgainHint1116Tests: XCTestCase {
    private func base() -> WeekHint.Input {
        .init(netaCount: 1, stamina: 80, livingThisWeek: false, money: 500_000, livingCost: 140_000,
              weeksWithoutPartner: 0, plusAvailable: false, expBannerShown: false)
    }
    func testRiftAgainLine() {
        var i = base(); XCTAssertNil(WeekHint.line(i))
        i.riftAgain = true; XCTAssertEqual(WeekHint.line(i), "相方との間に、また距離ができている。")
    }
    func testMoneyAndStaminaComeFirst() {
        var i = base(); i.riftAgain = true; i.stamina = 10
        XCTAssertEqual(WeekHint.line(i), "体力が少ない。今週は休むのも手だ。")
        i.stamina = 80; i.livingThisWeek = true; i.money = 0
        XCTAssertEqual(WeekHint.line(i), "今週末に生活費14万円。所持金が足りない。")
    }
    func testBeforePartnerGap() {
        var i = base(); i.riftAgain = true; i.weeksWithoutPartner = 9
        XCTAssertEqual(WeekHint.line(i), "相方との間に、また距離ができている。")
    }
}
