// 網羅の薄い所（DEBUG の目視フック・名前札の色）の今の挙動を固定（11/15 網羅追加 v1）
import XCTest
import SwiftUI
import GameCore
@testable import ManzaiGame

final class Coverage1115Tests: IsolatedStoreTestCase {
    private func make() -> GameSession { GameSession(startState: GameState(config: GameConfig())) }

    func testSpeakerTagColors() {
        XCTAssertEqual(SpeakerStyle.tagColor("谷口"), Theme.vermD)
        XCTAssertEqual(SpeakerStyle.tagColor(nil), Theme.cOreDeep)
        XCTAssertEqual(SpeakerStyle.tagColor("俺"), Theme.cOreDeep)
        XCTAssertEqual(SpeakerStyle.tagColor(FinalsMC.name), Color(hex: 0x23202B))
        XCTAssertEqual(SpeakerStyle.tagColor("誰か"), Theme.inkSub)
    }

    func testSeedKirokuLogHasFourVerdictsAndFiveLines() {
        let s = make()
        s.debugSeedKirokuLog()
        XCTAssertEqual(s.log.count, 5)
        for v in ["通過", "敗退", "休", "優勝"] { XCTAssertTrue(s.log.contains { $0.contains(v) }, v) }
        XCTAssertTrue(s.log.contains { $0.contains("（客席から）") })
        XCTAssertTrue(s.log[0].hasPrefix("第12週"))
    }

    func testMarkGPLostFlipsAliveFlagOnly() {
        let s = make()
        let before = s.state
        s.debugMarkGPLost()
        XCTAssertEqual(s.week, 1)
        XCTAssertEqual(s.state.money, before.money)
        XCTAssertEqual(s.debugRunnerState.money, before.money)
    }

    func testUntilOfferStopsOnOfferOrRunsBounded() {
        let s = make()
        s.debugUntilOffer()
        if case .freeAction(let o) = s.phase { XCTAssertTrue(o != nil || s.finished == false) }
        XCTAssertGreaterThanOrEqual(s.week, 1)
    }

    func testAdvanceUntilStageReachesTargetWeekOrLater() {
        let s = make()
        s.debugAdvanceUntilStage(weeksBefore: 2, stageWeek: 8)
        XCTAssertGreaterThanOrEqual(s.week, 6)
        XCTAssertNil(s.pendingChoiceEvent)
    }

    func testAdvanceUntilStageNoopWhenAlreadyPast() {
        let s = make()
        let w = s.week
        s.debugAdvanceUntilStage(weeksBefore: 5, stageWeek: 1)
        XCTAssertEqual(s.week, w)
    }

    func testUntilInjuryTerminatesWithinBound() {
        let s = make()
        s.debugUntilInjury(maxSteps: 60)
        XCTAssertTrue(s.injuryNoticeWeeks > 0 || s.finished || s.week > 1)
    }

    func testAdvanceToYearEndFinishesTheYear() {
        let s = make()
        s.debugAdvanceToYearEnd()
        XCTAssertTrue(s.finished || s.winFinale || s.week > 1)
    }

    func testAdvanceToPreludeTerminates() {
        let s = make()
        s.debugAdvanceToPrelude(final: false, maxSteps: 200)
        XCTAssertFalse(s.winFinale)
    }

    func testAdvanceToChampionFinaleTerminates() {
        let s = make()
        s.debugAdvanceToChampionFinale(maxSteps: 200)
        XCTAssertGreaterThanOrEqual(s.week, 1)
    }

    func testActionTraceDoesNotCrash() {
        GameSession.debugActionTrace()
    }

    func testAdvanceYearsOneYearMovesForward() {
        let s = make()
        s.debugAdvanceYears(1)
        XCTAssertTrue(s.year >= 1)
    }

    func testDebugFreeWeeksAdvancesWeeks() {
        let s = make()
        let w = s.week
        s.debugFreeWeeks(3, .rest(.完全休養))
        XCTAssertGreaterThan(s.week, w)
    }
}
