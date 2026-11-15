import XCTest
@testable import ManzaiGame
import GameCore

/// money_audit_1115 M1：次の生活費で夜逃げの線を割る時は、固定の段より先に段4の知らせを出す
final class DebtNextPay1115Tests: XCTestCase {
    func testWarnsWhenNextPaymentCrossesBankruptLine() {
        var c = GameConfig(); c.livingCost = 290_000   // タワー住まいの1回の支払いと同じ大きさ（14万＋上乗せ15万）
        let s = GameSession(seed: 1, config: c)
        let due = GameEngine.livingCostDue(s.state, config: s.config)
        let money = s.config.bankruptLine + due - 1    // 次の支払いで線を割り、まだ段3の手前（−71万）
        XCTAssertEqual(s.debtNoticeTierToShow(money: money), 4)
        s.markDebtWarned(4)
        XCTAssertNil(s.debtNoticeTierToShow(money: money), "段4は1回だけ")
        XCTAssertNil(s.debtNoticeTierToShow(money: -900_000), "段4の後に段3は出さない")
    }

    func testNoWarnWhenNextPaymentIsSafe() {
        let s = GameSession(seed: 1)
        let due = GameEngine.livingCostDue(s.state, config: s.config)
        XCTAssertEqual(s.debtNoticeTierToShow(money: s.config.bankruptLine + due + 1), GameSession.debtTier(money: s.config.bankruptLine + due + 1))
        XCTAssertNil(s.debtNoticeTierToShow(money: 10_000))
    }
}
