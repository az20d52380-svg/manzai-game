// 先輩の誘いの文面は、このキャリアで出した文面を避けて選ぶ（11/08 候補・乱数なし）
import XCTest
import GameCore
@testable import ManzaiGame

final class InviteVariantAvoid1108Tests: XCTestCase {
    func testInviteVariantsDoNotRepeatUntilAllUsed() {
        let s = GameSession()
        let n = ChoiceEventData.weekendInviteVariants.count
        var seen: [String] = []
        for i in 0..<n {
            let week = 5 + (i % 40), year = 1 + i / 40
            let t = ChoiceEventData.text(for: .weekendInvite, year: year, week: week) { scene, count, salt in
                s.pickIndex(scene: scene, count: count, salt: salt, key: year * 48 + week)
            }
            seen.append(t.setup.map(\.text).joined())
        }
        XCTAssertEqual(Set(seen).count, n, "全種を使い切るまで同じ文面は出ない")
    }

    func testSameWeekRedrawKeepsSameText() {
        let s = GameSession()
        func draw() -> String {
            ChoiceEventData.text(for: .weekendInvite, year: 3, week: 20) { scene, count, salt in
                s.pickIndex(scene: scene, count: count, salt: salt, key: 3 * 48 + 20)
            }.setup.map(\.text).joined()
        }
        XCTAssertEqual(draw(), draw())
    }
}
