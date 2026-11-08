import XCTest
import GameCore
@testable import ManzaiGame

/// 11/08 の直しを押さえる：日程表の過ぎた大会週の塗り（code_review_1108 #1・推薦制）と、無名のうちのファンの声（code_review_1108c #7）
final class PastWeekPaint1108Tests: XCTestCase {
    private let tournaments = GameConfig().calendar.tournaments

    private func first(_ match: (TournamentSpec.Eligibility) -> Bool) -> TournamentSpec? {
        tournaments.first { match($0.eligibility) }
    }

    // MARK: 日程表

    func testFameGatedPastWeekPaintedOnlyWhenEntered() throws {
        let spec = try XCTUnwrap(first { if case .fameAtLeast = $0 { return true } else { return false } })
        XCTAssertTrue(CalendarView.paintsPastTournamentWeek(spec, year: 3, category: .taikai))
        XCTAssertFalse(CalendarView.paintsPastTournamentWeek(spec, year: 3, category: nil))       // 知名度が足りず出られなかった週
        XCTAssertFalse(CalendarView.paintsPastTournamentWeek(spec, year: 3, category: .baito))    // 別の事をした週
    }

    func testAgedOutPastWeekNeverPainted() throws {
        let spec = try XCTUnwrap(first { if case .careerYearAtMost = $0 { return true } else { return false } })
        guard case .careerYearAtMost(let n) = spec.eligibility else { return XCTFail() }
        XCTAssertFalse(CalendarView.paintsPastTournamentWeek(spec, year: n + 1, category: .taikai))
        XCTAssertTrue(CalendarView.paintsPastTournamentWeek(spec, year: n, category: nil))        // 出られる年は従来どおり塗る
    }

    func testOrdinaryPastWeekKeepsOldBehaviour() throws {
        let spec = try XCTUnwrap(tournaments.first {
            if case .fameAtLeast = $0.eligibility { return false }
            if case .careerYearAtMost = $0.eligibility { return false }
            return !$0.name.hasPrefix("HANA")
        })
        XCTAssertTrue(CalendarView.paintsPastTournamentWeek(spec, year: 1, category: nil))
        XCTAssertTrue(CalendarView.paintsPastTournamentWeek(spec, year: 1, category: .taikai))
    }

    // MARK: ファンの声

    /// 「前から見ている客」の言い方。無名のうち（known=false）はどの組み合わせでも出ない
    private let veteranWords = ["常連", "毎回", "去年", "いつも", "前に見た", "何度か", "ずっと応援", "いつ見ても"]

    func testUnknownComboNeverGetsVeteranVoices() {
        var seen = 0
        for salt in 0..<400 {
            for passed in [true, false] {
                for margin: Double? in [nil, 12, 3, -2, -7, -20] {
                    for burst in [true, false] {
                        let lines = FanReportData.voices(name: "X", passed: passed, margin: margin, burst: burst, salt: salt, known: false)
                        XCTAssertFalse(lines.isEmpty)
                        for l in lines { seen += 1
                            for w in veteranWords where l.contains(w) {
                                XCTFail("無名に『\(w)』: \(l)（salt \(salt) passed \(passed) margin \(String(describing: margin)) burst \(burst)）")
                            }
                        }
                    }
                }
            }
            for w in veteranWords where FanReportData.burst(name: "X", salt: salt, known: false).contains(w) {
                XCTFail("無名の burst に『\(w)』（salt \(salt)）")
            }
        }
        XCTAssertGreaterThan(seen, 1000)
    }

    /// 名が売れていれば「前から見ている客」の声も出る（フィルタが効きすぎていない）
    func testKnownComboCanGetVeteranVoices() {
        var hit = false
        outer: for salt in 0..<400 {
            for passed in [true, false] {
                let lines = FanReportData.voices(name: "X", passed: passed, margin: passed ? 12 : -20, burst: false, salt: salt, known: true)
                if lines.contains(where: { l in veteranWords.contains { l.contains($0) } }) { hit = true; break outer }
            }
        }
        XCTAssertTrue(hit)
    }
}
