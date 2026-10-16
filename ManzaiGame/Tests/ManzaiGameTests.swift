// アプリ側の判定ロジック（Endings / Names / 借金の段 / 客席の声 / 予告0050）の単体テスト。UI は対象外。
import XCTest
import GameCore
@testable import ManzaiGame

final class EndingJudgeTests: XCTestCase {
    private func rec(_ y: Int, final f: Bool) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: 1, reachedFinal: f, champion: false, bankrupt: false, prize: 0)
    }
    private func out(champ: Bool = false, bank: Bool = false, diss: Bool = false) -> YearOutcome {
        YearOutcome(champion: champ, roundsPassed: 2, reachedFinal: false, bankrupt: bank, dissolved: diss)
    }
    private func judge(_ o: YearOutcome, compat: Double, hist: [GameSession.YearRecord] = [], year: Int = 3) -> EndingID? {
        EndingID.judge(outcome: o, compat: compat, history: hist, year: year, careerYears: 10)
    }

    func testBankruptAndDissolve() {
        XCTAssertEqual(judge(out(bank: true), compat: 20), .nightEscape)
        XCTAssertEqual(judge(out(diss: true), compat: 20), .breakup)
        XCTAssertEqual(judge(out(bank: true, diss: true), compat: 0), .nightEscape)   // 夜逃げが先
    }
    func testChampionByCompatBoundary() {
        XCTAssertEqual(judge(out(champ: true), compat: 15), .championPair)
        XCTAssertEqual(judge(out(champ: true), compat: 14.99), .championRetire)
        XCTAssertEqual(judge(out(champ: true), compat: 0), .championRetire)
    }
    func testDissolveBeatsChampionSameYear() {
        XCTAssertEqual(judge(out(champ: true, diss: true), compat: 20), .breakup)
        XCTAssertEqual(judge(out(champ: true, bank: true), compat: 20), .nightEscape)
    }
    func testNotYetEnded() {
        XCTAssertNil(judge(out(), compat: 20, year: 9))
    }
    func testTenYearsFourWay() {
        let none = (1...10).map { rec($0, final: false) }
        var once = none; once[4] = rec(5, final: true)
        let many = (1...10).map { rec($0, final: true) }
        XCTAssertEqual(judge(out(), compat: 14.99, hist: none, year: 10), .gaveUp)
        XCTAssertEqual(judge(out(), compat: 15, hist: none, year: 10), .keptGoing)
        XCTAssertEqual(judge(out(), compat: 14.99, hist: once, year: 10), .tenYearsClose)   // 決勝1回
        XCTAssertEqual(judge(out(), compat: 15, hist: once, year: 10), .tenYearsTrue)
        XCTAssertEqual(judge(out(), compat: 15, hist: many, year: 10), .tenYearsTrue)
        XCTAssertEqual(judge(out(), compat: 0, hist: [], year: 10), .gaveUp)   // 履歴空＝決勝0回
    }
    func testNumbersUniqueAndRoundTrip() {
        XCTAssertEqual(Set(EndingID.allCases.map { $0.number }).count, EndingID.allCases.count)
        for id in EndingID.allCases { XCTAssertEqual(EndingID.from(number: id.number), id) }
    }
}

final class NamesTests: XCTestCase {
    override func tearDown() { Names.set(me: nil, partner: nil); super.tearDown() }

    func testDefaultsUnchanged() {
        Names.set(me: nil, partner: nil)
        XCTAssertEqual(Names.show("谷口さんが来た"), "谷口さんが来た")
        XCTAssertEqual(Names.show("俺"), "俺")
    }
    func testPartnerReplacedInsideSentence() {
        Names.set(me: nil, partner: "ケンジ")
        XCTAssertEqual(Names.show("谷口の言う通りだ。谷口さん、行こう"), "ケンジの言う通りだ。ケンジさん、行こう")
    }
    func testMeOnlyWhenExactLabel() {
        Names.set(me: "ミナト", partner: nil)
        XCTAssertEqual(Names.show("俺"), "ミナト")
        XCTAssertEqual(Names.show("俺は行く"), "俺は行く")   // 地の文・心の声の「俺」は触らない
    }
    func testBlankFallsBack() {
        Names.set(me: "  ", partner: "")
        XCTAssertEqual(Names.show("俺"), "俺")
        XCTAssertEqual(Names.show("谷口"), "谷口")
        Names.set(me: nil, partner: " \n")
        XCTAssertEqual(Names.partner, "谷口")
    }
    func testSixAndSevenChars() {
        Names.set(me: nil, partner: "ABCDEF")
        XCTAssertEqual(Names.show("谷口"), "ABCDEF")
        Names.set(me: nil, partner: "ABCDEFG")   // 7字目は切る
        XCTAssertEqual(Names.partner, "ABCDEF")
    }
}

final class DebtWarnTests: XCTestCase {
    override func tearDown() { UserDefaults.standard.removeObject(forKey: "manzai.save.v1"); super.tearDown() }

    func testTierBoundaries() {
        XCTAssertEqual(GameSession.debtTier(money: 0), 0)
        XCTAssertEqual(GameSession.debtTier(money: -1), 1)
        XCTAssertEqual(GameSession.debtTier(money: -500_000), 1)
        XCTAssertEqual(GameSession.debtTier(money: -500_001), 2)
        XCTAssertEqual(GameSession.debtTier(money: -800_000), 2)
        XCTAssertEqual(GameSession.debtTier(money: -800_001), 3)
    }
    func testEachTierShownOnce() {
        let s = GameSession()
        XCTAssertNil(s.debtNoticeTierToShow(money: 10_000))
        var shown: [Int] = []
        for money in [-10_000, -10_000, -600_000, -600_000, -400_000, -900_000, -900_000, -600_000] {
            if let t = s.debtNoticeTierToShow(money: money) { shown.append(t); s.markDebtWarned(t) }
        }
        XCTAssertEqual(shown, [1, 2, 3])   // 回復して再び落ちても同じ段は出ない
    }
    func testSkippingTiersJumpsDirectly() {
        let s = GameSession()
        XCTAssertEqual(s.debtNoticeTierToShow(money: -900_000), 3)
        s.markDebtWarned(3)
        XCTAssertNil(s.debtNoticeTierToShow(money: -100_000))
    }
    func testOldSaveWithoutDebtTier() throws {
        let s = GameSession()
        s.markDebtWarned(2)   // saveNow される
        s.saveNow()
        let d = try XCTUnwrap(UserDefaults.standard.data(forKey: "manzai.save.v1"))
        var o = try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any])
        XCTAssertNotNil(o["debtWarnTier"])
        o.removeValue(forKey: "debtWarnTier")
        let old = try JSONDecoder().decode(GameSession.SaveData.self, from: JSONSerialization.data(withJSONObject: o))
        XCTAssertNil(old.debtWarnTier)
        let r = GameSession(restoring: old)
        XCTAssertEqual(r.debtWarnTier, 0)
        XCTAssertEqual(r.debtNoticeTierToShow(money: -10_000), 1)
    }
}

final class FanReportTests: XCTestCase {
    func testIsKnownBoundaries() {
        XCTAssertFalse(FanReportData.isKnown(year: 1, fame: 99))
        XCTAssertFalse(FanReportData.isKnown(year: 2, fame: 14.99))
        XCTAssertTrue(FanReportData.isKnown(year: 2, fame: 15))
        XCTAssertTrue(FanReportData.isKnown(year: 10, fame: 40))
    }
    private let knownMarks = ["いつも", "去年", "安定", "期待が違った", "切れが増して"]
    func testUnknownNeverGetsKnownOnlyLines() {
        for salt in -40...200 {
            let b = FanReportData.burst(name: "X", salt: salt, known: false)
            XCTAssertFalse(knownMarks.contains { b.contains($0) }, b)
            for passed in [true, false] { for m in [20.0, 5.0, -2.0, -8.0, -30.0, nil] as [Double?] {
                for burst in [true, false] {
                    for v in FanReportData.voices(name: "X", passed: passed, margin: m, burst: burst, salt: salt, known: false) {
                        XCTAssertFalse(knownMarks.contains { v.contains($0) }, v)
                    }
                }
            } }
        }
    }
    func testKnownCanGetKnownOnlyLines() {
        var hit = false
        for salt in 0..<300 {
            if FanReportData.burst(name: "X", salt: salt, known: true).contains("去年") { hit = true }
            for v in FanReportData.voices(name: "X", passed: true, margin: 20, burst: true, salt: salt, known: true) where knownMarks.contains(where: { v.contains($0) }) { hit = true }
        }
        XCTAssertTrue(hit)
    }
}

final class RiftWarnEventTests: XCTestCase {
    override func tearDown() { UserDefaults.standard.removeObject(forKey: "manzai.save.v1"); super.tearDown() }

    /// 予告0050：riftWarned が初めて true になった週の次の週頭に1回だけ出る（1キャリア1回）
    func testRiftWarningFiresOnceAfterFlagSet() {
        var st = GameState(config: GameConfig()); st.compat = 3; st.money = 500_000; st.rift = 49
        let s = GameSession(startState: st)
        var fired = 0, steps = 0
        var warnedBeforeFire: Bool?
        var warnedBeforeEver = false
        while steps < 4000, !s.finished { steps += 1
            if s.pendingChoiceEvent == .riftWarning {
                fired += 1
                if fired == 1 { warnedBeforeFire = (s.state.riftWarned == true); warnedBeforeEver = (s.didFireRiftWarn) }
                s.dismissChoiceEvent(); continue
            }
            if s.state.riftWarned != true { XCTAssertEqual(fired, 0, "フラグ前に出た") }
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.新幹線)
            case .freeAction: s.choose(.rest(.完全休養))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: steps = 4000
            }
        }
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(warnedBeforeFire, true)
        XCTAssertTrue(warnedBeforeEver)
    }
    /// 予告の後の「すれ違いが減る」知らせは、選んだ後に一度だけ出る（選ぶ前は出ない・記録後は出ない）
    func testRiftHintShowsOnlyOnceAfterWarning() {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertFalse(s.riftHintToShow, "選ぶ前に出た")
        s.applyEventChoice(s.availableEventChoices()[0].id)
        s.dismissChoiceEvent()
        XCTAssertTrue(s.riftHintToShow)
        s.markRiftHintShown()
        XCTAssertFalse(s.riftHintToShow, "2回目が出た")
    }
    /// 予告が出た週に「年末へ」を押しても、予告は消えず次の年の第1週頭に出る（1キャリア1回は保つ）
    func testRiftWarningSurvivesFastForwardToYearEnd() {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        s.fastForwardToYearEnd()
        if s.watchingFinal { s.finishWatchingFinal(winner: "x"); s.fastForwardToYearEnd() }   // 決勝の夜は観せて止まる
        XCTAssertTrue(s.finished && !s.careerOver, "年末まで進む前提 finished=\(s.finished) over=\(s.careerOver) rift=\(s.state.rift ?? -1)")
        guard s.finished, !s.careerOver else { return }
        XCTAssertFalse(s.didFireRiftWarn)
        s.startNextYear()
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertEqual(s.week, 1)
        XCTAssertTrue(s.didFireRiftWarn)
        s.dismissChoiceEvent()
        s.fastForwardToYearEnd()
        XCTAssertTrue(s.didFireRiftWarn)
    }
    func testNoRiftWarnWhenFlagNeverSet() {
        var st = GameState(config: GameConfig()); st.rift = 0
        let s = GameSession(startState: st)
        XCTAssertNotEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertFalse(s.didFireRiftWarn)
    }
}

final class PlaytestFixTests: XCTestCase {
    func testShortagesWhenOnlyMaGrains() {
        let cfg = GameConfig()
        var st = GameState(config: cfg)
        for c in ExpCurrency.allCases { st[currency: c] = 0 }
        st[currency: .間合い] = 80          // 間だけ貯まっている
        // 華（存在感70%・閃き30%）は存在感も閃きも足りない
        let sh = AbilityUpView.shortages(.華, state: st, config: cfg)
        XCTAssertTrue(sh.contains { $0.currency == .存在感 && $0.short > 0 })
        XCTAssertTrue(sh.contains { $0.currency == .閃き && $0.short > 0 })
        XCTAssertFalse(sh.contains { $0.currency == .間合い })
    }
    func testNoShortageWhenRich() {
        let cfg = GameConfig()
        var st = GameState(config: cfg)
        for c in ExpCurrency.allCases { st[currency: c] = 500 }
        for a in Ability.allCases { XCTAssertTrue(AbilityUpView.shortages(a, state: st, config: cfg).isEmpty) }
    }
    func testPracticesMapToTrainingSpec() {
        let cfg = GameConfig()
        XCTAssertEqual(AbilityUpView.practices(for: .存在感, config: cfg).first, "舞台に立つ")
        XCTAssertTrue(AbilityUpView.practices(for: .存在感, config: cfg).contains("カラオケボックスで声出し"))
        XCTAssertEqual(AbilityUpView.practices(for: .閃き, config: cfg).first, "ネタを書く")
        XCTAssertFalse(AbilityUpView.practices(for: .語彙, config: cfg).isEmpty)   // 語彙は副効果から引く
    }
    func testPowerNote() {
        XCTAssertNotNil(TournamentResultView.powerNote(passed: true, power: 21, line: 28))
        XCTAssertNotNil(TournamentResultView.powerNote(passed: false, power: 30, line: 28))
        XCTAssertNil(TournamentResultView.powerNote(passed: true, power: 30, line: 28))
        XCTAssertNil(TournamentResultView.powerNote(passed: false, power: 20, line: 28))
        XCTAssertNil(TournamentResultView.powerNote(passed: true, power: 20, line: nil))
    }
    func testLengthMismatchNote() {
        let n = Neta(id: 1, name: "x", kata: .華先行, lengthFit: [.短尺], bornYear: 1)
        XCTAssertNil(NetaPickRow.lengthMismatchNote(n, required: .短尺))
        let note = NetaPickRow.lengthMismatchNote(n, required: .中尺)
        XCTAssertTrue(note?.contains("ふつう") == true && note?.contains("短め") == true)
    }
}
