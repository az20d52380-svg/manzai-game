// 大会の結果画面に出す経験点の増分（TournamentResultView.expGainRow の元データ）を固定
import XCTest
import GameCore
@testable import ManzaiGame

final class ResultExpRow1107Tests: IsolatedStoreTestCase {
    func testLossResultHasExpDelta() throws {
        let s = GameSession()
        s.debugAdvanceToFirstResult()
        _ = try XCTUnwrap(s.pendingResult)
        let total = ExpDisplay.total(ExpCurrency.allCases.map { max(0, s.lastResultExpDelta[$0] ?? 0) })
        XCTAssertGreaterThanOrEqual(total, 1, "敗退でも結果の行が出る")
    }
}
