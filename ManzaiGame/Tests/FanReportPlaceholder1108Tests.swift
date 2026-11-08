// 客席アンケートの文に「〈名〉」が残らない（11/08 に〈名〉入りの文を足した＝どの条件の組み合わせでも置き換わることを押さえる）
import XCTest
@testable import ManzaiGame

final class FanReportPlaceholder1108Tests: XCTestCase {
    func testNoPlaceholderLeftInVoices() {
        let name = "満月ロケット"
        for passed in [true, false] {
            for margin in [nil, -12.0, -3.0, 0.5, 4.0, 15.0] as [Double?] {
                for burst in [true, false] {
                    for known in [true, false] {
                        for salt in 0..<40 {
                            let out = FanReportData.voices(name: name, passed: passed, margin: margin, burst: burst, salt: salt, known: known)
                            for t in out {
                                XCTAssertFalse(t.contains("〈") || t.contains("〉"), "残った: \(t)")
                            }
                        }
                    }
                }
            }
        }
        for salt in 0..<200 {
            for known in [true, false] {
                XCTAssertFalse(FanReportData.burst(name: name, salt: salt, known: known).contains("〈名〉"))
            }
        }
    }
}
