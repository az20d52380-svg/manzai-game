import XCTest
import GameCore
@testable import ManzaiGame

/// 練習・ネタが休演（体力 < staminaGate）の週に、稽古をする前提の独白が出ない（playtest_y11_15_1110・表示のみ）
final class GateStaminaMono1110Tests: XCTestCase {
    func testNoKeikoLineWhenGated() {
        var st = GameState(config: GameConfig())
        for stamina in [0.0, 10.0, 19.0] {
            st.stamina = stamina
            for w in 0..<200 {
                let a = DialogueData.innerVoice(state: st, lossStreak: 0, justPassed: false, justLost: false,
                                                nextMilestone: nil, weakAbility: "", week: w)
                XCTAssertFalse(a.text.contains("稽古"), "stamina=\(stamina) week=\(w): \(a.text)")
            }
        }
    }
    func testKeikoLineStillAppearsAboveGate() {
        var st = GameState(config: GameConfig()); st.stamina = 22
        let texts = (0..<200).map { DialogueData.innerVoice(state: st, lossStreak: 0, justPassed: false, justLost: false,
                                                            nextMilestone: nil, weakAbility: "", week: $0).text }
        XCTAssertTrue(texts.contains { $0.contains("稽古") })
    }
}

/// 休演の週は「休む」がはっきりした10行（lowStaminaGated）だけ・全部 lowStamina に既にある文（新しい文なし）
final class GateStaminaStrong1110Tests: XCTestCase {
    func testGatedWeeksUseStrongLinesOnly() {
        var st = GameState(config: GameConfig()); st.stamina = 0
        let all = Set((0..<300).map { DialogueData.innerVoice(state: st, lossStreak: 0, justPassed: false, justLost: false,
                                                             nextMilestone: nil, weakAbility: "", week: $0).text })
        XCTAssertTrue(all.isSubset(of: Set(DialogueData.lowStaminaGated)))
        XCTAssertEqual(all.count, DialogueData.lowStaminaGated.count)
    }
    func testStrongLinesAreExistingLowStaminaLines() {
        var st = GameState(config: GameConfig()); st.stamina = 22
        let low = Set((0..<400).map { DialogueData.innerVoice(state: st, lossStreak: 0, justPassed: false, justLost: false,
                                                             nextMilestone: nil, weakAbility: "", week: $0).text })
        for l in DialogueData.lowStaminaGated { XCTAssertTrue(low.contains(l), l) }
    }
}
