// Coverage1019Tests.swift
// 未カバー箇所の補強（Codable 往復・同値タイブレーク・境界）。今の振る舞いを固定するだけ・Sources／式／golden は不変。

import XCTest
@testable import GameCore

final class Coverage1019Tests: XCTestCase {
    let cfg = GameConfig()

    private func roundTrip<T: Codable>(_ v: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(v))
    }

    // MARK: Codable 往復

    func testNetaStampCodableRoundTripAndEquatable() throws {
        let a = NetaStamp(year: 2, stage: "GP3回戦", passed: true)
        XCTAssertEqual(try roundTrip(a), a)
        XCTAssertNotEqual(a, NetaStamp(year: 2, stage: "GP3回戦", passed: false))
    }

    func testWeekRunnerSectionAndAutoStageCodableAllCases() throws {
        let secs: [WeekRunner<SplitMix64>.Section] = [.tournament, .gp, .finalWeek, .free, .end]
        let secBack: [WeekRunner<SplitMix64>.Section] = try roundTrip(secs)
        XCTAssertTrue(secBack == secs)
        let autos: [WeekRunner<SplitMix64>.AutoStage] = [.round, .revival, .final]
        let autoBack: [WeekRunner<SplitMix64>.AutoStage] = try roundTrip(autos)
        XCTAssertTrue(autoBack == autos)
    }

    func testTravelAndEligibilityCodableRoundTrip() throws {
        let trv: [Travel] = [.夜行バス, .新幹線]
        let trvBack: [Travel] = try roundTrip(trv)
        XCTAssertTrue(trvBack == trv)
        let es: [TournamentSpec.Eligibility] = [.always, .careerYearAtMost(3), .fameAtLeast(42.5)]
        let back = try roundTrip(es)
        XCTAssertEqual(back.count, 3)
        if case .careerYearAtMost(let n) = back[1] { XCTAssertEqual(n, 3) } else { XCTFail() }
        if case .fameAtLeast(let f) = back[2] { XCTAssertEqual(f, 42.5, accuracy: 1e-12) } else { XCTFail() }
    }

    func testWeekSummaryCodableKeepsResultsAndOptionalFields() throws {
        var st = GameState(config: cfg)
        st.money = 1234
        let rs = [StageResult(name: "予選", passed: true, prize: 10),
                  StageResult(name: "決勝", passed: false, prize: 0, isStage: true, margin: -3.5, burst: true)]
        let back = try roundTrip(WeekSummary(year: 2, week: 17, results: rs, state: st))
        XCTAssertEqual(back.year, 2); XCTAssertEqual(back.week, 17)
        XCTAssertEqual(back.results.map(\.name), ["予選", "決勝"])
        XCTAssertNil(back.results[0].margin); XCTAssertNil(back.results[0].burst)
        XCTAssertEqual(back.results[1].margin ?? 0, -3.5, accuracy: 1e-12)
        XCTAssertEqual(back.results[1].burst, true)
        XCTAssertEqual(back.state.money, 1234)
    }

    func testStageResultDecodesOldSaveWithoutOptionalFields() throws {
        let json = #"{"name":"旧","passed":true,"prize":5,"isStage":true}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(StageResult.self, from: json)
        XCTAssertEqual(r.name, "旧"); XCTAssertNil(r.margin); XCTAssertNil(r.burst)
    }

    // MARK: イベント効果の境界・タイブレーク

    func testWeakestSkillPlusTieBreaksToFirstSkillAndExcludesMental() {
        var s = GameState(config: cfg)
        for a in [Ability.センス, .発想, .表現, .華] { s[a] = 10 }
        s[.メンタル] = 0
        s.applyEventEffect(.weakestSkillPlus(5), config: cfg)
        XCTAssertEqual(s[.センス], 15, accuracy: 1e-12)
        XCTAssertEqual(s[.発想], 10, accuracy: 1e-12)
        XCTAssertEqual(s[.メンタル], 0, accuracy: 1e-12)
    }

    func testWeakerSenseIdeaPlusTieGoesToSenseAndCapsAtAbilityCap() {
        var s = GameState(config: cfg)
        s[.センス] = 20; s[.発想] = 20
        s.applyEventEffect(.weakerSenseIdeaPlus(3), config: cfg)
        XCTAssertEqual(s[.センス], 23, accuracy: 1e-12)
        XCTAssertEqual(s[.発想], 20, accuracy: 1e-12)
        s.applyEventEffect(.weakerSenseIdeaPlus(10_000), config: cfg)   // 発想の方が低い→発想がキャップまで
        XCTAssertEqual(s[.発想], cfg.abilityCap, accuracy: 1e-12)
    }

    func testMentalAbilityEffectUsesMentalCapAndFloorsAtZero() {
        var s = GameState(config: cfg)
        s.applyEventEffect(.ability(.メンタル, 10_000), config: cfg)
        XCTAssertEqual(s[.メンタル], cfg.mentalCap, accuracy: 1e-12)
        s.applyEventEffect(.ability(.メンタル, -10_000), config: cfg)
        XCTAssertEqual(s[.メンタル], 0, accuracy: 1e-12)
    }

    func testMoneyEffectIsUnclampedAndCanGoNegative() {
        var s = GameState(config: cfg)
        s.money = 100
        s.applyEventEffect(.money(-250), config: cfg)
        XCTAssertEqual(s.money, -150)
    }

    func testRiftEffectFromNilStartsAtZeroAndClamps() {
        var s = GameState(config: cfg)
        s.rift = nil
        s.applyEventEffect(.rift(-5), config: cfg)
        XCTAssertEqual(s.rift ?? -1, 0, accuracy: 1e-12)
        s.applyEventEffect(.rift(500), config: cfg)
        XCTAssertEqual(s.rift ?? -1, 100, accuracy: 1e-12)
    }

    // MARK: エンジン／ショップ／講評

    func testWeightOfMentalIsZeroAndSkillWeightsMatchConfig() {
        XCTAssertEqual(GameEngine.weight(of: .メンタル, config: cfg), 0)
        XCTAssertEqual(GameEngine.weight(of: .センス, config: cfg), cfg.weightSense)
        XCTAssertEqual(GameEngine.weight(of: .発想, config: cfg), cfg.weightIdea)
        XCTAssertEqual(GameEngine.weight(of: .表現, config: cfg), cfg.weightExpr)
        XCTAssertEqual(GameEngine.weight(of: .華, config: cfg), cfg.weightChara)
    }

    func testCanBuyIsFalseWithZeroMoneyForEveryShopItem() {
        var s = GameState(config: cfg)
        s.money = 0
        for item in ShopItem.allCases {
            XCTAssertFalse(GameEngine.canBuy(item, state: s, config: cfg), "\(item)")
        }
    }

    func testFinalCommentIsDeterministicForSameSaltAndNonEmpty() {
        for j in JudgeTalk.judgeNames {
            let a = JudgeTalk.finalComment(judge: j, score: 92, high: true, scene: JudgeTalk.Scene(), salt: 7)
            let b = JudgeTalk.finalComment(judge: j, score: 92, high: true, scene: JudgeTalk.Scene(), salt: 7)
            XCTAssertEqual(a, b)
            XCTAssertFalse(a.text.isEmpty)
        }
    }

    func testPickupAfterEmptyTextIsNil() {
        XCTAssertNil(JudgeTalk.pickup(after: ""))
    }
}
