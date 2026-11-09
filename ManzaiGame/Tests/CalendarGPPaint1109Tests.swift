import XCTest
import GameCore
@testable import ManzaiGame

/// 【候補 C-25 案②】来週以降の頂GP の週は、まだ出られる段だけ塗る（calendar_ineligible_paint_1108_v0）
final class CalendarGPPaint1109Tests: XCTestCase {
    private func gp(_ w: Int) -> GameSession.StageInfo {
        GameSession.StageInfo(week: w, name: "頂GP", line: 0, highStakes: false, isGP: true)
    }

    func testPaintsOnlyRemainingGPStages() {
        let up = [gp(41), gp(43), GameSession.StageInfo(week: 41, name: "寒梅", line: 0, highStakes: true, isGP: false)]
        XCTAssertTrue(CalendarView.paintsFutureGPWeek(43, upcoming: up))
        XCTAssertFalse(CalendarView.paintsFutureGPWeek(45, upcoming: up))   // 残っていない段
        XCTAssertFalse(CalendarView.paintsFutureGPWeek(47, upcoming: up))   // 落ちた年の決勝の週
    }

    func testNonGPStageDoesNotPaintGPWeek() {
        let up = [GameSession.StageInfo(week: 39, name: "推薦制中堅賞", line: 0, highStakes: true, isGP: false)]
        XCTAssertFalse(CalendarView.paintsFutureGPWeek(39, upcoming: up))
    }

    func testFreshSessionPaintsAllGPWeeks() {
        let s = GameSession()
        let cal = GameConfig().calendar
        for r in cal.gpRounds { XCTAssertTrue(CalendarView.paintsFutureGPWeek(r.week, upcoming: s.upcomingStages()), "週\(r.week)") }
        XCTAssertTrue(CalendarView.paintsFutureGPWeek(cal.gpFinalWeek, upcoming: s.upcomingStages()))
    }
}
