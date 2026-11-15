import XCTest
@testable import ManzaiGame

/// 大会の記録の行は空白でだけ折る（大きい文字で「THE HANA 決／勝 優勝」と折れた・AUTOPILOT 569）
final class KirokuBreakAtSpaces1116Tests: XCTestCase {
    func testShortWordsAreJoined() {
        let s = NotebookView.breakAtSpaces("THE HANA 決勝 優勝")
        XCTAssertTrue(s.contains("決\u{2060}勝"))
        XCTAssertEqual(s.replacingOccurrences(of: "\u{2060}", with: ""), "THE HANA 決勝 優勝")   // 見える文字は変わらない
    }
    func testLongWordStaysBreakable() {
        let long = "優勝「ひだまり座」（客席から）"
        XCTAssertEqual(NotebookView.breakAtSpaces("頂GP 決勝 " + long), "頂\u{2060}G\u{2060}P 決\u{2060}勝 " + long)
    }
}
