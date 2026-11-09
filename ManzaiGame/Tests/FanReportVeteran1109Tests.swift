import XCTest
@testable import ManzaiGame

/// 古参の前提の文（veteranOnly）は4年目以降かつ知名度15以上でだけ出る（試し版 fanreport_veteran_cand_1109）
final class FanReportVeteran1109Tests: XCTestCase {
    func testIsVeteranThreshold() {
        XCTAssertFalse(FanReportData.isVeteran(year: 3, fame: 99))
        XCTAssertFalse(FanReportData.isVeteran(year: 4, fame: 14))
        XCTAssertTrue(FanReportData.isVeteran(year: 4, fame: 15))
    }

    func testVeteranOnlySubsetOfKnownOnly() {
        XCTAssertFalse(FanReportData.veteranOnlyForTest.isEmpty)
        XCTAssertTrue(FanReportData.veteranOnlyForTest.isSubset(of: FanReportData.knownOnlyForTest))
    }

    private func all(known: Bool, veteran: Bool) -> Set<String> {
        var out = Set<String>()
        for salt in 0..<400 {
            for (passed, margin) in [(true, 12.0), (true, 2.0), (false, -1.0), (false, -6.0), (false, -20.0)] {
                for burst in [false, true] {
                    out.formUnion(FanReportData.voices(name: "〈名〉", passed: passed, margin: margin, burst: burst, salt: salt, known: known, veteran: veteran))
                }
            }
            out.insert(FanReportData.burst(name: "〈名〉", salt: salt, known: known, veteran: veteran))
        }
        return out
    }

    func testNotShownBeforeYear4() {
        let vo = FanReportData.veteranOnlyForTest
        XCTAssertTrue(all(known: true, veteran: false).isDisjoint(with: vo))
        XCTAssertTrue(all(known: false, veteran: false).isDisjoint(with: vo))
    }

    func testShownFromYear4() {
        let vo = FanReportData.veteranOnlyForTest
        XCTAssertFalse(all(known: true, veteran: true).isDisjoint(with: vo))
    }
}
