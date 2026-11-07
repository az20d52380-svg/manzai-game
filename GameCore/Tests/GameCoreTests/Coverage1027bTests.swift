// Coverage1027bTests.swift
// 未カバーだった境界を固定（テストのみ・本体/式/乱数/golden は不変）。
import XCTest
@testable import GameCore

final class Coverage1027bTests: XCTestCase {

    // paperNetaLines: 来歴フラグなし→空、全部→3行（順序＝再演・鉄板・おろしたて）
    func testPaperNetaLinesEmptyWhenNoFlags() {
        XCTAssertTrue(JudgeTalk.paperNetaLines(scene: .init(), passed: true).isEmpty)
        XCTAssertTrue(JudgeTalk.paperNetaLines(scene: .init(), passed: false).isEmpty)
    }

    func testPaperNetaLinesCountAndOrderAndPassFailDiffer() {
        let rich = JudgeTalk.Scene(isTeppan: true, isRevivalNeta: true, isFresh: true)
        let p = JudgeTalk.paperNetaLines(scene: rich, passed: true)
        let f = JudgeTalk.paperNetaLines(scene: rich, passed: false)
        XCTAssertEqual(p.count, 3)
        XCTAssertEqual(f.count, 3)
        XCTAssertTrue(p[0].contains("寝かせた"))
        XCTAssertTrue(p[1].contains("かけ込んだ"))
        XCTAssertTrue(p[2].contains("おろしたて"))
        for i in 0..<3 { XCTAssertNotEqual(p[i], f[i]) }
    }

    func testPaperNetaLinesSingleFlagYieldsOneLine() {
        XCTAssertEqual(JudgeTalk.paperNetaLines(scene: .init(isTeppan: true), passed: true).count, 1)
        XCTAssertEqual(JudgeTalk.paperNetaLines(scene: .init(isRevivalNeta: true), passed: false).count, 1)
        XCTAssertEqual(JudgeTalk.paperNetaLines(scene: .init(isFresh: true), passed: true).count, 1)
    }

    // addFameRaw: 上限100・0丸め・0加算は不変
    func testAddFameRawClampsAtBothEnds() {
        let c = GameConfig()
        var s = GameState(config: c)
        s.fame = 95
        GameEngine.addFameRaw(50, to: &s)
        XCTAssertEqual(s.fame, 100)
        GameEngine.addFameRaw(0, to: &s)
        XCTAssertEqual(s.fame, 100)
        s.fame = 3
        GameEngine.addFameRaw(-10, to: &s)
        XCTAssertEqual(s.fame, 0)
    }

    // pourRecommended: 通貨ゼロなら能力は動かない
    func testPourRecommendedIsNoOpWithZeroCurrency() {
        let c = GameConfig()
        var s = GameState(config: c)
        for k in ExpCurrency.allCases { s[currency: k] = 0 }
        let before = s
        GameEngine.pourRecommended(to: &s, config: c)
        for a in Ability.allCases { XCTAssertEqual(s[a], before[a], "\(a)") }
    }
}
