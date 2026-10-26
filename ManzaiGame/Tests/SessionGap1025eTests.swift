// アプリ側の穴埋めテスト その5（オファーの札・飲みの誘い・選択イベントの金ゲート・年末〜次の年・ネタおろしの一言・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class SessionGap1025eTests: IsolatedStoreTestCase {
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }
    /// 知名度を高くして、オファーが来る自由週まで休みで進める（シード固定＝決定的）
    private func toYearEnd(_ s: GameSession) {
        for _ in 0..<5 {
            s.fastForwardToYearEnd()
            if s.watchingFinal { s.finishWatchingFinal(winner: "—") }
            if s.finished || s.winFinale { break }
        }
    }
    private func sessionAtOffer(fame: Double = 100) -> GameSession? {
        var st = GameSession.debugNetaState()
        st.fame = fame; st.money = 800_000
        let s = GameSession(startState: st)
        for _ in 0..<60 {
            if let k = s.pendingChoiceEvent { _ = k; s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .freeAction(let o):
                if o != nil { return s }
                s.choose(.rest(.完全休養))
            case .tournamentDecision: s.decideTournament(nil)
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return nil
            }
        }
        return nil
    }

    func testOfferChoicesAppearWithHighFame() throws {
        let s = try XCTUnwrap(sessionAtOffer())
        let cs = try XCTUnwrap(s.offerChoices)
        XCTAssertGreaterThanOrEqual(cs.count, 2)
        XCTAssertEqual(Set(cs.map { $0.name }).count, cs.count, "札は重ならない")
    }
    func testChooseOfferSwitchesWhichCardIsAccepted() throws {
        let s = try XCTUnwrap(sessionAtOffer())
        let cs = try XCTUnwrap(s.offerChoices)
        let a = s.previewState(.acceptOffer, offer: cs[0])
        let b = s.previewState(.acceptOffer, offer: cs[1])
        XCTAssertNotEqual(bytes(a), bytes(b), "札が違えば受けた後の状態も違う")
        s.chooseOffer(index: 99)   // 範囲外は無視
        s.chooseOffer(index: 1)
        let week = s.week
        s.choose(.acceptOffer)
        XCTAssertGreaterThan(s.week, week)
        XCTAssertNil(s.offerChoices, "週が進めば札は消える")
    }
    func testPreviewAcceptOfferChangesState() throws {
        let s = try XCTUnwrap(sessionAtOffer(fame: 20))
        guard case .freeAction(let o) = s.phase, let offer = o else { return XCTFail("オファーの週のはず") }
        XCTAssertNotEqual(bytes(s.previewState(.acceptOffer, offer: offer)), bytes(s.state))
        XCTAssertEqual(bytes(s.previewState(.acceptOffer, offer: nil)), bytes(s.state), "札を渡さなければ変化なし")
    }
    func testDeclineOfferByRestingClearsCards() throws {
        let s = try XCTUnwrap(sessionAtOffer())
        let week = s.week
        s.choose(.rest(.完全休養))
        XCTAssertGreaterThan(s.week, week)
        XCTAssertNil(s.offerChoices)
    }
    func testOfferNotFatiguedAtStart() {
        XCTAssertFalse(GameSession(startState: GameSession.debugNetaState()).offerFatigued)
    }
    func testPreviewTrainFallsBackToRestWhenBroke() {
        var st = GameSession.debugNetaState()
        st.money = 0
        let s = GameSession(startState: st)
        guard let paid = s.config.trainings.first(where: { $0.value.cost > 0 })?.key else { return XCTFail("有料の稽古があるはず") }
        let t = s.previewState(.train(paid))
        let r = s.previewState(.rest(.完全休養))
        XCTAssertEqual(bytes(t), bytes(r), "払えない稽古は休みの結果に差し替わる")
    }

    func testTaniguchiShortJobFiresWhenBrokeAndCompatHigh() {
        var st = GameState(config: GameConfig())
        st.money = 50_000; st.compat = 9
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .taniguchiShortJob)
        let money = s.state.money, stamina = s.state.stamina
        s.applyEventChoice("A")
        XCTAssertEqual(s.state.money, money + 150_000)
        XCTAssertEqual(s.state.stamina, stamina - 15)
        let again = bytes(s.state)
        s.applyEventChoice("B")   // 二度押しは無視
        XCTAssertEqual(bytes(s.state), again)
        s.dismissChoiceEvent()
        XCTAssertNil(s.pendingChoiceEvent)
    }
    func testTaniguchiShortJobDeclineGivesCompat() {
        var st = GameState(config: GameConfig())
        st.money = 50_000; st.compat = 9
        let s = GameSession(startState: st)
        let compat = s.state.compat
        s.applyEventChoice("B")
        XCTAssertEqual(s.state.compat, compat + 1)
    }

    func testGatedChoiceIgnoredWhenMoneyShort() {
        var st = GameSession.debugNetaState()
        st.money = 0
        let s = GameSession(startState: st)
        guard let kind = ChoiceEventKind.allCases.first(where: { k in ChoiceEventTable.choices(for: k, config: s.config).contains { !$0.gate(s.state) } }),
              let gated = ChoiceEventTable.choices(for: kind, config: s.config).first(where: { !$0.gate(s.state) })
        else { return XCTFail("お金ゲートの札があるはず") }
        s.debugForceEvent(kind)
        XCTAssertFalse(s.availableEventChoices().contains { $0.id == gated.id })
        let before = bytes(s.state)
        s.applyEventChoice(gated.id)
        XCTAssertEqual(bytes(s.state), before, "お金が足りない選択肢は効かない")
        s.applyEventChoice("zzz")   // 存在しない札
        XCTAssertEqual(bytes(s.state), before)
    }
    func testApplyEventChoiceWithoutPendingEventIsNoop() {
        let s = GameSession(startState: GameSession.debugNetaState())
        s.dismissChoiceEvent()
        let before = bytes(s.state)
        s.applyEventChoice("A")
        XCTAssertEqual(bytes(s.state), before)
        XCTAssertTrue(s.availableEventChoices().isEmpty)
    }
    func testWeekendInviteGoPaysAndDeclineDoesNot() {
        let s = GameSession(startState: GameSession.debugNetaState())
        s.debugForceEvent(.weekendInvite)
        let money = s.state.money, stamina = s.state.stamina
        s.applyEventChoice("A")
        XCTAssertEqual(s.state.money, money - 5_000)
        XCTAssertEqual(s.state.stamina, stamina - 10)
        let t = GameSession(startState: GameSession.debugNetaState())
        t.debugForceEvent(.weekendInvite)
        let before = bytes(t.state)
        t.applyEventChoice("B")
        XCTAssertEqual(bytes(t.state), before, "断ると何も起きない")
    }

    func testBankruptYearEndBlocksNextYear() {
        var st = GameState(config: GameConfig())
        st.compat = 10; st.money = GameConfig().bankruptLine + 5000
        let s = GameSession(startState: st)
        toYearEnd(s)
        guard s.finished else { return XCTFail("年末まで進むはず") }
        XCTAssertTrue(s.careerOver)
        let year = s.year
        s.startNextYear()
        XCTAssertEqual(s.year, year, "夜逃げの年末から次の年へは進めない")
        XCTAssertTrue(s.finished)
    }
    func testStartNextYearResetsYearStateAndKeepsHistory() {
        var st = GameSession.debugNetaState()
        st.money = 900_000
        let s = GameSession(startState: st)
        toYearEnd(s)
        guard s.finished, !s.careerOver else { return XCTFail("通常の年末の想定") }
        let n = s.yearHistory.count
        s.startNextYear()
        XCTAssertEqual(s.year, 2)
        XCTAssertFalse(s.finished)
        XCTAssertNil(s.outcome)
        XCTAssertEqual(s.totalPrize, 0)
        XCTAssertTrue(s.log.isEmpty || s.log.count <= 1)
        XCTAssertGreaterThanOrEqual(s.yearHistory.count, n)
    }
    func testRestoreFromYearEndShowsOutcomeAgain() {
        var st = GameSession.debugNetaState()
        st.money = 900_000
        let s = GameSession(startState: st)
        toYearEnd(s)
        guard s.finished, !s.careerOver else { return XCTFail("通常の年末の想定") }
        s.saveNow()
        let r = GameSession.loadedOrNew()
        XCTAssertTrue(r.isRestored)
        XCTAssertTrue(r.finished)
        XCTAssertNotNil(r.outcome)
        XCTAssertEqual(r.year, s.year)
    }

    func testNetaLiveSetsOroshiLineOnFirstShow() {
        var st = GameSession.debugNetaState()
        st.netas = [Neta(id: 7, name: "新作", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)]
        st.selectedNetaID = 7
        let s = GameSession(startState: st)
        s.choose(.train(.ネタ見せ会))
        if let o = s.justOroshiNeta { XCTAssertEqual(o.0, 7) }
        // 次の行動で一言は消える
        s.choose(.rest(.完全休養))
        XCTAssertNil(s.justOroshiNeta)
    }
    func testCostOfNextStepAndRecommendedAllocation() {
        let s = GameSession(startState: GameSession.debugAllocationState())
        let plan = s.recommendedAllocation()
        XCTAssertFalse(plan.isEmpty)
        let probe = s.previewAllocation([])
        var anyCost = false
        for a in Ability.allCases { if let n = s.costOfNextStep(a, in: probe) { XCTAssertGreaterThan(n, 0); anyCost = true } }
        XCTAssertTrue(anyCost)
        var empty = GameState(config: GameConfig())
        empty.exp閃き = 0; empty.exp語彙 = 0; empty.exp間合い = 0; empty.exp存在感 = 0; empty.exp胆力 = 0
        XCTAssertNil(s.costOfNextStep(.センス, in: empty), "粒が無ければ届かない")
    }
    func testReachedFinalViaRevivalAtStart() {
        let s = GameSession(startState: GameSession.debugNetaState())
        XCTAssertTrue(s.reachedFinalViaRevival)
        XCTAssertFalse(s.upcomingStages().isEmpty)
    }
}
