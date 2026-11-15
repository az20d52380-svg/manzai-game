// 候補 calendar_audit_1115 中-2：道中の大会を見送った・払えず出なかった週は、過ぎた後に塗らない（出た週だけ朱）
import XCTest
import GameCore
@testable import ManzaiGame

final class PastRoadPaint1115Tests: IsolatedStoreTestCase {
    func testSkippedRoadTournamentIsNotPainted() {
        XCTAssertTrue(CalendarView.paintsPastWeek(tournamentName: "春新人賞A", category: .taikai))
        XCTAssertFalse(CalendarView.paintsPastWeek(tournamentName: "春新人賞A", category: .keiko))   // 見送って稽古した週
        XCTAssertFalse(CalendarView.paintsPastWeek(tournamentName: "寒梅杯", category: .baito))
        XCTAssertTrue(CalendarView.paintsPastWeek(tournamentName: "春新人賞A", category: nil))      // 旧セーブ（印なし）は従来どおり
    }
}
