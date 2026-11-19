import XCTest
import GameCore
@testable import ManzaiGame

/// 能力アップの値札1マスは「経験点の名前＋数」で読む（裸の数字にしない・code_review_views_1116 #1）
final class ViewsA11y1116Tests: XCTestCase {
    func testCostLabelNamesCurrency() {
        XCTAssertEqual(AbilityUpView.costLabel(.閃き, 4, short: false), "ネタ種 4")
        XCTAssertEqual(AbilityUpView.costLabel(.胆力, 12, short: true), "場数 12、足りない")
    }
    func testEveryCurrencyHasItsOwnName() {
        let names = ExpCurrency.allCases.map { AbilityUpView.costLabel($0, 1, short: false) }
        XCTAssertEqual(Set(names).count, ExpCurrency.allCases.count)
        XCTAssertFalse(names.contains { $0.first?.isNumber == true })
    }
}
