// 週の記録の「書く所」と「読む所」の突き合わせ（code_review_2026-10-26e）
// summarize が実際に作った文字列を、年末・戦績の読む関数に通す。
import XCTest
import GameCore
@testable import ManzaiGame

final class LogRoundTrip1026Tests: IsolatedStoreTestCase {
    private func sr(_ name: String, passed: Bool, prize: Int = 0, stage: Bool = true) -> StageResult {
        StageResult(name: name, passed: passed, prize: prize, isStage: stage)
    }
    private func line(week: Int = 12, _ rs: [StageResult]) -> String {
        GameSession.summarize(WeekSummary(year: 1, week: week, results: rs, state: GameState(config: GameConfig())))
    }

    func testParseSingleForms() {
        let cases: [(StageResult, String, Int)] = [
            (sr("GP1回戦", passed: true), "通過", 0), (sr("GP2回戦", passed: false), "敗退", 0),
            (sr("春新人賞A", passed: true, prize: 500_000), "優勝", 50), (sr("夏中堅賞", passed: false), "敗退", 0),
            (sr("敗者復活", passed: true), "通過", 0), (sr("GP決勝", passed: false), "敗退", 0),
            (sr("体調ダウン", passed: false, stage: false), "休", 0), (sr("療養", passed: false, stage: false), "休", 0),
        ]
        for (r, mark, prize) in cases {
            let ps = GameSession.parseLogLine(line([r]))
            XCTAssertEqual(ps.count, 1, r.name)
            XCTAssertEqual(ps.first?.mark, mark, r.name)
            XCTAssertEqual(ps.first?.prize, prize, r.name)
            XCTAssertEqual(ps.first?.week, "第12週")
        }
    }
    func testParseMultiResultWeek() {
        let l = line([sr("春新人賞A", passed: true, prize: 500_000), sr("GP1回戦", passed: false)])
        let ps = GameSession.parseLogLine(l)
        XCTAssertEqual(ps.map(\.mark), ["優勝", "敗退"])
        XCTAssertEqual(ps.map(\.prize), [50, 0])
        XCTAssertEqual(ps[1].title, "頂GP 1回戦 敗退")
        XCTAssertEqual(YearResultView.stageRecord(log: [l]).wins, 1)
        XCTAssertEqual(YearResultView.stageRecord(log: [l]).losses, 1)
    }
    func testFinaleAndWatchedLines() {
        let fin = "第44週: 頂GP 決勝 優勝 +100万"
        XCTAssertEqual(GameSession.parseLogLine(fin).first?.mark, "優勝")
        XCTAssertEqual(GameSession.parseLogLine(fin).first?.prize, 100)
        let w = "第44週: 頂GP 決勝 優勝「ひだまり座」（客席から）"
        XCTAssertEqual(GameSession.parseLogLine(w).map(\.mark), ["観戦"])
        XCTAssertEqual(YearResultView.stageRecord(log: [w]).wins, 0)
    }
    func testLoggedGPEntryAgainstWrittenLine() {
        let cfg = GameConfig()
        let first = cfg.calendar.gpRoundNames.first ?? "GP1回戦"
        XCTAssertTrue(GameSession.loggedGPEntry(in: [line([sr(first, passed: false)])], config: cfg))
        XCTAssertFalse(GameSession.loggedGPEntry(in: [line([sr("春新人賞A", passed: false)])], config: cfg))
    }
    func testEventLinesAndHiddenCountSkipRest() {
        let log = [line(week: 5, [sr("体調ダウン", passed: false, stage: false)]),
                   line(week: 12, [sr("春新人賞A", passed: false)]),
                   line(week: 20, [sr("GP1回戦", passed: true)]),
                   line(week: 21, [sr("GP2回戦", passed: false)])]
        let shown = YearResultView.eventLines(log)
        XCTAssertEqual(shown.count, 3)
        XCTAssertFalse(shown.contains { $0.contains("体調ダウン") })
        XCTAssertEqual(YearResultView.hiddenStageCount(log, shown: shown), 0)   // 休は大会に数えない
        let log2 = log + [line(week: 30, [sr("夏中堅賞", passed: false)])]
        XCTAssertEqual(YearResultView.hiddenStageCount(log2, shown: YearResultView.eventLines(log2)), 1)
        XCTAssertEqual(YearResultView.eventLines([line(week: 5, [sr("療養", passed: false, stage: false)])]), [])
    }
}
