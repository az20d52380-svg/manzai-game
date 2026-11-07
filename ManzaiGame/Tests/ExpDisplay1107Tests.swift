// 経験点の合計の見え方（playtest_v11b #5）と、おまかせ後の「経験点が残ってる」の条件（#6）を固定
import XCTest
import GameCore
@testable import ManzaiGame

final class ExpDisplay1107Tests: IsolatedStoreTestCase {
    func testTotalEqualsSumOfDisplayedParts() {
        let parts = [1.46, 0.48]   // 札は 14 と 4。内部で足してから丸めると 19 になる
        XCTAssertEqual(ExpDisplay.value(parts[0]) + ExpDisplay.value(parts[1]), 18)
        XCTAssertEqual(ExpDisplay.total(parts), 18)
        XCTAssertEqual(ExpDisplay.value(parts.reduce(0, +)), 19, "この差を直した")
        XCTAssertEqual(ExpDisplay.total([]), 0)
    }

    /// おまかせを確定した直後は、押せる＋が残らない＝朱の帯（anyPlusEnabled が条件）は消える
    func testNoPlusLeftAfterAutoAllocation() {
        for (a, b, c, d, e) in [(1.2, 0.0, 0.5, 1.4, 0.0), (5.0, 5.0, 5.0, 5.0, 5.0), (0.3, 0.3, 0.3, 0.3, 0.3), (50.0, 0.0, 0.0, 0.0, 0.0)] {
            var st = GameState(config: GameConfig())
            st.exp閃き = a; st.exp語彙 = b; st.exp間合い = c; st.exp存在感 = d; st.exp胆力 = e
            let s = GameSession(startState: st)
            _ = s.allocate(s.recommendedAllocation())
            XCTAssertFalse(AbilityUpView.anyPlusEnabled(s, state: s.state), "持ち分 \((a, b, c, d, e)) でおまかせ後に＋が残る")
        }
    }
}
