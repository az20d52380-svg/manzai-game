// knownOnly（知られてから出す声）は配列の文の写し＝片方だけ書き換えると制限が黙って外れる（11/09：候補の△直しで veteranOnly の9本が外れかけた）
import XCTest
@testable import ManzaiGame

final class FanReportKnownOnly1109Tests: XCTestCase {
    func testKnownOnlyLinesExistInPools() {
        XCTAssertEqual(FanReportData.knownOnlyOrphans, [], "knownOnly の写しがどの配列にも無い")
    }
}
