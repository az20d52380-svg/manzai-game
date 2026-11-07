import XCTest
import GameCore
@testable import ManzaiGame

/// きろくの通算優勝と日程表の塗り（THE HANA・code_review_1107c #6 #8）
final class KirokuCalendarHana1107Tests: XCTestCase {
    func testPastYearHanaWinsCount() {
        // 前の年に THE HANA 優勝1回（記録は消えている）＋今年の道中優勝1回
        let w = NotebookView.kirokuWins(marks: [("春新人賞A", "優勝")], gpChampionYears: 0, hanaWins: 1)
        XCTAssertEqual(w, 2)
    }
    func testThisYearHanaWinNotDoubleCounted() {
        let w = NotebookView.kirokuWins(marks: [("THE HANA 決勝", "優勝")], gpChampionYears: 1, hanaWins: 1)
        XCTAssertEqual(w, 2)   // 今年の HANA 1回＋過去の GP 1回
    }
    func testMaleComboHasNoHanaWins() {
        XCTAssertEqual(NotebookView.kirokuWins(marks: [], gpChampionYears: 2, hanaWins: nil), 2)
    }
    func testPastHanaWeekPaintedOnlyWhenEntered() {
        XCTAssertTrue(CalendarView.paintsPastWeek(tournamentName: "HANA1回戦", category: .taikai))
        XCTAssertFalse(CalendarView.paintsPastWeek(tournamentName: "HANA2回戦", category: nil))
        XCTAssertTrue(CalendarView.paintsPastWeek(tournamentName: "春新人賞A", category: nil))   // 道中は従来どおり
    }

    /// 前の年の道中優勝が年をまたいで消えない（通算の数字が年明けに減らない）
    func testPastSmallWinsKept() {
        XCTAssertEqual(NotebookView.kirokuWins(marks: [], gpChampionYears: 0, hanaWins: nil, pastSmallWins: 2), 2)
    }

    func testSmallWinCountExcludesGPAndHana() {
        let log = ["第5週: 春新人賞A 優勝 +10万 / 夏中堅賞 敗退", "第30週: THE HANA 決勝 優勝 +100万", "第47週: 頂GP 決勝 優勝 +1000万",
                   "第47週: 頂GP 決勝 優勝「誰か」（客席から）", "第9週: 寒梅漫才杯 優勝 +20万"]
        XCTAssertEqual(GameSession.smallWinCount(log: log), 2)
    }

    func testAgedOutOnlyAfterCap() {
        let t = GameConfig().calendar.tournaments
        let capped = t.first { if case .careerYearAtMost = $0.eligibility { return true } else { return false } }!
        guard case .careerYearAtMost(let n) = capped.eligibility else { return XCTFail() }
        XCTAssertFalse(CalendarView.isAgedOut(capped, year: n))
        XCTAssertTrue(CalendarView.isAgedOut(capped, year: n + 1))
        let open = t.first { if case .careerYearAtMost = $0.eligibility { return false } else { return true } }!
        XCTAssertFalse(CalendarView.isAgedOut(open, year: 15))
    }
}
