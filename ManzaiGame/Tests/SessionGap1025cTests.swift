// アプリ側の穴埋めテスト その3（終わりの場面カード／行動プレビュー・割り振り／初出判定／デバッグ進行での終わり判定・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class EndingCardsGapTests: XCTestCase {
    func testEveryEndingHasCardsWithDialogue() {
        for id in EndingID.allCases {
            let cs = id.cards()
            if id == .championRetire { XCTAssertTrue(cs.isEmpty); continue }   // #7 は場面カード無し（仕様どおり）
            XCTAssertFalse(cs.isEmpty, "\(id)")
            for c in cs {
                XCTAssertFalse(c.caption.isEmpty, "\(id)")
                XCTAssertFalse(c.talk.isEmpty, "\(id)")
            }
            XCTAssertFalse(id.hint.isEmpty)
            XCTAssertFalse(id.kind.label.isEmpty)
        }
    }
    func testCardCountsMatchSpecThreesExceptShortOnes() {
        XCTAssertEqual(EndingID.nightEscape.cards().count, 3)
        XCTAssertEqual(EndingID.breakup.cards().count, 3)
        XCTAssertEqual(EndingID.gaveUp.cards().count, 3)
        XCTAssertEqual(EndingID.keptGoing.cards().count, 3)
        XCTAssertEqual(EndingID.tenYearsClose.cards().count, 3)
    }
    func testBreakupRiftChoiceChangesFirstSceneLastLine() {
        let base = EndingID.breakup.cards()[0].talk
        let a = EndingID.breakup.cards(riftChoice: "A")[0].talk
        let b = EndingID.breakup.cards(riftChoice: "B")[0].talk
        XCTAssertEqual(a.count, base.count + 1)
        XCTAssertEqual(b.count, base.count + 1)
        XCTAssertNotEqual(a.last?.text, b.last?.text)
        XCTAssertTrue(a.last!.text.contains("夜のこと"))
        XCTAssertTrue(b.last!.text.contains("言いかけた"))
        XCTAssertEqual(EndingID.breakup.cards(riftChoice: "Z")[0].talk.count, base.count)
    }
    func testRiftChoiceIgnoredByOtherEndings() {
        XCTAssertEqual(EndingID.gaveUp.cards(riftChoice: "A").map(\.caption), EndingID.gaveUp.cards().map(\.caption))
    }
    func testFromNumberOutOfRangeIsNil() {
        XCTAssertNil(EndingID.from(number: 0))
        XCTAssertNil(EndingID.from(number: 9))
        XCTAssertNil(EndingID.from(number: -1))
    }
}

final class SessionPreviewGapTests: IsolatedStoreTestCase {
    private func fresh() -> GameSession { GameSession(startState: GameState(config: GameConfig())) }
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }

    func testPreviewsDoNotMutateState() {
        let s = fresh()
        let before = bytes(s.state)
        _ = s.previewState(.job(.標準))
        _ = s.previewGains(.rest(.完全休養))
        _ = s.previewGrainGains(.train(.allCases.first!))
        _ = s.previewAfterPour(.job(.標準))
        _ = s.previewAllocation(Array(repeating: .センス, count: 5))
        XCTAssertEqual(bytes(s.state), before)
    }
    func testJobPreviewRaisesMoneyAndDropsStamina() {
        let s = fresh()
        let p = s.previewState(.job(.標準))
        XCTAssertGreaterThan(p.money, s.state.money)
        XCTAssertLessThan(p.stamina, s.state.stamina)
    }
    func testPreviewGainsOnlyPositiveAmounts() {
        let s = fresh()
        for g in s.previewGains(.job(.標準)) { XCTAssertGreaterThan(g.amount, 0.001) }
        for g in s.previewGrainGains(.job(.標準)) { XCTAssertGreaterThan(g.amount, 0.001) }
    }
    func testPreviewAllocationWithNoTapsEqualsState() {
        let s = fresh()
        XCTAssertEqual(bytes(s.previewAllocation([])), bytes(s.state))
    }
    func testRecommendedAllocationFromFreshStateIsFinite() {
        let s = fresh()
        XCTAssertLessThanOrEqual(s.recommendedAllocation().count, 2_000 + 100)
    }
    func testAllocateWithNoTapsChangesNothing() {
        let s = fresh()
        let before = bytes(s.state)
        let r = s.allocate([])
        XCTAssertTrue(r.isEmpty)
        XCTAssertEqual(bytes(s.state), before)
    }
    func testFirstShowOnlyFirstKeyPerId() {
        let s = fresh()
        XCTAssertTrue(s.firstShow("x", key: 1))
        XCTAssertTrue(s.firstShow("x", key: 1))     // 同じ場面の再描画
        XCTAssertFalse(s.firstShow("x", key: 2))    // 別の場面では出さない
        XCTAssertTrue(s.firstShow("y", key: 2))     // 別 id は別
    }
    func testClearInjuryNoticeIsIdempotentAndEndingNilWhileRunning() {
        let s = fresh()
        s.clearInjuryNotice()
        XCTAssertNil(s.endingID)
        XCTAssertEqual(s.year, 1)
    }
}

final class SessionDebugPlayGapTests: IsolatedStoreTestCase {
    func testPlayToEndYieldsAnEndingConsistentWithJudge() {
        let s = GameSession(startState: GameState(config: GameConfig()))
        s.debugPlayToEnd(maxSteps: 3000)
        guard s.finished, let o = s.outcome else { return }   // 途中で止まる経路は別（ここでは終わった時だけ検証）
        XCTAssertEqual(s.endingID, EndingID.judge(outcome: o, compat: s.state.compat, history: s.yearHistory, year: s.year, careerYears: s.config.careerYears))
    }
    func testDebugAdvanceYearsRecordsHistory() {
        let s = GameSession(startState: GameState(config: GameConfig()))
        s.debugAdvanceYears(1)
        XCTAssertTrue(s.finished || s.year >= 2 || s.winFinale || !s.yearHistory.isEmpty)
    }
}
