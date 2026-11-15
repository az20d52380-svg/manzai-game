import XCTest
@testable import ManzaiGame

/// 候補 short-money-price：お金が足りない札に値段と不足を出す
final class ShortMoneyPrice1116Tests: XCTestCase {
    func testLine() {
        XCTAssertEqual(WeekMainView.shortMoneyLine(cost: 60_000, money: 20_000), "¥6万・あと¥4万不足")
        XCTAssertEqual(WeekMainView.shortMoneyLine(cost: 10_000, money: 6_000), "¥1万・あと¥4,000不足")
        XCTAssertEqual(WeekMainView.shortMoneyLine(cost: 0, money: -5), "お金が足りない")
    }
}
