import XCTest
@testable import GameCore

/// GameConfig.netaWork（稽古→ネタの効き方）の対応を押さえる（test_formula_copies_1115 #6）
final class NetaWork1115Tests: XCTestCase {
    func testMapping() {
        let c = GameConfig()
        XCTAssertEqual(c.netaWork(for: .ネタ作り), .write(gain: nil))
        XCTAssertEqual(c.netaWork(for: .喫茶店で書く), .write(gain: c.netaPlaceGain[.喫茶店で書く]))
        XCTAssertEqual(c.netaWork(for: .ファミレスで書く), .write(gain: c.netaPlaceGain[.ファミレスで書く]))
        XCTAssertEqual(c.netaWork(for: .ネタ見せ会), .live(hard: true))
        XCTAssertEqual(c.netaWork(for: .フリーライブ), .live(hard: false))
    }

    func testOtherTrainingsDoNotTouchNeta() {
        let c = GameConfig()
        let neta: Set<Training> = GameConfig.netaWriteTrainings.union([.ネタ見せ会, .フリーライブ])
        for t in Training.allCases where !neta.contains(t) {
            XCTAssertNil(c.netaWork(for: t), "\(t)")
        }
    }
}
