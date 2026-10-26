// アプリ側の穴埋めテスト（選択イベント後の札の一言 hiddenEffectNote／書く対象のフォールバック・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class HiddenEffectNoteTests: XCTestCase {
    func testRegularEmploymentA() {
        XCTAssertEqual(ChoiceEventData.hiddenEffectNote(for: .regularEmployment, choice: "A"), "芸に回せる余力が少し減った")
    }
    func testWroteOneTonightB() {
        XCTAssertEqual(ChoiceEventData.hiddenEffectNote(for: .wroteOneTonight, choice: "B"), "来週のネタ合わせが捗りそう")
    }
    func testPhotoShootOfferA() {
        XCTAssertEqual(ChoiceEventData.hiddenEffectNote(for: .photoShootOffer, choice: "A"), "その週は稽古に出られない")
    }
    func testRiftWarningA() {
        XCTAssertEqual(ChoiceEventData.hiddenEffectNote(for: .riftWarning, choice: "A"), "二人の空気が少しほどけた")
    }
    func testOtherChoicesHaveNoNote() {
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .regularEmployment, choice: "B"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .wroteOneTonight, choice: "A"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .photoShootOffer, choice: "B"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .riftWarning, choice: "B"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .styleTalk, choice: "A"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .regularEmployment, choice: ""))
    }
}

final class WriteTargetFallbackTests: IsolatedStoreTestCase {
    private func twoNetas() -> GameState {
        var st = GameState(config: GameConfig())
        var a = Neta(id: 0, name: "A", kata: .伏線回収, lengthFit: [.長尺], bornYear: 1); a.polish = 80
        var b = Neta(id: 1, name: "B", kata: .瞬発, lengthFit: [.短尺], bornYear: 1); b.polish = 30
        st.netas = [a, b]; st.selectedNetaID = 0
        return st
    }
    func testNoNetasMeansNoTarget() {
        let s = GameSession(startState: GameState(config: GameConfig()))
        XCTAssertNil(s.writeTargetID)
        XCTAssertNil(s.writeTargetNeta)
    }
    func testWriteTargetNetaFollowsSetWriteNeta() {
        let s = GameSession(startState: twoNetas())
        s.setWriteNeta(1)
        XCTAssertEqual(s.writeTargetNeta?.name, "B")
    }
    func testSetWriteNetaClearsNewWriteFlag() {
        let s = GameSession(startState: twoNetas())
        s.beginNewWrite()
        XCTAssertTrue(s.writeNewNeta)
        XCTAssertNil(s.writeNetaID)
        s.setWriteNeta(1)
        XCTAssertFalse(s.writeNewNeta)
        XCTAssertEqual(s.writeTargetID, 1)
    }
    func testBeginNewWriteClearsWriteNetaID() {
        let s = GameSession(startState: twoNetas())
        s.setWriteNeta(1)
        s.beginNewWrite()
        XCTAssertNil(s.writeNetaID)
        XCTAssertNil(s.writeTargetID)
    }
    func testStaleWriteNetaIDFallsBackToStageNeta() {
        let s = GameSession(startState: twoNetas())
        s.setWriteNeta(99)   // 存在しないID＝勝負ネタへフォールバック
        XCTAssertEqual(s.writeTargetID, 0)
    }
}
