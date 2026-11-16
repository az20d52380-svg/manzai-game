import XCTest
@testable import ManzaiGame

/// 大会の記録の行は空白でだけ折る（大きい文字で「THE HANA 決／勝 優勝」と折れた・AUTOPILOT 569）
final class KirokuBreakAtSpaces1116Tests: XCTestCase {
    func testShortWordsAreJoined() {
        let s = NotebookView.breakAtSpaces("THE HANA 決勝 優勝")
        XCTAssertTrue(s.contains("決\u{2060}勝"))
        XCTAssertEqual(s.replacingOccurrences(of: "\u{2060}", with: ""), "THE HANA 決勝 優勝")   // 見える文字は変わらない
    }
    func testBracketsAreBreakPoints() {
        let s = NotebookView.breakAtSpaces("頂GP 決勝 優勝「ひだまり座」（客席から）")
        XCTAssertTrue(s.contains("勝「"))   // 「の前では折れる
        XCTAssertTrue(s.contains("」（"))   // （の前では折れる
        XCTAssertTrue(s.contains("ひ\u{2060}だ\u{2060}ま"))   // 名前の途中では折れない
        XCTAssertEqual(s.replacingOccurrences(of: "\u{2060}", with: ""), "頂GP 決勝 優勝「ひだまり座」（客席から）")
        let veryLong = "とても長い名前のコンビ名です"   // 8字を超えるかたまりは今までどおり途中で折れる
        XCTAssertEqual(NotebookView.breakAtSpaces(veryLong), veryLong)
    }
    func testEntrySubBreaksAtLastDot() {
        XCTAssertEqual(TournamentEntryView.breakAtLastDot("舞台には立たない・結果は後日・エントリー費 ¥2,000"), "舞台には立たない・結果は後日\nエントリー費 ¥2,000")
        XCTAssertEqual(TournamentEntryView.breakAtLastDot("残高不足で出られない"), "残高不足で出られない")
    }
}
