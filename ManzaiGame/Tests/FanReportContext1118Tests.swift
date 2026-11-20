// 観客の声が状況に合うこと（code_review_fan_talk_avatar_1118 #1〜#3）：決勝・単発で「予選」、最終年で「来年」、短尺で「4分」を出さない
import XCTest
@testable import ManzaiGame

final class FanReportContext1118Tests: XCTestCase {
    private func all(prelim: Bool, finalYear: Bool, short: Bool) -> [String] {
        var out: [String] = []
        for salt in 0..<120 {
            for (p, m) in [(true, 12.0), (true, 2.0), (false, -1.0), (false, -6.0), (false, -20.0)] {
                for known in [false, true] {
                    out += FanReportData.voices(name: "テスト", passed: p, margin: m, burst: salt % 3 == 0, salt: salt, known: known,
                                                prelim: prelim, finalYear: finalYear, short: short)
                }
            }
        }
        return out
    }

    func testNoPrelimWordsOutsidePrelims() {
        XCTAssertTrue(all(prelim: false, finalYear: false, short: false).allSatisfy { !$0.contains("予選") })
    }

    func testNoNextYearInFinalYear() {
        XCTAssertTrue(all(prelim: true, finalYear: true, short: false).allSatisfy { !$0.contains("来年") && !$0.contains("次の予選") })
    }

    func testNoFourMinutesInShortRounds() {
        XCTAssertTrue(all(prelim: true, finalYear: false, short: true).allSatisfy { !$0.contains("4分") })
    }

    func testDefaultUnchanged() {
        // 既定（予選・最終年でない・短尺でない）は絞らない＝従来の並びのまま
        XCTAssertEqual(FanReportData.voices(name: "テスト", passed: true, margin: 12, burst: false, salt: 7),
                       FanReportData.voices(name: "テスト", passed: true, margin: 12, burst: false, salt: 7, prelim: true, finalYear: false, short: false))
    }
}
