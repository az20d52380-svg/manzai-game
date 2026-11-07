// 道中大会の出た数・優勝した数が中断と再開で0に戻らない（六冠の年の判定・code_review_1107g #1）
import XCTest
import GameCore
@testable import ManzaiGame

final class SmallCountSave1107Tests: IsolatedStoreTestCase {
    func testCountsSurviveSaveAndLoad() {
        let s = GameSession(startState: GameSession.debugMaxedState())
        var steps = 0
        while s.smallEntered == 0, !s.winFinale, !s.finished, steps < 300 {
            steps += 1
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.夜行バス)
            case .freeAction: s.choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: steps = 300
            }
        }
        XCTAssertGreaterThan(s.smallEntered, 0)
        s.saveNow()
        let r = GameSession.loadedOrNew()
        XCTAssertEqual(r.smallEntered, s.smallEntered)
        XCTAssertEqual(r.smallWon, s.smallWon)
    }
}
