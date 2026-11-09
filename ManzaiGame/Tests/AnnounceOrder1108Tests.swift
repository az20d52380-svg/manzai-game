// 結果発表：自組の読み（C-18）。かな名はひらがなのまま、漢字・英字名は年ごとに散る（決定的）
import XCTest
@testable import ManzaiGame

final class AnnounceOrder1108Tests: XCTestCase {
    func testKanaNameKeepsReading() {
        XCTAssertEqual(FinalistAnnounceView.selfYomi("ひかり", year: 1), "ひかり")
        XCTAssertEqual(FinalistAnnounceView.selfYomi("ヒカリ", year: 3), "ひかり")
    }
    func testKanjiAndLatinSpreadAcrossYears() {
        for name in ["東京ヒカリ", "ABC"] {
            let ys = (1...10).map { FinalistAnnounceView.selfYomi(name, year: $0) }
            XCTAssertGreaterThan(Set(ys).count, 3, "年ごとに散らない：\(name)")
            XCTAssertEqual(ys, (1...10).map { FinalistAnnounceView.selfYomi(name, year: $0) }, "決定的でない：\(name)")
        }
    }
}
