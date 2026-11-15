// 撮影・出張で拘束された週は日程表の判子が「仕」（categoryLog = .offer）になる（calendar_audit_1115 低-3 ②・07a628ffe）を固定
import XCTest
import GameCore
@testable import ManzaiGame

final class CalendarPreoccupied1115Tests: IsolatedStoreTestCase {
    /// 拘束2週の間はバイトを選んでも「仕」、稽古は休養に替わっても「仕」
    func testPreoccupiedWeeksAreStampedAsOffer() {
        for action in [WeekAction.job(.標準), .train(.ネタ合わせ)] {
            var st = GameState(config: GameConfig()); st.preoccupiedWeeks = 2
            let s = GameSession(startState: st)
            s.debugFreeWeeks(2, action)
            let weeks = s.categoryLog.keys.sorted()
            XCTAssertGreaterThanOrEqual(weeks.count, 2, "\(action)：2週ぶん記録されていない")
            for w in weeks.prefix(2) {
                XCTAssertEqual(s.categoryLog[w], .offer, "\(action)：拘束中の第\(w)週が「仕」でない")
            }
        }
    }

    /// 拘束が無ければ、選んだ行動どおりの判子（バイト＝「バ」）のまま
    func testUnoccupiedWeekKeepsActionStamp() {
        let s = GameSession(startState: GameState(config: GameConfig()))
        s.debugFreeWeeks(1, .job(.標準))
        guard let w = s.categoryLog.keys.sorted().first else { return XCTFail("記録なし") }
        XCTAssertEqual(s.categoryLog[w], .baito)
    }
}
