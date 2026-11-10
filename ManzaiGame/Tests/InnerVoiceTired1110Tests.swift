// 体力が体調ダウンの線未満の週に、活動を足す独白が谷口の「無理すると倒れるよ」と並ばないこと（playtest_y4_1110 中2）。
// 文面・効果は不変。外す行の一覧（DialogueData.tiredUnfit）がプールに実在することも確かめる。
import XCTest
import GameCore
@testable import ManzaiGame

final class InnerVoiceTired1110Tests: XCTestCase {
    private func state(stamina: Double) -> GameState {
        var s = GameState(config: GameConfig())
        s.recoveryWeeks = 0; s.stamina = stamina; s.money = 1_000_000
        return s
    }
    private typealias Case = (lossStreak: Int, passed: Bool, milestone: (name: String, weeksLeft: Int)?)
    private let cases: [Case] = [(2, false, nil), (0, true, nil), (0, false, ("X", 8))]   // 連敗・通過・本番が遠い週

    /// picker が返す番号を 0..<count で全部回し、出る文と場面キーを集める
    private func lines(_ s: GameState, _ c: Case) -> (Set<String>, Set<String>) {
        var out = Set<String>(), scenes = Set<String>()
        for i in 0..<200 {
            var sc = ""
            let a = DialogueData.innerVoice(state: s, lossStreak: c.lossStreak, justPassed: c.passed, justLost: false,
                                            nextMilestone: c.milestone, weakAbility: "", week: i,
                                            picker: { name, count, _ in sc = name; return i % count })
            out.insert(a.text); scenes.insert(sc)
        }
        return (out, scenes)
    }

    func testTiredWeekDropsActivityLines() {
        for c in cases {
            let (got, scenes) = lines(state(stamina: 40), c)
            XCTAssertTrue(got.isDisjoint(with: DialogueData.tiredUnfit), "\(c.lossStreak)/\(c.passed): \(got.intersection(DialogueData.tiredUnfit))")
            XCTAssertTrue(scenes.allSatisfy { $0.hasSuffix(".tired") }, "直近避けの記録は別キー：\(scenes)")
        }
    }

    func testRestedWeekUnchangedAndListIsReal() {
        var all = Set<String>()
        for c in cases {
            let (got, scenes) = lines(state(stamina: WeekHint.injuryWarn), c)   // 線ちょうどは注意が出ない＝今まで通り
            XCTAssertFalse(scenes.contains { $0.hasSuffix(".tired") })
            all.formUnion(got)
        }
        XCTAssertTrue(DialogueData.tiredUnfit.isSubset(of: all), "プールに無い行：\(DialogueData.tiredUnfit.subtracting(all))")
    }
}
