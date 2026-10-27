import XCTest
@testable import ManzaiGame

/// お金の書き方（money_format_inventory_1027_v0 案C）：札＝¥◯万／¥5,000、文の中＝◯万円／5,000円
final class MoneyFormat1027Tests: XCTestCase {
    func testShortForCards() {
        XCTAssertEqual(Yen.short(5_000), "5,000")      // 1万未満は ¥0.5万 にしない
        XCTAssertEqual(Yen.short(-8_000), "8,000")     // 符号は呼ぶ側
        XCTAssertEqual(Yen.short(10_000), "1万")
        XCTAssertEqual(Yen.short(32_000), "3.2万")
        XCTAssertEqual(Yen.short(-80_000), "8万")
    }
    func testInTextForSentences() {
        XCTAssertEqual(Yen.inText(5_000), "5,000円")
        XCTAssertEqual(Yen.inText(140_000), "14万円")
        XCTAssertEqual(Yen.inText(12_000), "1.2万円")
    }
}
