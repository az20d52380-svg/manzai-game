// 入口の段の照合（懸念の台帳 L37 二度押し・bbbd65a）：今の段と合わない呼び出しは何もしない
import XCTest
import GameCore
@testable import ManzaiGame

final class PhaseGuardTests: IsolatedStoreTestCase {
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }

    func testWrongPhaseCallsAreIgnoredOnFreeWeek() {
        let s = GameSession(startState: GameSession.debugNetaState())
        guard case .freeAction = s.phase else { return XCTFail("第1週は自由週の想定") }
        let before = bytes(s.state), week = s.week
        s.decideTournament(.夜行バス)   // 大会の段ではない
        s.advanceAuto()                 // GP の段ではない
        XCTAssertEqual(bytes(s.state), before)
        XCTAssertEqual(s.week, week)
        guard case .freeAction = s.phase else { return XCTFail("段が変わってはいけない") }
    }

    func testChooseRunsOnFreeWeekThenNextWeekStillAccepts() {
        let s = GameSession(startState: GameSession.debugNetaState())
        let week = s.week
        s.choose(.rest(.完全休養))
        XCTAssertGreaterThan(s.week, week, "正しい段の行動は通る")
    }
}
