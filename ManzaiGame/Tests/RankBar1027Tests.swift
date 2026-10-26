// 段（G〜S）と「次の段までの進み」の棒の現状固定（10/27 定期・年末総決算に「棒は、次の段までの進み」と書いたので、その意味どおりかを確かめる）
// rank と rankBounds は同じ閾値（経済の abilityRankCostBands と共有）。表示専用・数値は不変。
import XCTest
@testable import ManzaiGame

final class RankBar1027Tests: XCTestCase {
    func testRankLettersMatchBounds() {
        let letters = ["G", "F", "E", "D", "C", "B", "A", "S"]
        XCTAssertEqual(Theme.rankBounds.count, letters.count)
        for (lo, g) in zip(Theme.rankBounds, letters) {
            XCTAssertEqual(Theme.rank(lo), g, "境界 \(lo) の段")
            if lo > 0 { XCTAssertNotEqual(Theme.rank(lo - 0.01), g, "境界 \(lo) の直前は1つ下の段") }
        }
    }

    func testBarResetsAtEachBoundAndStaysInRange() {
        let cap = 100.0
        for lo in Theme.rankBounds {
            XCTAssertEqual(Theme.rankProgress(lo, cap: cap), 0, accuracy: 1e-9, "段が上がった瞬間は棒が空")
        }
        // F帯（15〜25）の真ん中は半分
        XCTAssertEqual(Theme.rankProgress(20, cap: cap), 0.5, accuracy: 1e-9)
        for v in stride(from: -5.0, through: 120.0, by: 0.5) {
            let p = Theme.rankProgress(v, cap: cap)
            XCTAssertTrue((0...1).contains(p), "v=\(v) p=\(p)")
        }
    }

    func testSBarMeasuresToCap() {
        XCTAssertEqual(Theme.rankProgress(95, cap: 100), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Theme.rankProgress(100, cap: 100), 1, accuracy: 1e-9)
        // cap が S の下限以下でも 0 割りにならない
        XCTAssertEqual(Theme.rankProgress(90, cap: 80), 0, accuracy: 1e-9)
    }
}
