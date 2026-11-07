import XCTest
@testable import ManzaiGame

/// 優勝の翌年の独白：去年と比べる行を外す（code_review_1107f #2）
final class YearEndLine1107Tests: XCTestCase {
    func testDropsLinesComparingWithLastYear() {
        let pool = ["去年の自分が見たら、驚くような一年だった。", "去年と、あまり変わらない一年だった。", "次の舞台を、楽しみに待てる一年だった。"]
        XCTAssertEqual(YearResultView.withoutLastYearLines(pool), ["次の舞台を、楽しみに待てる一年だった。"])
    }

    func testKeepsPoolWhenEverythingWouldBeRemoved() {
        let pool = ["去年の自分が見たら、驚くような一年だった。"]
        XCTAssertEqual(YearResultView.withoutLastYearLines(pool), pool)
    }
}
