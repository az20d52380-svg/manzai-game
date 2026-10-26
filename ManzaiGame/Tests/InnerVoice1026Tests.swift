// 週の独白（DialogueData.innerVoice）の優先順の現状固定（10/26 定期・アプリのカバー率で未通過だった分岐）
// 療養 → 体力 → お金 → 負けた翌週（単発/連敗）→ 連敗 → 通過 → 大会2週前（弱点あり/なし）→ 本番が遠い週 → 平常
// 文面は見ない（picker に渡る場面キーで分岐を確かめる）。文面・条件・効果は不変。
import XCTest
import GameCore
@testable import ManzaiGame

final class InnerVoice1026Tests: XCTestCase {
    private func calm() -> GameState {
        var s = GameState(config: GameConfig())
        s.recoveryWeeks = 0
        s.stamina = 100
        s.money = 1_000_000
        return s
    }

    /// 選ばれた場面キーを返す（picker は常に 0 番）
    private func scene(_ s: GameState, lossStreak: Int = 0, justPassed: Bool = false, justLost: Bool = false,
                       milestone: (name: String, weeksLeft: Int)? = nil, weak: String = "") -> (String?, Advice) {
        var seen: String?
        let a = DialogueData.innerVoice(state: s, lossStreak: lossStreak, justPassed: justPassed, justLost: justLost,
                                        nextMilestone: milestone, weakAbility: weak, week: 7,
                                        picker: { sc, _, _ in seen = sc; return 0 })
        return (seen, a)
    }

    func testRecoveringBeatsEverything() {
        var s = calm(); s.recoveryWeeks = 2; s.stamina = 10; s.money = 0
        XCTAssertEqual(scene(s, lossStreak: 3, justPassed: true, justLost: true, milestone: ("X", 2)).0, "mono.recovering")
    }

    func testLowStaminaThenLowMoney() {
        var s = calm(); s.stamina = 24.9; s.money = 0
        XCTAssertEqual(scene(s, justLost: true).0, "mono.lowStamina")
        s.stamina = 25
        XCTAssertEqual(scene(s, justLost: true).0, "mono.lowMoney", "25 ちょうどは体力の警告にしない")
        s.money = 30_000
        XCTAssertEqual(scene(s, justLost: true).0, "mono.justLostSingle", "3万ちょうどはお金の警告にしない")
    }

    func testJustLostSingleVsRepeatAndLosing() {
        let s = calm()
        XCTAssertEqual(scene(s, lossStreak: 1, justLost: true).0, "mono.justLostSingle")
        XCTAssertEqual(scene(s, lossStreak: 2, justLost: true).0, "mono.justLostRepeat")
        XCTAssertEqual(scene(s, lossStreak: 2, justPassed: true).0, "mono.losing", "連敗は通過の余韻より先")
        XCTAssertEqual(scene(s, lossStreak: 1, justPassed: true).0, "mono.passed")
    }

    func testMilestoneTwoWeeksWeakAndPlainWithSubstitution() {
        let s = calm()
        let (k1, a1) = scene(s, milestone: ("春の新人杯", 2), weak: "表現")
        XCTAssertEqual(k1, "mono.stageNearWeak")
        XCTAssertFalse(a1.text.contains("〈"), "差し込みが残らない")
        let (k2, a2) = scene(s, milestone: ("春の新人杯", 2), weak: "")
        XCTAssertEqual(k2, "mono.stageNearPlain")
        XCTAssertFalse(a2.text.contains("〈"))
        XCTAssertEqual(a2.name, "俺")
    }

    func testMilestoneOtherDistances() {
        let s = calm()
        XCTAssertEqual(scene(s, milestone: ("X", 1)).0, "mono.plain", "1週前は平常に譲る")
        XCTAssertEqual(scene(s, milestone: ("X", 5)).0, "mono.plain")
        XCTAssertEqual(scene(s, milestone: ("X", 6)).0, "mono.midseason")
        XCTAssertEqual(scene(s).0, "mono.plain")
    }

    func testWithoutPickerIsDeterministicByWeek() {
        let s = calm()
        let a = DialogueData.innerVoice(state: s, lossStreak: 0, justPassed: false, justLost: false,
                                        nextMilestone: nil, weakAbility: "", week: 3)
        let b = DialogueData.innerVoice(state: s, lossStreak: 0, justPassed: false, justLost: false,
                                        nextMilestone: nil, weakAbility: "", week: 3)
        XCTAssertEqual(a.text, b.text)
        XCTAssertFalse(a.text.isEmpty)
    }

    func testChooseEmptyPoolIsNil() {
        XCTAssertNil(DialogueData.choose([], salt: 1, scene: "x", picker: nil))
        XCTAssertEqual(DialogueData.choose(["a", "b"], salt: -1, scene: "x", picker: nil), "b", "負の salt も範囲に折り返す")
    }
}
