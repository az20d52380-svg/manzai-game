import XCTest
import GameCore
@testable import ManzaiGame

/// 一言行が体力の注意を出す週は、独白で同じ低体力の話をしない（week_prompts_inventory_1108 案②の③）。
final class StaminaDedup1110Tests: XCTestCase {
    private func scene(_ s: GameState, skip: Bool) -> String? {
        var seen: String?
        _ = DialogueData.innerVoice(state: s, lossStreak: 0, justPassed: false, justLost: false,
                                    nextMilestone: nil, weakAbility: "", week: 7,
                                    picker: { sc, _, _ in seen = sc; return 0 }, staminaSaidElsewhere: skip)
        return seen
    }

    func testLowStaminaMonologueYieldsWhenHintSaysIt() {
        var s = GameState(config: GameConfig()); s.recoveryWeeks = 0; s.stamina = 10; s.money = 1_000_000
        XCTAssertEqual(scene(s, skip: false), "mono.lowStamina", "今まで通り")
        XCTAssertNotEqual(scene(s, skip: true), "mono.lowStamina", "一言行が言う週は独白は別の話へ")
        s.money = 0
        XCTAssertEqual(scene(s, skip: true), "mono.lowMoney", "次の優先（お金）へ譲る")
    }

    func testIsStaminaLineMatchesBothHintLines() {
        XCTAssertTrue(WeekHint.isStaminaLine("体力が少ない。今週は休むのも手だ。"))
        XCTAssertTrue(WeekHint.isStaminaLine("谷口：無理すると倒れるよ。"))
        XCTAssertFalse(WeekHint.isStaminaLine("まだネタがない。まずはネタを書こう。"))
        XCTAssertFalse(WeekHint.isStaminaLine(nil))
    }
}
