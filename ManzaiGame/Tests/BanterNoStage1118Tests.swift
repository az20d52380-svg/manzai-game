import XCTest
@testable import ManzaiGame

/// 今年もう大会が無い週の掛け合い（code_review_dialoguedata_1118 #1）
final class BanterNoStage1118Tests: XCTestCase {
    func testNoStageNeverMentionsNextStage() {
        for band in [BanterBand.afterPass, .streak] {
            for salt in 0..<200 {
                let lines = DialogueData.banter(band: band, salt: salt, noStage: true) ?? []
                XCTAssertFalse(lines.isEmpty)
                XCTAssertFalse(DialogueData.mentionsNextStage(lines), "\(band) \(lines.map(\.text))")
            }
        }
    }

    func testWithStageKeepsFullPool() {
        let hits = (0..<200).compactMap { DialogueData.banter(band: .afterPass, salt: $0) }.filter(DialogueData.mentionsNextStage)
        XCTAssertFalse(hits.isEmpty)
    }

    func testNextDayIsNotAStage() {
        XCTAssertFalse(DialogueData.mentionsNextStage([Advice(name: "俺", text: "入れて。次の日は寝ておく")]))
    }
}
