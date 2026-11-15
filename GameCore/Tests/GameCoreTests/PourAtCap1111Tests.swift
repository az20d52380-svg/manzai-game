import XCTest
@testable import GameCore

/// 能力が上限に達していると、経験点があっても pourStep は何も消費せず0を返す
/// （Allocation.pourStep の「伸びしろ0」ガード＝11/11 時点で網羅0回だった行）。
final class PourAtCap1111Tests: XCTestCase {
    func testPourStepAtCapKeepsCurrency() {
        let c = GameConfig()
        var s = GameState(config: c)
        for cur in ExpCurrency.allCases { s[currency: cur] = 1000 }
        s[.センス] = c.abilityCap
        let before = ExpCurrency.allCases.map { s[currency: $0] }
        XCTAssertEqual(GameEngine.pourStep(.センス, to: &s, config: c), 0)
        XCTAssertEqual(s[.センス], c.abilityCap)
        XCTAssertEqual(ExpCurrency.allCases.map { s[currency: $0] }, before)
    }
}
