import XCTest
@testable import ManzaiGame

/// 寄席の音の口→既存 SE の対応表（キュー158 ②・code_review_cands4_1109 #3）。当てる口は3つだけ・他の口は鳴らさない。
final class YoseSoundMap1110Tests: XCTestCase {
    func testOnlyThreeSlotsAreWired() {
        XCTAssertEqual(YoseFX.soundMap.count, 3)
        XCTAssertEqual(YoseFX.soundMap[.championImpact], .taiko)
        XCTAssertEqual(YoseFX.soundMap[.stampHeavy], .don)
        XCTAssertEqual(YoseFX.soundMap[.prizeGet], .money)
        XCTAssertNotNil(YoseFX.onPlaySound, "既定で繋がっている")
    }
}
