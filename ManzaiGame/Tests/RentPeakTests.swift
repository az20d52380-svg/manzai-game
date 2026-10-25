// 【候補 q9】家賃はその月に住んだ一番上の部屋の額（月末だけ安い部屋に戻す抜け道を塞ぐ・room_rent_exploit_v0 直しA）
import XCTest
import GameCore
@testable import ManzaiGame

final class RentPeakTests: IsolatedStoreTestCase {
    func testMovingDownMidMonthStillPaysUpperRoomThenCheaperNextMonth() {
        var st = GameState(config: GameConfig()); st.money = 3_000_000; st.room = 2
        let s = GameSession(startState: st)
        let cfg = s.config
        XCTAssertTrue(s.moveRoom(to: 0))
        var paid: [Int] = []
        var guardSteps = 0
        while paid.count < 2, guardSteps < 400 {
            guardSteps += 1
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(nil)
            case .freeAction:
                s.choose(.rest(.完全休養))
                if s.lastLivingPaid > 0 { paid.append(s.lastLivingPaid) }
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: break
            }
            if s.finished { break }
        }
        XCTAssertEqual(paid.count, 2)
        let base = GameEngine.livingCostDue(GameState(config: cfg), config: cfg)
        XCTAssertEqual(paid.first, base + cfg.roomRents[2], "下げた月は上の部屋の家賃")
        XCTAssertEqual(paid.last, base, "次の月は今の部屋（安アパート）")
        XCTAssertNil(s.state.roomPeak)
    }
}
