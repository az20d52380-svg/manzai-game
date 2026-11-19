import XCTest
import GameCore
@testable import ManzaiGame

/// 選択イベントの表示（code_review_choiceevent_1117 #1・#5・表示のみ）
final class ChoiceEventState1117Tests: XCTestCase {
    private func setupText(_ t: ChoiceEventText) -> String { t.setup.map(\.text).joined() }

    /// 連敗の相談：お金・疲れを語る版は、その状況の時だけ出る
    func testStyleTalkFollowsState() {
        let v = ChoiceEventData.styleTalkVariants   // [元, 疲れ, お金, 静か]
        let tired = setupText(v[1]), money = setupText(v[2])
        for w in 1...48 {
            let rich = setupText(ChoiceEventData.text(for: .styleTalk, year: 3, week: w, money: 300_000, stamina: 90))
            XCTAssertNotEqual(rich, tired); XCTAssertNotEqual(rich, money)
            XCTAssertEqual(setupText(ChoiceEventData.text(for: .styleTalk, year: 3, week: w, money: 300_000, stamina: 30)), tired)
            XCTAssertEqual(setupText(ChoiceEventData.text(for: .styleTalk, year: 3, week: w, money: 20_000, stamina: 90)), money)
        }
        // 状態を渡さない時は従来どおり週で4つを回す
        XCTAssertEqual(Set((1...48).map { setupText(ChoiceEventData.text(for: .styleTalk, year: 2, week: $0)) }).count, v.count)
    }

    /// 良い効果の一言だけ伸びる側の札
    func testHiddenNoteDirection() {
        XCTAssertTrue(ChoiceEventData.hiddenEffectNoteIsGood(for: .wroteOneTonight, choice: "B"))
        XCTAssertTrue(ChoiceEventData.hiddenEffectNoteIsGood(for: .riftWarning, choice: "A"))
        XCTAssertFalse(ChoiceEventData.hiddenEffectNoteIsGood(for: .regularEmployment, choice: "A"))
        XCTAssertFalse(ChoiceEventData.hiddenEffectNoteIsGood(for: .photoShootOffer, choice: "A"))
    }
}
