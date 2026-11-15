import XCTest
@testable import ManzaiGame

/// 候補 self-order：漢字・英字のコンビ名が読みの並びで必ず末尾／先頭にならない
final class SelfOrder1116Tests: XCTestCase {
    private let others = ["あおぞら", "かもめ", "さくら", "たんぽぽ", "なのはな", "ひまわり", "まつぼっくり", "やまびこ"]

    private func pos(_ name: String, seed: Int) -> Int {
        FinalistAnnounceView.ordered(others + [name], isSelf: { $0 == name }, yomi: { $0 }, selfName: name, seed: seed).firstIndex(of: name)!
    }

    func testKanaKeepsReadingPosition() {
        XCTAssertEqual(pos("こだま", seed: 1), 2)
        XCTAssertEqual(pos("コダマ", seed: 7), 2)   // カタカナはひらがなに直して並べる
    }

    func testKanjiNameIsNotAlwaysLast() {
        let ps = Set((1...15).map { pos("十字路", seed: $0) })
        XCTAssertGreaterThan(ps.count, 3)                       // 年で位置が変わる
        XCTAssertEqual(pos("十字路", seed: 4), pos("十字路", seed: 4))   // 同じ年なら同じ位置（決定論）
        XCTAssertGreaterThan(Set((1...15).map { pos("ABC", seed: $0) }).count, 3)
    }

    func testOthersStaySorted() {
        let out = FinalistAnnounceView.ordered(others + ["十字路"], isSelf: { $0 == "十字路" }, yomi: { $0 }, selfName: "十字路", seed: 3)
        XCTAssertEqual(out.filter { $0 != "十字路" }, others)
        XCTAssertEqual(out.count, others.count + 1)
    }
}
