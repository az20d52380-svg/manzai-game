// 生活費の予告の金額：やりくり上手（0.95倍）の 133,000円 が整数割りで「13万円」と切り捨てて出ていた（11/08 定期の文の採点で発見）
import XCTest
@testable import ManzaiGame

final class WeekHintLivingMan1108Tests: XCTestCase {
    private func base(livingCost: Int) -> WeekHint.Input {
        .init(netaCount: 2, stageWeeksLeft: 10, stageLength: .中尺, netaFitsStage: true, stamina: 80,
              livingThisWeek: true, money: 10_000, livingCost: livingCost, weeksWithoutPartner: 0,
              plusAvailable: false, expBannerShown: false)
    }
    func testThriftyLivingCostKeepsDecimal() {
        XCTAssertEqual(WeekHint.line(base(livingCost: 133_000)), "今週末に生活費13.3万円。所持金が足りない。")
    }
    func testRoundLivingCostHasNoDecimal() {
        XCTAssertEqual(WeekHint.line(base(livingCost: 190_000)), "今週末に生活費19万円。所持金が足りない。")
    }
}
